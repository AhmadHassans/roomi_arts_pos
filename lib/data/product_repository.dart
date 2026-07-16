import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../core/db/database.dart';
import '../models/product.dart';

/// All product database access. Keeps SQL out of the UI/controllers.
class ProductRepository {
  Database get _db => AppDatabase.instance.db;

  /// List products. Optional case-insensitive partial name [search] AND/OR an
  /// exact [category] filter (used by the Sale screen category buttons).
  Future<List<Product>> getAll({String search = '', String? category}) async {
    final clauses = <String>[];
    final args = <Object?>[];
    if (search.trim().isNotEmpty) {
      clauses.add('name LIKE ?');
      args.add('%${search.trim()}%');
    }
    if (category != null && category.isNotEmpty) {
      clauses.add('category = ?');
      args.add(category);
    }
    final rows = await _db.query(
      'products',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(Product.fromMap).toList();
  }

  /// Find a product by exact barcode (used by the Sale screen scanner). M2.
  Future<Product?> getByBarcode(String barcode) async {
    final rows = await _db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  Future<int> insert(Product p) => _db.insert('products', p.toMap());

  Future<void> update(Product p) async {
    await _db.update('products', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
  }

  Future<void> delete(int id) async {
    await _db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  /// Increase stock when a new box arrives, e.g. add 24. Never goes negative.
  Future<void> addStock(int id, int amount) async {
    await _db.rawUpdate(
      'UPDATE products SET stock_qty = MAX(0, stock_qty + ?) WHERE id = ?',
      [amount, id],
    );
  }

  Future<int> count() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS n FROM products');
    return (rows.first['n'] as num).toInt();
  }

  /// Put a realistic set of stationery products in on first launch (only when
  /// the shop is empty) so the owner has something to bill/return/report on.
  Future<void> seedIfEmpty() async {
    if (await count() > 0) return;
    final batch = _db.batch();
    for (final p in _sampleProducts) {
      batch.insert('products', p.toMap());
    }
    await batch.commit(noResult: true);
  }

  // name, category, cost, selling, stock (pieces), unit, barcode
  static const List<Product> _sampleProducts = [
    Product(name: 'Blue ball pen', category: 'Pens', costPrice: 8, sellingPrice: 15, stockQty: 100, unit: 'piece', barcode: '8901000000011'),
    Product(name: 'Black ball pen', category: 'Pens', costPrice: 8, sellingPrice: 15, stockQty: 80, unit: 'piece', barcode: '8901000000028'),
    Product(name: 'Red ball pen', category: 'Pens', costPrice: 8, sellingPrice: 15, stockQty: 40, unit: 'piece', barcode: '8901000000035'),
    Product(name: 'Blue gel pen', category: 'Pens', costPrice: 18, sellingPrice: 30, stockQty: 60, unit: 'piece', barcode: '8901000000042'),
    Product(name: 'Black gel pen', category: 'Pens', costPrice: 18, sellingPrice: 30, stockQty: 3, unit: 'piece', barcode: '8901000000059'),
    Product(name: 'Marker pen', category: 'Pens', costPrice: 30, sellingPrice: 55, stockQty: 25, unit: 'piece', barcode: '8901000000066'),
    Product(name: 'Highlighter', category: 'Pens', costPrice: 25, sellingPrice: 50, stockQty: 18, unit: 'piece', barcode: '8901000000073'),
    Product(name: 'HB pencil', category: 'School', costPrice: 4, sellingPrice: 10, stockQty: 150, unit: 'piece', barcode: '8901000000080'),
    Product(name: 'Eraser', category: 'School', costPrice: 3, sellingPrice: 8, stockQty: 150, unit: 'piece', barcode: '8901000000097'),
    Product(name: 'Sharpener', category: 'School', costPrice: 5, sellingPrice: 12, stockQty: 2, unit: 'piece', barcode: '8901000000103'),
    Product(name: 'Glue stick', category: 'School', costPrice: 15, sellingPrice: 30, stockQty: 50, unit: 'piece', barcode: '8901000000110'),
    Product(name: 'Geometry box', category: 'School', costPrice: 110, sellingPrice: 180, stockQty: 15, unit: 'box', barcode: '8901000000127'),
    Product(name: 'A4 register 200pg', category: 'Copies', costPrice: 90, sellingPrice: 140, stockQty: 25, unit: 'piece', barcode: '8901000000134'),
    Product(name: 'Single line copy', category: 'Copies', costPrice: 25, sellingPrice: 45, stockQty: 120, unit: 'piece', barcode: '8901000000141'),
    Product(name: 'Four line copy', category: 'Copies', costPrice: 25, sellingPrice: 45, stockQty: 90, unit: 'piece', barcode: '8901000000158'),
    Product(name: 'Square copy', category: 'Copies', costPrice: 25, sellingPrice: 45, stockQty: 4, unit: 'piece', barcode: '8901000000165'),
    Product(name: 'Drawing copy', category: 'Art', costPrice: 40, sellingPrice: 70, stockQty: 30, unit: 'piece', barcode: '8901000000172'),
    Product(name: 'Color box (12)', category: 'Art', costPrice: 70, sellingPrice: 120, stockQty: 20, unit: 'box', barcode: '8901000000189'),
    Product(name: 'Oil pastels (24)', category: 'Art', costPrice: 120, sellingPrice: 190, stockQty: 12, unit: 'box', barcode: '8901000000196'),
    Product(name: 'Chart paper', category: 'Art', costPrice: 10, sellingPrice: 20, stockQty: 200, unit: 'piece', barcode: '8901000000202'),
  ];
}
