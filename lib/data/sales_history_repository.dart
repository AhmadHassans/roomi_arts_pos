import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../core/db/database.dart';

/// Net money taken per payment method over a period (sales add, returns
/// subtract). Only 'cash' and 'card' are recorded today; anything else is
/// bucketed into [online] so the split stays complete if that is added later.
class PaymentSplit {
  final double cash;
  final double card;
  final double online;
  const PaymentSplit({this.cash = 0, this.card = 0, this.online = 0});

  double get total => cash + card + online;
}

/// Top-of-screen totals for the selected date/range.
class HistorySummary {
  final double salesTotal; // net sales amount (returns subtracted)
  final double profit; // net profit
  final int invoiceCount; // number of 'sale' invoices
  final int returnCount; // number of 'return' invoices
  final PaymentSplit split;
  const HistorySummary({
    required this.salesTotal,
    required this.profit,
    required this.invoiceCount,
    required this.returnCount,
    required this.split,
  });
}

/// One item line inside an invoice on the breakdown (product name + quantity).
class HistoryItemLine {
  final String name;
  final int qty;
  final double amount; // line total (price_at_sale * qty)
  const HistoryItemLine(this.name, this.qty, this.amount);
}

/// One invoice on the day-wise breakdown.
class HistoryInvoice {
  final String invoiceNo;
  final DateTime dateTime;
  final String type; // 'sale' | 'return'
  final String paymentType; // 'cash' | 'card' | ...
  final double amount; // total_amount as stored (always positive)
  final double discount; // discount_amount for this invoice
  final String? cashier; // username who rang it (null on older rows)
  final List<HistoryItemLine> items;
  const HistoryInvoice({
    required this.invoiceNo,
    required this.dateTime,
    required this.type,
    required this.paymentType,
    required this.amount,
    required this.discount,
    required this.cashier,
    required this.items,
  });

  bool get isReturn => type == 'return';

  /// Signed contribution to the day total: sales add, returns subtract.
  double get signedAmount => isReturn ? -amount : amount;
}

/// All invoices for a single calendar day, plus that day's net total.
class HistoryDay {
  final String day; // YYYY-MM-DD
  final List<HistoryInvoice> invoices;
  const HistoryDay(this.day, this.invoices);

  double get dayTotal =>
      invoices.fold(0.0, (sum, inv) => sum + inv.signedAmount);
}

/// A product's net quantity sold and net amount over the range.
class ProductSold {
  final String name;
  final int qty;
  final double amount;
  const ProductSold(this.name, this.qty, this.amount);
}

/// Read-only date-wise sales history queries for the owner's History screen.
///
/// Money rule (matches [ReportsRepository]): sales add, returns subtract.
/// All ranges are [start, end): start inclusive, end exclusive. Dates are the
/// ISO-8601 local strings written when the sale was saved, so plain string
/// comparison bounds the range correctly.
class SalesHistoryRepository {
  Database get _db => AppDatabase.instance.db;

  /// Summary totals for the range: net sales, net profit, invoice/return
  /// counts, and the payment split.
  Future<HistorySummary> summary(DateTime start, DateTime end) async {
    final a = start.toIso8601String();
    final b = end.toIso8601String();

    // Net sales amount + invoice/return counts in one pass over `sales`.
    final head = await _db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'sale'
             THEN total_amount ELSE -total_amount END), 0) AS net,
        COALESCE(SUM(CASE WHEN type = 'sale'   THEN 1 ELSE 0 END), 0) AS sales_n,
        COALESCE(SUM(CASE WHEN type = 'return' THEN 1 ELSE 0 END), 0) AS returns_n
      FROM sales
      WHERE date >= ? AND date < ?
    ''', [a, b]);

    // Net profit from the line items.
    final prof = await _db.rawQuery('''
      SELECT COALESCE(SUM(
        CASE WHEN s.type = 'sale'
             THEN (si.price_at_sale - si.cost_at_sale) * si.qty
             ELSE -((si.price_at_sale - si.cost_at_sale) * si.qty) END
      ), 0) AS profit
      FROM sale_items si
      JOIN sales s ON s.id = si.sale_id
      WHERE s.date >= ? AND s.date < ?
    ''', [a, b]);

    // Net money per payment method.
    final pay = await _db.rawQuery('''
      SELECT payment_type,
        COALESCE(SUM(CASE WHEN type = 'sale'
             THEN total_amount ELSE -total_amount END), 0) AS net
      FROM sales
      WHERE date >= ? AND date < ?
      GROUP BY payment_type
    ''', [a, b]);

    var cash = 0.0, card = 0.0, online = 0.0;
    for (final r in pay) {
      final pt = (r['payment_type'] as String?)?.toLowerCase() ?? '';
      final v = (r['net'] as num).toDouble();
      if (pt == 'cash') {
        cash += v;
      } else if (pt == 'card') {
        card += v;
      } else {
        online += v; // any other/future method
      }
    }

    final h = head.first;
    return HistorySummary(
      salesTotal: (h['net'] as num).toDouble(),
      profit: (prof.first['profit'] as num).toDouble(),
      invoiceCount: (h['sales_n'] as num).toInt(),
      returnCount: (h['returns_n'] as num).toInt(),
      split: PaymentSplit(cash: cash, card: card, online: online),
    );
  }

  /// Day-wise breakdown: every invoice in the range with its lines, grouped by
  /// calendar day, newest day first (invoices within a day newest first too).
  ///
  /// One joined query, grouped in Dart, so it stays a single round-trip even
  /// for a wide range.
  Future<List<HistoryDay>> breakdown(DateTime start, DateTime end) async {
    final rows = await _db.rawQuery('''
      SELECT s.id AS sid, s.invoice_no AS invoice_no, s.date AS date,
             s.type AS type, s.payment_type AS payment_type,
             s.total_amount AS total_amount, s.discount_amount AS discount_amount,
             s.cashier AS cashier,
             p.name AS pname, si.qty AS qty, si.price_at_sale AS price
      FROM sales s
      LEFT JOIN sale_items si ON si.sale_id = s.id
      LEFT JOIN products p ON p.id = si.product_id
      WHERE s.date >= ? AND s.date < ?
      ORDER BY s.date DESC, s.id DESC
    ''', [start.toIso8601String(), end.toIso8601String()]);

    // Group flat rows -> invoices (preserving the newest-first row order).
    final invoicesById = <int, HistoryInvoice>{};
    final itemsById = <int, List<HistoryItemLine>>{};
    final order = <int>[]; // sale ids in newest-first order

    for (final r in rows) {
      final sid = (r['sid'] as num).toInt();
      if (!invoicesById.containsKey(sid)) {
        order.add(sid);
        itemsById[sid] = [];
        invoicesById[sid] = HistoryInvoice(
          invoiceNo: r['invoice_no'] as String,
          dateTime: DateTime.parse(r['date'] as String),
          type: r['type'] as String,
          paymentType: r['payment_type'] as String,
          amount: (r['total_amount'] as num).toDouble(),
          discount: (r['discount_amount'] as num?)?.toDouble() ?? 0,
          cashier: r['cashier'] as String?,
          items: itemsById[sid]!, // filled below (same list reference)
        );
      }
      // A sale with no lines (shouldn't happen) yields a null-join row.
      if (r['pname'] != null) {
        final qty = (r['qty'] as num).toInt();
        final price = (r['price'] as num).toDouble();
        itemsById[sid]!.add(HistoryItemLine(r['pname'] as String, qty, price * qty));
      }
    }

    // Group invoices by YYYY-MM-DD (order preserved -> days already newest first).
    final days = <String, List<HistoryInvoice>>{};
    final dayOrder = <String>[];
    for (final sid in order) {
      final inv = invoicesById[sid]!;
      final key = _dayKey(inv.dateTime);
      if (!days.containsKey(key)) {
        days[key] = [];
        dayOrder.add(key);
      }
      days[key]!.add(inv);
    }

    return [for (final k in dayOrder) HistoryDay(k, days[k]!)];
  }

  /// Product-wise summary over the range: net quantity and net amount per
  /// product, biggest sellers first. Products with a net quantity <= 0 (fully
  /// returned) are dropped.
  Future<List<ProductSold>> productSummary(DateTime start, DateTime end) async {
    final rows = await _db.rawQuery('''
      SELECT p.name AS name,
        SUM(CASE WHEN s.type = 'sale' THEN si.qty ELSE -si.qty END) AS qty,
        SUM(CASE WHEN s.type = 'sale'
             THEN si.price_at_sale * si.qty
             ELSE -si.price_at_sale * si.qty END) AS amount
      FROM sale_items si
      JOIN sales s ON s.id = si.sale_id
      JOIN products p ON p.id = si.product_id
      WHERE s.date >= ? AND s.date < ?
      GROUP BY si.product_id
      HAVING qty > 0
      ORDER BY qty DESC, amount DESC
    ''', [start.toIso8601String(), end.toIso8601String()]);
    return rows
        .map((r) => ProductSold(
              r['name'] as String,
              (r['qty'] as num).toInt(),
              (r['amount'] as num).toDouble(),
            ))
        .toList();
  }

  /// YYYY-MM-DD for a local date, matching the substr(date,1,10) SQL key.
  String _dayKey(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }
}
