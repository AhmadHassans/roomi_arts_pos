import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../theme.dart';
import 'receipt_data.dart';

/// On-screen receipt preview used on Mac / desktop while testing without the
/// real thermal printer. Renders the SAME [ReceiptData] the printer uses, laid
/// out to look like an 80mm paper slip.
class ReceiptPreview extends StatelessWidget {
  final ReceiptData data;
  const ReceiptPreview({super.key, required this.data});

  static Future<void> show(ReceiptData data) =>
      Get.dialog(ReceiptPreview(data: data), barrierDismissible: true);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Small banner so the tester knows this stands in for the printer.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
              decoration: const BoxDecoration(
                color: AppColors.violet,
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: const Text('Receipt preview (printer not connected)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: DefaultTextStyle(
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 12.5, color: Colors.black),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(data.shopName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.black)),
                    Text(data.subtitle, textAlign: TextAlign.center),
                    Text(data.address, textAlign: TextAlign.center),
                    Text(data.phone, textAlign: TextAlign.center),
                    if (data.isReturn)
                      const Text('** RETURN / REFUND **',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                              color: Colors.black)),
                    const _Dashes(),
                    _KV(label: 'Invoice:', value: data.invoiceNo),
                    _KV(label: 'Date:', value: data.dateText),
                    if (data.cashier != null && data.cashier!.isNotEmpty)
                      _KV(label: 'Cashier:', value: data.cashier!),
                    _KV(label: 'Payment:', value: data.paymentText),
                    const _Dashes(),
                    const _Row(
                        name: 'Item', qty: 'Qty x Rate', total: 'Amt', bold: true),
                    for (final it in data.items)
                      _Row(
                        name: it.name,
                        qty: '${it.qty} x ${ReceiptData.money(it.unitPrice)}',
                        total: ReceiptData.money(it.lineTotal),
                      ),
                    const _Dashes(),
                    _Row(
                      name: 'Subtotal',
                      qty: '',
                      total: ReceiptData.money(data.subtotal),
                    ),
                    _Row(
                      name: 'Discount',
                      qty: '',
                      total: '-${ReceiptData.money(data.discount)}',
                    ),
                    _Row(
                      name: 'TOTAL',
                      qty: '',
                      total: 'Rs ${ReceiptData.money(data.total)}',
                      bold: true,
                    ),
                    if (data.showsCash) ...[
                      const _Dashes(),
                      _Row(
                        name: 'Cash received',
                        qty: '',
                        total: ReceiptData.money(data.cashReceived!),
                      ),
                      if (data.balanceDue != null)
                        _Row(
                          name: 'BALANCE DUE',
                          qty: '',
                          total: 'Rs ${ReceiptData.money(data.balanceDue!)}',
                          bold: true,
                        )
                      else
                        _Row(
                          name: 'CHANGE RETURN',
                          qty: '',
                          total:
                              'Rs ${ReceiptData.money(data.changeReturn ?? 0)}',
                          bold: true,
                        ),
                    ],
                    const _Dashes(),
                    Text('Items: ${data.itemsCount}',
                        textAlign: TextAlign.center),
                    Text(data.footer,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: SizedBox(
                height: Sizes.buttonHeight,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  child: const Text('Close'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dashes extends StatelessWidget {
  const _Dashes();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Text('--------------------------------',
            maxLines: 1, overflow: TextOverflow.clip),
      );
}

/// A label-left, value-right line (Invoice / Date / Cashier / Payment).
class _KV extends StatelessWidget {
  final String label;
  final String value;
  const _KV({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
        fontFamily: 'monospace', fontSize: 12.5, color: Colors.black);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text(label, style: style)),
          Expanded(
              flex: 7,
              child: Text(value, style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String name;
  final String qty;
  final String total;
  final bool bold;
  const _Row({
    required this.name,
    required this.qty,
    required this.total,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
        fontFamily: 'monospace',
        fontSize: 12.5,
        color: Colors.black,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w400);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text(name, style: style)),
          Expanded(
              flex: 4,
              child: Text(qty, style: style, textAlign: TextAlign.center)),
          Expanded(
              flex: 3,
              child: Text(total, style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}
