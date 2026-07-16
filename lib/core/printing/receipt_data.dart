import '../../models/sale.dart';
import '../../models/sale_item.dart';
import '../constants.dart';

/// One printed line on the receipt: item name, quantity, line total.
class ReceiptItemLine {
  final String name;
  final int qty;
  final double lineTotal;
  const ReceiptItemLine(this.name, this.qty, this.lineTotal);
}

/// The receipt as plain data — the SINGLE source of truth for the layout. Both
/// the Windows thermal printer (ESC/POS bytes) and the Mac/desktop on-screen
/// preview render from this exact same object, so they always match.
class ReceiptData {
  final String shopName;
  final String subtitle;
  final String invoiceNo;
  final String dateText;
  final String paymentText;
  final bool isReturn;
  final List<ReceiptItemLine> items;
  final double discount;
  final double total;
  final String footer;

  const ReceiptData({
    required this.shopName,
    required this.subtitle,
    required this.invoiceNo,
    required this.dateText,
    required this.paymentText,
    required this.isReturn,
    required this.items,
    required this.discount,
    required this.total,
    required this.footer,
  });

  factory ReceiptData.from({
    required Sale sale,
    required List<SaleItem> items,
    required Map<int, String> names,
  }) {
    final dt = DateTime.tryParse(sale.date) ?? DateTime.now();
    return ReceiptData(
      shopName: AppText.shopName,
      subtitle: 'Stationery Shop',
      invoiceNo: sale.invoiceNo,
      dateText: fmtDate(dt),
      paymentText: sale.paymentType == 'cash' ? 'Cash' : 'Card',
      isReturn: sale.type == 'return',
      items: [
        for (final it in items)
          ReceiptItemLine(
            names[it.productId] ?? 'Item',
            it.qty,
            it.priceAtSale * it.qty,
          ),
      ],
      discount: sale.discountAmount,
      total: sale.totalAmount,
      footer: 'Thank you! Please come again.',
    );
  }

  /// Whole rupees, no decimals — matches the thermal print formatting.
  static String money(double v) => v.toStringAsFixed(0);

  static String fmtDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour < 12 ? 'AM' : 'PM';
    return '${two(d.day)}/${two(d.month)}/${d.year}  '
        '${two(h12)}:${two(d.minute)} $ampm';
  }
}
