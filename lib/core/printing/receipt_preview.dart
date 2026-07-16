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
                    if (data.isReturn)
                      const Text('** RETURN / REFUND **',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                              color: Colors.black)),
                    const _Dashes(),
                    Text('Invoice: ${data.invoiceNo}'),
                    Text('Date: ${data.dateText}'),
                    Text('Payment: ${data.paymentText}'),
                    const _Dashes(),
                    const _Row(name: 'Item', qty: 'Qty', total: 'Total', bold: true),
                    for (final it in data.items)
                      _Row(
                        name: it.name,
                        qty: '${it.qty}',
                        total: ReceiptData.money(it.lineTotal),
                      ),
                    const _Dashes(),
                    if (data.discount > 0)
                      _Row(
                        name: 'Discount',
                        qty: '',
                        total: '-${ReceiptData.money(data.discount)}',
                      ),
                    _Row(
                      name: 'TOTAL',
                      qty: '',
                      total: ReceiptData.money(data.total),
                      bold: true,
                    ),
                    const _Dashes(),
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
          Expanded(flex: 6, child: Text(name, style: style)),
          Expanded(
              flex: 2,
              child: Text(qty, style: style, textAlign: TextAlign.center)),
          Expanded(
              flex: 3,
              child: Text(total, style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}
