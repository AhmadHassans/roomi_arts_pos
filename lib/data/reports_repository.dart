import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../core/db/database.dart';

/// One day's net sales (for the bar chart).
class DailySales {
  final String day; // YYYY-MM-DD
  final double amount;
  DailySales(this.day, this.amount);
}

/// A best-selling product row.
class BestSeller {
  final String name;
  final int qty;
  BestSeller(this.name, this.qty);
}

/// Read-only aggregate queries for the Reports screen.
///
/// Money rule: sales add, returns subtract.
/// Profit = sum((price_at_sale - cost_at_sale) * qty), returns subtracted.
class ReportsRepository {
  Database get _db => AppDatabase.instance.db;

  /// Net sales amount between [start] (inclusive) and [end] (exclusive).
  Future<double> salesTotal(DateTime start, DateTime end) async {
    final rows = await _db.rawQuery('''
      SELECT COALESCE(SUM(
        CASE WHEN type = 'sale' THEN total_amount ELSE -total_amount END
      ), 0) AS net
      FROM sales
      WHERE date >= ? AND date < ?
    ''', [start.toIso8601String(), end.toIso8601String()]);
    return (rows.first['net'] as num).toDouble();
  }

  /// Net profit between [start] (inclusive) and [end] (exclusive).
  Future<double> profitTotal(DateTime start, DateTime end) async {
    final rows = await _db.rawQuery('''
      SELECT COALESCE(SUM(
        CASE WHEN s.type = 'sale'
             THEN (si.price_at_sale - si.cost_at_sale) * si.qty
             ELSE -((si.price_at_sale - si.cost_at_sale) * si.qty) END
      ), 0) AS profit
      FROM sale_items si
      JOIN sales s ON s.id = si.sale_id
      WHERE s.date >= ? AND s.date < ?
    ''', [start.toIso8601String(), end.toIso8601String()]);
    return (rows.first['profit'] as num).toDouble();
  }

  /// Net sales per day within a period (for the bar chart).
  ///
  /// Returns one entry for EVERY day in [start, end), in order. Days with no
  /// sales come back as 0 so the chart plots the whole month, not just the
  /// days that happened to have activity.
  Future<List<DailySales>> dailySales(DateTime start, DateTime end) async {
    final rows = await _db.rawQuery('''
      SELECT substr(date, 1, 10) AS day,
        COALESCE(SUM(
          CASE WHEN type = 'sale' THEN total_amount ELSE -total_amount END
        ), 0) AS net
      FROM sales
      WHERE date >= ? AND date < ?
      GROUP BY day
      ORDER BY day
    ''', [start.toIso8601String(), end.toIso8601String()]);

    // Index the rows that exist by their YYYY-MM-DD key.
    final byDay = <String, double>{
      for (final r in rows) r['day'] as String: (r['net'] as num).toDouble(),
    };

    // Walk every calendar day in the range and fill gaps with 0. Reconstruct
    // each day via DateTime(y, m, d+1) so month/DST rollover stays correct.
    final result = <DailySales>[];
    for (var d = DateTime(start.year, start.month, start.day);
        d.isBefore(end);
        d = DateTime(d.year, d.month, d.day + 1)) {
      final key = _dayKey(d);
      result.add(DailySales(key, byDay[key] ?? 0));
    }
    return result;
  }

  /// YYYY-MM-DD for a local date, matching the substr(date, 1, 10) SQL key.
  String _dayKey(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  /// Best-selling products by net quantity (sales minus returns), all time.
  Future<List<BestSeller>> bestSellers({int limit = 5}) async {
    final rows = await _db.rawQuery('''
      SELECT p.name AS name,
        SUM(CASE WHEN s.type = 'sale' THEN si.qty ELSE -si.qty END) AS qty
      FROM sale_items si
      JOIN sales s ON s.id = si.sale_id
      JOIN products p ON p.id = si.product_id
      GROUP BY si.product_id
      HAVING qty > 0
      ORDER BY qty DESC
      LIMIT ?
    ''', [limit]);
    return rows
        .map((r) => BestSeller(r['name'] as String, (r['qty'] as num).toInt()))
        .toList();
  }

  /// Products at or below the low-stock threshold.
  Future<List<({String name, int stock})>> lowStock(int threshold) async {
    final rows = await _db.rawQuery('''
      SELECT name, stock_qty FROM products
      WHERE stock_qty < ?
      ORDER BY stock_qty ASC
    ''', [threshold]);
    return rows
        .map((r) => (name: r['name'] as String, stock: (r['stock_qty'] as num).toInt()))
        .toList();
  }
}
