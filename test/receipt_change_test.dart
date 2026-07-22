// Verifies the receipt cash-change logic: change is shown when the customer
// pays enough, and an underpayment shows BALANCE DUE instead of a negative
// "CHANGE RETURN".
import 'package:flutter_test/flutter_test.dart';
import 'package:roomi_arts_pos/core/printing/receipt_data.dart';

ReceiptData _r({required double total, double? cash, bool isReturn = false}) =>
    ReceiptData(
      shopName: 'Roomi Arts',
      subtitle: 't',
      address: 'a',
      phone: 'p',
      invoiceNo: 'INV-1',
      dateText: 'd',
      cashier: 'Ali',
      paymentText: 'Cash',
      isReturn: isReturn,
      items: const [ReceiptItemLine('Item', 1, 100, 100)],
      subtotal: total,
      discount: 0,
      total: total,
      cashReceived: cash,
      footer: 'f',
    );

void main() {
  test('overpaid: change shown, no balance due', () {
    final r = _r(total: 100, cash: 150);
    expect(r.showsCash, isTrue);
    expect(r.changeReturn, 50);
    expect(r.balanceDue, isNull);
  });

  test('exact payment: zero change, no balance due', () {
    final r = _r(total: 100, cash: 100);
    expect(r.changeReturn, 0);
    expect(r.balanceDue, isNull);
  });

  test('underpaid: balance due shown, no (negative) change', () {
    final r = _r(total: 100, cash: 60);
    expect(r.balanceDue, 40);
    expect(r.changeReturn, isNull); // never a negative CHANGE RETURN
  });

  test('no cash entered: cash block hidden', () {
    final r = _r(total: 100, cash: null);
    expect(r.showsCash, isFalse);
    expect(r.changeReturn, isNull);
    expect(r.balanceDue, isNull);
  });

  test('returns never show the cash block', () {
    final r = _r(total: 100, cash: 150, isReturn: true);
    expect(r.showsCash, isFalse);
  });
}
