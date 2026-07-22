import '../../models/sale.dart';
import '../../models/sale_item.dart';
import '../constants.dart';

/// One printed line on the receipt: item name, quantity, per-unit rate, and
/// line total (rate * qty).
class ReceiptItemLine {
  final String name;
  final int qty;
  final double unitPrice; // per-unit rate (after discount)
  final double lineTotal;
  const ReceiptItemLine(this.name, this.qty, this.unitPrice, this.lineTotal);
}

/// The receipt as plain data — the SINGLE source of truth for the layout. Both
/// the Windows thermal printer (ESC/POS bytes) and the Mac/desktop on-screen
/// preview render from this exact same object, so they always match.
class ReceiptData {
  final String shopName;
  final String subtitle; // tagline under the name
  final String address;
  final String phone;
  final String invoiceNo;
  final String dateText;
  final String? cashier; // null when unknown (e.g. a reprint from Records)
  final String paymentText;
  final bool isReturn;
  final List<ReceiptItemLine> items;
  final double subtotal; // sum of line totals (before discount)
  final double discount;
  final double total;

  /// Cash handed over by the customer, when captured at checkout. Null for
  /// card sales, returns, or reprints — then the Cash received / Change lines
  /// are not printed.
  final double? cashReceived;

  final String footer;

  const ReceiptData({
    required this.shopName,
    required this.subtitle,
    required this.address,
    required this.phone,
    required this.invoiceNo,
    required this.dateText,
    required this.cashier,
    required this.paymentText,
    required this.isReturn,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.cashReceived,
    required this.footer,
  });

  /// Total pieces across all lines ("Items: N").
  int get itemsCount => items.fold(0, (sum, it) => sum + it.qty);

  /// Change to return, when cash received is known (can be negative if the
  /// customer underpaid).
  double? get changeDue =>
      cashReceived == null ? null : (cashReceived! - total);

  /// Whether the Cash received block should print.
  bool get showsCash => cashReceived != null && !isReturn;

  /// Change to give back (>= 0), or null when the customer underpaid.
  double? get changeReturn =>
      changeDue != null && changeDue! >= 0 ? changeDue : null;

  /// Amount still owed (> 0) when the customer underpaid, else null. Avoids
  /// printing a confusing negative "CHANGE RETURN".
  double? get balanceDue =>
      changeDue != null && changeDue! < 0 ? -changeDue! : null;

  factory ReceiptData.from({
    required Sale sale,
    required List<SaleItem> items,
    required Map<int, String> names,
    String? cashierName,
    double? cashReceived,
  }) {
    final dt = DateTime.tryParse(sale.date) ?? DateTime.now();
    final lines = [
      for (final it in items)
        ReceiptItemLine(
          names[it.productId] ?? 'Item',
          it.qty,
          it.priceAtSale,
          it.priceAtSale * it.qty,
        ),
    ];
    final subtotal = lines.fold(0.0, (sum, it) => sum + it.lineTotal);
    return ReceiptData(
      shopName: AppText.shopName,
      subtitle: AppText.shopTagline,
      address: AppText.shopAddress,
      phone: AppText.shopPhone,
      invoiceNo: sale.invoiceNo,
      dateText: fmtDate(dt),
      cashier: cashierName ?? sale.cashier,
      paymentText: sale.paymentType == 'cash' ? 'Cash' : 'Card',
      isReturn: sale.type == 'return',
      items: lines,
      subtotal: subtotal,
      discount: sale.discountAmount,
      total: sale.totalAmount,
      cashReceived: sale.paymentType == 'cash' ? cashReceived : null,
      footer: 'Thank you! Please come again',
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
