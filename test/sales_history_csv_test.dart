// Verifies the Sales History CSV export: it contains exactly the selected
// range (no more, no less), the right columns, correct per-item rows and
// totals, a matching filename, and graceful handling of empty ranges.
import 'package:flutter_test/flutter_test.dart';
import 'package:roomi_arts_pos/core/db/database.dart';
import 'package:roomi_arts_pos/data/product_repository.dart';
import 'package:roomi_arts_pos/data/sale_repository.dart';
import 'package:roomi_arts_pos/models/product.dart';
import 'package:roomi_arts_pos/models/sale.dart';
import 'package:roomi_arts_pos/models/sale_item.dart';
import 'package:roomi_arts_pos/modules/sales_history/sales_history_controller.dart';

void main() {
  final products = ProductRepository();
  final sales = SaleRepository();
  late int idA; // cost 10, sell 20
  late int idB; // cost 5,  sell 15

  Future<int> idOf(String name) async =>
      (await products.getAll(search: name)).first.id!;

  Future<void> mkSale({
    required String date,
    required double total,
    required String pay,
    required List<SaleItem> items,
    String? cashier,
  }) async {
    await sales.completeSale(
      sale: Sale(
          invoiceNo: 'tmp',
          date: date,
          totalAmount: total,
          discountAmount: 0,
          paymentType: pay,
          type: 'sale',
          cashier: cashier),
      items: items,
    );
  }

  setUp(() async {
    await AppDatabase.instance.initInMemory();
    await products.insert(const Product(
        name: 'A pen', category: 'Pens', costPrice: 10, sellingPrice: 20,
        stockQty: 100, unit: 'piece'));
    await products.insert(const Product(
        name: 'B copy', category: 'Copies', costPrice: 5, sellingPrice: 15,
        stockQty: 100, unit: 'piece'));
    idA = await idOf('A pen');
    idB = await idOf('B copy');

    await mkSale(
        date: '2026-07-14T10:00:00',
        total: 55,
        pay: 'cash',
        cashier: 'Ali',
        items: [
          SaleItem(productId: idA, qty: 2, priceAtSale: 20, costAtSale: 10),
          SaleItem(productId: idB, qty: 1, priceAtSale: 15, costAtSale: 5),
        ]);
    await mkSale(date: '2026-07-14T14:00:00', total: 45, pay: 'card', items: [
      SaleItem(productId: idB, qty: 3, priceAtSale: 15, costAtSale: 5),
    ]);
    await mkSale(date: '2026-07-15T09:00:00', total: 20, pay: 'cash', items: [
      SaleItem(productId: idA, qty: 1, priceAtSale: 20, costAtSale: 10),
    ]);
  });

  Future<SalesHistoryController> loadedFor(DateTime day) async {
    final c = SalesHistoryController();
    c.setSingleDay(day);
    await c.load();
    return c;
  }

  test('single day export contains only that day and the right filename',
      () async {
    final c = await loadedFor(DateTime(2026, 7, 14));
    expect(c.suggestedCsvName(), 'roomi_sales_2026-07-14.csv');
    final csv = c.buildCsv();

    // Column header present.
    expect(
        csv,
        contains(
            'Invoice,Date,Time,Item,Quantity,Rate,Amount,Discount,Total,Payment,Cashier'));
    // Summary matches the on-screen numbers.
    expect(csv, contains('Total sales,100'));
    expect(csv, contains('Total profit,60'));
    expect(csv, contains('Invoices,2'));
    expect(csv, contains('Cash,55'));
    expect(csv, contains('Card,45'));

    // The 15 Jul invoice (INV-000003) must NOT be in a 14 Jul export.
    expect(csv.contains('INV-000003'), isFalse);
    expect(csv, contains('INV-000001'));
    expect(csv, contains('INV-000002'));

    // Per-item row: A pen, qty 2, rate 20.00, amount 40, total 55, Cash, Ali.
    expect(csv, contains('INV-000001,2026-07-14'));
    expect(csv, contains('A pen,2,20.00,40,0,55,Cash,Ali'));
    expect(csv, contains('B copy,3,15.00,45,0,45,Card,')); // no cashier set
  });

  test('range export uses a range filename and includes both days', () async {
    final c = SalesHistoryController();
    c.setRange(DateTime(2026, 7, 14), DateTime(2026, 7, 15));
    await c.load();
    expect(c.suggestedCsvName(), 'roomi_sales_2026-07-14_to_2026-07-15.csv');
    final csv = c.buildCsv();
    expect(csv, contains('INV-000001')); // 14 Jul
    expect(csv, contains('INV-000003')); // 15 Jul
  });

  test('empty range reports no sales and is safe to skip', () async {
    final c = await loadedFor(DateTime(2026, 1, 1));
    expect(c.hasSales, isFalse);
    expect(c.days, isEmpty);
  });
}
