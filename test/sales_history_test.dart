// Verifies the date-wise Sales History aggregates against known records:
//  - summary totals (net sales, profit, invoice count, payment split)
//  - day-wise breakdown grouping (days, invoices, item lines)
//  - product-wise summary (net qty + amount)
//  - returns subtract from every total
// Drives the REAL SaleRepository + SalesHistoryRepository over an in-memory DB.
import 'package:flutter_test/flutter_test.dart';
import 'package:roomi_arts_pos/core/db/database.dart';
import 'package:roomi_arts_pos/data/product_repository.dart';
import 'package:roomi_arts_pos/data/sale_repository.dart';
import 'package:roomi_arts_pos/data/sales_history_repository.dart';
import 'package:roomi_arts_pos/models/product.dart';
import 'package:roomi_arts_pos/models/sale.dart';
import 'package:roomi_arts_pos/models/sale_item.dart';

void main() {
  final products = ProductRepository();
  final sales = SaleRepository();
  final history = SalesHistoryRepository();

  // Product ids assigned during seeding below.
  late int idA; // cost 10, sell 20
  late int idB; // cost 5,  sell 15

  Future<int> idOf(String name) async =>
      (await products.getAll(search: name)).first.id!;

  Future<void> mkSale({
    required String date,
    required double total,
    required String pay,
    required List<SaleItem> items,
    String type = 'sale',
  }) async {
    await sales.completeSale(
      sale: Sale(
        invoiceNo: 'tmp', // completeSale assigns the real one
        date: date,
        totalAmount: total,
        discountAmount: 0,
        paymentType: pay,
        type: type,
      ),
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

    // 14 Jul: two invoices.
    await mkSale(date: '2026-07-14T10:00:00', total: 55, pay: 'cash', items: [
      SaleItem(productId: idA, qty: 2, priceAtSale: 20, costAtSale: 10),
      SaleItem(productId: idB, qty: 1, priceAtSale: 15, costAtSale: 5),
    ]);
    await mkSale(date: '2026-07-14T14:00:00', total: 45, pay: 'card', items: [
      SaleItem(productId: idB, qty: 3, priceAtSale: 15, costAtSale: 5),
    ]);
    // 15 Jul: one invoice (outside the single-day range).
    await mkSale(date: '2026-07-15T09:00:00', total: 20, pay: 'cash', items: [
      SaleItem(productId: idA, qty: 1, priceAtSale: 20, costAtSale: 10),
    ]);
  });

  final jul14 = DateTime(2026, 7, 14);
  final jul15 = DateTime(2026, 7, 15);
  final jul16 = DateTime(2026, 7, 16);

  test('summary totals for a single day match the records', () async {
    final s = await history.summary(jul14, jul15);
    expect(s.salesTotal, 100); // 55 + 45
    expect(s.invoiceCount, 2);
    expect(s.returnCount, 0);
    // profit: (20-10)*2 + (15-5)*1  +  (15-5)*3 = 20 + 10 + 30 = 60
    expect(s.profit, 60);
    expect(s.split.cash, 55);
    expect(s.split.card, 45);
    expect(s.split.online, 0);
  });

  test('day-wise breakdown groups invoices under their day', () async {
    final days = await history.breakdown(jul14, jul16); // 14 + 15
    expect(days.length, 2);
    // Newest day first.
    expect(days.first.day, '2026-07-15');
    expect(days.first.invoices.length, 1);

    final d14 = days.firstWhere((d) => d.day == '2026-07-14');
    expect(d14.invoices.length, 2);
    expect(d14.dayTotal, 100);

    // Invoice lines carry product name + qty + line amount.
    final withTwoItems = d14.invoices.firstWhere((i) => i.items.length == 2);
    final names = withTwoItems.items.map((e) => e.name).toSet();
    expect(names, {'A pen', 'B copy'});
    final aLine = withTwoItems.items.firstWhere((e) => e.name == 'A pen');
    expect(aLine.qty, 2);
    expect(aLine.amount, 40); // 20 * 2
  });

  test('product-wise summary is net qty + amount, biggest first', () async {
    final ps = await history.productSummary(jul14, jul15);
    expect(ps.length, 2);
    // B: 1 + 3 = 4 sold; A: 2 sold. Sorted qty desc -> B first.
    expect(ps.first.name, 'B copy');
    expect(ps.first.qty, 4);
    expect(ps.first.amount, 60); // 15 * 4
    final a = ps.firstWhere((p) => p.name == 'A pen');
    expect(a.qty, 2);
    expect(a.amount, 40);
  });

  test('returns subtract from totals, split and product summary', () async {
    // Return 1x B copy on 14 Jul (price 15). Insert as a return sale row.
    await mkSale(
      date: '2026-07-14T16:00:00',
      total: 15,
      pay: 'cash',
      type: 'return',
      items: [SaleItem(productId: idB, qty: 1, priceAtSale: 15, costAtSale: 5)],
    );

    final s = await history.summary(jul14, jul15);
    expect(s.salesTotal, 85); // 100 - 15
    expect(s.invoiceCount, 2); // sales only
    expect(s.returnCount, 1);
    expect(s.profit, 50); // 60 - (15-5)*1
    expect(s.split.cash, 40); // 55 - 15
    expect(s.split.card, 45);

    // B net qty now 4 - 1 = 3.
    final ps = await history.productSummary(jul14, jul15);
    final b = ps.firstWhere((p) => p.name == 'B copy');
    expect(b.qty, 3);
    expect(b.amount, 45); // 60 - 15
  });
}
