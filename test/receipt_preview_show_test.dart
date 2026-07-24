// Confirms that completing a sale in preview mode (no thermal printer, e.g.
// Mac/desktop) actually pops the on-screen receipt preview dialog.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roomi_arts_pos/core/printing/printer_prefs.dart';
import 'package:roomi_arts_pos/core/printing/receipt_service.dart';
import 'package:roomi_arts_pos/models/sale.dart';
import 'package:roomi_arts_pos/models/sale_item.dart';

void main() {
  testWidgets('sale in system mode shows the receipt preview on desktop',
      (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: Scaffold()));

    final svc = ReceiptService.instance;
    svc.printerMode = PrinterMode.system; // Mac test host is not thermal
    svc.networkIp = null;

    // Fire the delivery (it awaits the dialog being dismissed, so don't await).
    unawaited(svc.deliver(
      sale: const Sale(
        invoiceNo: 'INV-000001',
        date: '2026-07-20T12:00:00',
        totalAmount: 100,
        discountAmount: 0,
        paymentType: 'cash',
        type: 'sale',
        cashier: 'Ali',
      ),
      items: const [SaleItem(productId: 1, qty: 1, priceAtSale: 100, costAtSale: 60)],
      names: const {1: 'A4 register'},
      cashierName: 'Ali',
      cashReceived: 150,
    ));

    await tester.pumpAndSettle();

    // The preview dialog and its contents should be on screen.
    expect(find.text('Receipt preview (printer not connected)'), findsOneWidget);
    expect(find.text('Roomi Arts'), findsOneWidget);
    expect(find.textContaining('INV-000001'), findsOneWidget);
    expect(find.text('CHANGE RETURN'), findsOneWidget); // 150 - 100 = 50

    // Clean up the open dialog.
    Get.back();
    await tester.pumpAndSettle();
  });
}

void unawaited(Future<void> f) {}
