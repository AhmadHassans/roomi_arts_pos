import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../core/db/database.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';

/// Raised (inside a transaction, so it rolls back) when a sale would take more
/// pieces than are in stock. The whole sale is cancelled — never a partial save.
class InsufficientStockException implements Exception {
  final int productId;
  const InsufficientStockException(this.productId);
  @override
  String toString() => 'Not enough stock for product $productId';
}

/// Raised when a return would give back more pieces than were bought on that
/// invoice (counting anything already returned). Rolls the return back.
class OverReturnException implements Exception {
  final int productId;
  const OverReturnException(this.productId);
  @override
  String toString() => 'Returning more than was sold for product $productId';
}

/// All sale/return database access. Keeps SQL out of the UI/controllers.
class SaleRepository {
  Database get _db => AppDatabase.instance.db;

  /// Invoice number for the NEXT sale, formatted INV-000123, for display only
  /// (e.g. a preview). The number actually saved is generated inside the
  /// transaction by [_nextInvoiceNoTxn] so two saves can never collide.
  Future<String> nextInvoiceNo() async {
    final row =
        await _db.rawQuery('SELECT COALESCE(MAX(id), 0) AS n FROM sales');
    final n = (row.first['n'] as num).toInt() + 1;
    return _formatInvoice(n);
  }

  static String _formatInvoice(int n) => 'INV-${n.toString().padLeft(6, '0')}';

  /// Generate the invoice number inside a live transaction. Because the write
  /// transaction is serialized, MAX(id)+1 is stable here, so the number is
  /// unique by construction (and the UNIQUE column is a final backstop).
  Future<String> _nextInvoiceNoTxn(Transaction txn) async {
    final row =
        await txn.rawQuery('SELECT COALESCE(MAX(id), 0) AS n FROM sales');
    return _formatInvoice((row.first['n'] as num).toInt() + 1);
  }

  /// Browse past sales/returns for the Sales-records screen, newest first.
  ///
  /// [query] matches the invoice number (partial). [type] is 'all', 'sale' or
  /// 'return'. [from]/[to] bound the date range ([from] inclusive, [to]
  /// exclusive). All filters are optional and combine with AND.
  Future<List<Sale>> listSales({
    String query = '',
    String type = 'all',
    DateTime? from,
    DateTime? to,
    int limit = 500,
  }) async {
    final where = <String>[];
    final args = <Object?>[];

    if (type == 'sale' || type == 'return') {
      where.add('type = ?');
      args.add(type);
    }
    final q = query.trim();
    if (q.isNotEmpty) {
      where.add('invoice_no LIKE ?');
      args.add('%$q%');
    }
    if (from != null) {
      where.add('date >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('date < ?');
      args.add(to.toIso8601String());
    }

    final rows = await _db.query(
      'sales',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'date DESC, id DESC',
      limit: limit,
    );
    return rows.map(Sale.fromMap).toList();
  }

  /// Find a past sale by its invoice number (used by the Return screen).
  Future<Sale?> getSaleByInvoice(String invoiceNo) async {
    final rows = await _db.query('sales',
        where: 'invoice_no = ?', whereArgs: [invoiceNo.trim()], limit: 1);
    if (rows.isEmpty) return null;
    return Sale.fromMap(rows.first);
  }

  /// All line items for a sale.
  Future<List<SaleItem>> itemsForSale(int saleId) async {
    final rows = await _db.query('sale_items',
        where: 'sale_id = ?', whereArgs: [saleId]);
    return rows.map(SaleItem.fromMap).toList();
  }

  /// Look up product names for a set of ids (to show on the Return screen).
  Future<Map<int, String>> namesForProductIds(List<int> ids) async {
    if (ids.isEmpty) return {};
    final marks = List.filled(ids.length, '?').join(',');
    final rows = await _db.rawQuery(
        'SELECT id, name FROM products WHERE id IN ($marks)', ids);
    return {for (final r in rows) r['id'] as int: r['name'] as String};
  }

  /// How many pieces of each product have ALREADY been returned against
  /// [originalInvoiceNo]. Used by the Return screen so it only offers the
  /// pieces still returnable.
  Future<Map<int, int>> returnedQtyForInvoice(String originalInvoiceNo) async {
    final rows = await _db.rawQuery('''
      SELECT si.product_id AS pid, COALESCE(SUM(si.qty), 0) AS q
      FROM sale_items si
      JOIN sales s ON s.id = si.sale_id
      WHERE s.type = 'return' AND s.ref_invoice_no = ?
      GROUP BY si.product_id
    ''', [originalInvoiceNo]);
    return {for (final r in rows) r['pid'] as int: (r['q'] as num).toInt()};
  }

  /// Save a return and put the returned pieces BACK into stock — one
  /// transaction. Refund lines carry the original price_at_sale (discount-aware).
  ///
  /// Blocks over-returning: for each product, (already returned + this return)
  /// can never exceed how many were bought on the original sale. The whole
  /// return rolls back if any line would exceed that.
  Future<({int id, String invoiceNo})> saveReturn({
    required Sale returnSale,
    required List<SaleItem> returnedItems,
    required int originalSaleId,
    required String originalInvoiceNo,
  }) async {
    return _db.transaction((txn) async {
      final invoiceNo = await _nextInvoiceNoTxn(txn);
      final map = returnSale.toMap()
        ..['invoice_no'] = invoiceNo
        ..['ref_invoice_no'] = originalInvoiceNo;
      final id = await txn.insert('sales', map);

      for (final it in returnedItems) {
        final sold = await _soldQty(txn, originalSaleId, it.productId);
        final already =
            await _returnedQty(txn, originalInvoiceNo, it.productId, id);
        if (already + it.qty > sold) {
          throw OverReturnException(it.productId);
        }
        await txn.insert('sale_items', it.copyForSale(id).toMap());
        // Put returned pieces back into stock.
        await txn.rawUpdate(
          'UPDATE products SET stock_qty = stock_qty + ? WHERE id = ?',
          [it.qty, it.productId],
        );
      }
      return (id: id, invoiceNo: invoiceNo);
    });
  }

  /// Pieces of [productId] bought on the original sale [saleId].
  Future<int> _soldQty(Transaction txn, int saleId, int productId) async {
    final r = await txn.rawQuery(
      'SELECT COALESCE(SUM(qty), 0) AS q FROM sale_items '
      'WHERE sale_id = ? AND product_id = ?',
      [saleId, productId],
    );
    return (r.first['q'] as num).toInt();
  }

  /// Pieces of [productId] already returned against [originalInvoiceNo],
  /// excluding the return currently being written ([excludeSaleId]).
  Future<int> _returnedQty(Transaction txn, String originalInvoiceNo,
      int productId, int excludeSaleId) async {
    final r = await txn.rawQuery('''
      SELECT COALESCE(SUM(si.qty), 0) AS q
      FROM sale_items si
      JOIN sales s ON s.id = si.sale_id
      WHERE s.type = 'return' AND s.ref_invoice_no = ?
        AND si.product_id = ? AND s.id <> ?
    ''', [originalInvoiceNo, productId, excludeSaleId]);
    return (r.first['q'] as num).toInt();
  }

  /// Save a completed sale and its lines, and reduce product stock — all in one
  /// transaction so nothing is half-saved. Returns the new sale id and the
  /// invoice number that was assigned.
  ///
  /// Blocks overselling: each line only saves if that many pieces are actually
  /// in stock; otherwise the whole sale rolls back with
  /// [InsufficientStockException].
  Future<({int id, String invoiceNo})> completeSale({
    required Sale sale,
    required List<SaleItem> items,
  }) async {
    return _db.transaction((txn) async {
      final invoiceNo = await _nextInvoiceNoTxn(txn);
      final map = sale.toMap()..['invoice_no'] = invoiceNo;
      final saleId = await txn.insert('sales', map);

      for (final it in items) {
        // Atomic guard: subtract only when enough stock remains. A rowcount of
        // 0 means not enough stock -> throw so the transaction rolls back.
        final updated = await txn.rawUpdate(
          'UPDATE products SET stock_qty = stock_qty - ? '
          'WHERE id = ? AND stock_qty >= ?',
          [it.qty, it.productId, it.qty],
        );
        if (updated != 1) {
          throw InsufficientStockException(it.productId);
        }
        await txn.insert('sale_items', it.copyForSale(saleId).toMap());
      }
      return (id: saleId, invoiceNo: invoiceNo);
    });
  }
}

extension _SaleItemSaleId on SaleItem {
  /// Copy this line attaching a sale id (lines are built before the sale exists).
  SaleItem copyForSale(int saleId) => SaleItem(
        id: id,
        saleId: saleId,
        productId: productId,
        qty: qty,
        priceAtSale: priceAtSale,
        costAtSale: costAtSale,
      );
}
