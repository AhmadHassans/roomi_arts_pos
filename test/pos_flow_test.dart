// End-to-end logic test. Drives the REAL repositories and controllers against
// an in-memory database, so it verifies the actual code paths used by the app:
//  - sale reduces stock and saves with discount-aware price_at_sale
//  - profit = (price_at_sale - cost_at_sale) * qty
//  - return refunds price_at_sale (NOT current selling price) and restores stock
//  - reports subtract returns
import 'package:flutter_test/flutter_test.dart';
import 'package:roomi_arts_pos/core/db/database.dart';
import 'package:roomi_arts_pos/data/product_repository.dart';
import 'package:roomi_arts_pos/data/reports_repository.dart';
import 'package:roomi_arts_pos/models/product.dart';
import 'package:roomi_arts_pos/modules/return_screen/return_controller.dart';
import 'package:roomi_arts_pos/modules/sale/sale_controller.dart';

Future<Product> _first(ProductRepository repo, String name) async {
  final all = await repo.getAll(search: name);
  return all.first;
}

void main() {
  final products = ProductRepository();
  final reports = ReportsRepository();

  setUp(() async {
    await AppDatabase.instance.initInMemory();
  });

  test('seed inserts the sample catalogue with low-stock items', () async {
    await products.seedIfEmpty();
    expect(await products.count(), 20);
    final low = await reports.lowStock(5);
    // Black gel pen (3), Sharpener (2), Square copy (4)
    expect(low.length, 3);
  });

  test('SALE: discount-aware price, stock decrease, sale saved', () async {
    // One product: cost 10, sell 20, stock 100.
    await products.insert(const Product(
        name: 'Test pen', category: 'Pens', costPrice: 10, sellingPrice: 20,
        stockQty: 100, unit: 'piece'));
    final p = await _first(products, 'Test pen');

    final c = SaleController();
    c.addToCart(p);
    c.increase(c.cart.first); // qty = 2
    c.discountKind.value = DiscountKind.percent;
    c.discountValue.value = 10; // 10% off whole bill

    expect(c.subtotal, 40); // 20 * 2
    expect(c.discountAmount, 4); // 10% of 40
    expect(c.total, 36);

    final saved = await c.completeSale();

    // price_at_sale is the discounted per-unit price: 20 * 0.9 = 18
    expect(saved.items.first.priceAtSale, closeTo(18, 0.001));
    expect(saved.items.first.costAtSale, 10);
    expect(saved.sale.totalAmount, 36);
    expect(saved.sale.type, 'sale');

    // Stock reduced by 2.
    final after = await _first(products, 'Test pen');
    expect(after.stockQty, 98);

    // Reports: profit = (18 - 10) * 2 = 16 today.
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    expect(await reports.profitTotal(start, end), closeTo(16, 0.001));
    expect(await reports.salesTotal(start, end), closeTo(36, 0.001));
  });

  test('RETURN: refunds price_at_sale not current price, restores stock',
      () async {
    // Product sold at a discount; later the selling price CHANGES.
    await products.insert(const Product(
        name: 'Gel pen', category: 'Pens', costPrice: 10, sellingPrice: 20,
        stockQty: 50, unit: 'piece'));
    final p = await _first(products, 'Gel pen');

    // Sell 2 at 25% discount -> price_at_sale = 15 each.
    final c = SaleController();
    c.addToCart(p);
    c.increase(c.cart.first);
    c.discountValue.value = 25;
    final sold = await c.completeSale();
    expect(sold.items.first.priceAtSale, closeTo(15, 0.001));

    // Owner raises the selling price AFTER the sale.
    final refreshed = await _first(products, 'Gel pen');
    await products.update(refreshed.copyWith(sellingPrice: 40));
    expect((await _first(products, 'Gel pen')).stockQty, 48); // sold 2

    // Return 1 piece via the real ReturnController.
    final rc = ReturnController();
    rc.invoiceInput.value = sold.sale.invoiceNo;
    await rc.lookup();
    expect(rc.lines.length, 1);
    rc.setReturnQty(rc.lines.first, 1);

    // Refund must use the discounted price actually charged (15), NOT 40.
    expect(rc.refundTotal, closeTo(15, 0.001));

    final res = await rc.confirm();
    expect(res.difference, closeTo(-15, 0.001)); // refund to customer

    // Stock restored by 1 -> 49.
    expect((await _first(products, 'Gel pen')).stockQty, 49);

    // Reports: net today = sale(30) - refund(15) = 15.
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    expect(await reports.salesTotal(start, end), closeTo(15, 0.001));
    // Profit: sale (15-10)*2=10 ; return subtracts (15-10)*1=5 -> 5.
    expect(await reports.profitTotal(start, end), closeTo(5, 0.001));
  });

  test('EXCHANGE: return one item + add another, price difference', () async {
    await products.insert(const Product(
        name: 'Cheap item', category: 'Pens', costPrice: 5, sellingPrice: 10,
        stockQty: 30, unit: 'piece'));
    await products.insert(const Product(
        name: 'Pricey item', category: 'Pens', costPrice: 20, sellingPrice: 50,
        stockQty: 30, unit: 'piece'));
    final cheap = await _first(products, 'Cheap item');
    final pricey = await _first(products, 'Pricey item');

    // Sell 1 cheap item, no discount -> price_at_sale 10.
    final c = SaleController();
    c.addToCart(cheap);
    final sold = await c.completeSale();

    final rc = ReturnController();
    rc.invoiceInput.value = sold.sale.invoiceNo;
    await rc.lookup();
    rc.setReturnQty(rc.lines.first, 1); // return the cheap item (refund 10)
    rc.addReplacement(pricey); // take the pricey item (50)

    expect(rc.refundTotal, closeTo(10, 0.001));
    expect(rc.replacementTotal, closeTo(50, 0.001));
    expect(rc.difference, closeTo(40, 0.001)); // customer pays 40

    await rc.confirm();

    // Cheap restored (+1 -> 30), pricey reduced (-1 -> 29).
    expect((await _first(products, 'Cheap item')).stockQty, 30);
    expect((await _first(products, 'Pricey item')).stockQty, 29);
  });

  test('SALE category filter returns that category (not name match)', () async {
    await products.seedIfEmpty();
    // No product NAME contains "Pens", so only a category filter can work.
    final byName = await products.getAll(search: 'Pens');
    expect(byName, isEmpty);
    final byCategory = await products.getAll(category: 'Pens');
    expect(byCategory.isNotEmpty, true);
    expect(byCategory.every((p) => p.category == 'Pens'), true);
  });

  test('STOCK: add stock increases quantity', () async {
    await products.insert(const Product(
        name: 'Box item', category: 'Art', costPrice: 5, sellingPrice: 9,
        stockQty: 0, unit: 'piece'));
    final p = await _first(products, 'Box item');
    await products.addStock(p.id!, 24); // a box of 24 arrives
    expect((await _first(products, 'Box item')).stockQty, 24);
  });
}
