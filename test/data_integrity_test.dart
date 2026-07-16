// Data-integrity guards driven through the REAL repositories/controllers on an
// in-memory database: overselling is blocked, over-returning is blocked,
// invoice numbers are unique and increment, and edge cases behave.
import 'package:flutter_test/flutter_test.dart';
import 'package:roomi_arts_pos/core/db/database.dart';
import 'package:roomi_arts_pos/data/product_repository.dart';
import 'package:roomi_arts_pos/data/sale_repository.dart';
import 'package:roomi_arts_pos/models/product.dart';
import 'package:roomi_arts_pos/modules/return_screen/return_controller.dart';
import 'package:roomi_arts_pos/modules/sale/sale_controller.dart';

Future<Product> _first(ProductRepository repo, String name) async {
  final all = await repo.getAll(search: name);
  return all.first;
}

void main() {
  final products = ProductRepository();
  final sales = SaleRepository();

  setUp(() async {
    await AppDatabase.instance.initInMemory();
  });

  test('OVERSELL: selling more than stock is blocked and nothing is saved',
      () async {
    await products.insert(const Product(
        name: 'Rare pen', category: 'Pens', costPrice: 5, sellingPrice: 10,
        stockQty: 5, unit: 'piece'));
    final p = await _first(products, 'Rare pen');

    final c = SaleController();
    c.addToCart(p);
    for (var i = 0; i < 5; i++) {
      c.increase(c.cart.first); // qty = 6, stock only 5
    }
    expect(c.cart.first.qty, 6);
    expect(c.overStockLine, isNotNull); // friendly pre-check catches it

    // The database is the real guard: it throws and rolls back.
    await expectLater(
        c.completeSale(), throwsA(isA<InsufficientStockException>()));

    // Stock untouched, no sale saved.
    expect((await _first(products, 'Rare pen')).stockQty, 5);
    expect((await sales.listSales()).isEmpty, isTrue);
  });

  test('OVER-RETURN: cannot return more than was bought, across sessions',
      () async {
    await products.insert(const Product(
        name: 'Note pad', category: 'School', costPrice: 10, sellingPrice: 20,
        stockQty: 10, unit: 'piece'));
    final p = await _first(products, 'Note pad');

    // Sell 3.
    final c = SaleController();
    c.addToCart(p);
    c.increase(c.cart.first);
    c.increase(c.cart.first); // qty 3
    final sold = await c.completeSale();

    // Return 2 now.
    final rc = ReturnController();
    rc.invoiceInput.value = sold.sale.invoiceNo;
    await rc.lookup();
    rc.setReturnQty(rc.lines.first, 2);
    await rc.confirm();

    // Look the sale up again: only 1 piece should still be returnable.
    final rc2 = ReturnController();
    rc2.invoiceInput.value = sold.sale.invoiceNo;
    await rc2.lookup();
    expect(rc2.lines.first.alreadyReturned, 2);
    expect(rc2.lines.first.maxQty, 1);

    // The clamp keeps the UI honest...
    rc2.setReturnQty(rc2.lines.first, 5);
    expect(rc2.lines.first.returnQty, 1);

    // Stock is back to 10 - 3 + 2 = 9.
    expect((await _first(products, 'Note pad')).stockQty, 9);
  });

  test('INVOICE NUMBERS: unique and incrementing', () async {
    await products.insert(const Product(
        name: 'Any', category: 'Pens', costPrice: 1, sellingPrice: 2,
        stockQty: 100, unit: 'piece'));
    final p = await _first(products, 'Any');

    Future<String> sellOne() async {
      final c = SaleController();
      c.addToCart(p);
      final s = await c.completeSale();
      return s.sale.invoiceNo;
    }

    final a = await sellOne();
    final b = await sellOne();
    final cc = await sellOne();
    expect(a, 'INV-000001');
    expect(b, 'INV-000002');
    expect(cc, 'INV-000003');
    expect({a, b, cc}.length, 3); // all unique
  });

  test('EMPTY CART: cannot complete', () async {
    final c = SaleController();
    expect(c.cart.isEmpty, isTrue);
    expect(c.canComplete, isFalse);
  });

  test('BIG DISCOUNT flag trips above the cashier limit', () async {
    await products.insert(const Product(
        name: 'Item', category: 'Pens', costPrice: 10, sellingPrice: 100,
        stockQty: 10, unit: 'piece'));
    final p = await _first(products, 'Item');
    final c = SaleController();
    c.addToCart(p); // subtotal 100

    c.discountKind.value = DiscountKind.percent;
    c.discountValue.value = 10; // 10% -> allowed
    expect(c.isBigDiscount, isFalse);

    c.discountValue.value = 50; // 50% -> big
    expect(c.isBigDiscount, isTrue);

    // Same idea when expressed as rupees.
    c.discountKind.value = DiscountKind.amount;
    c.discountValue.value = 15; // 15 of 100 = 15% -> allowed
    expect(c.isBigDiscount, isFalse);
    c.discountValue.value = 40; // 40 of 100 = 40% -> big
    expect(c.isBigDiscount, isTrue);
  });

  test('NEGATIVE/ZERO: discount clamps to [0, subtotal], never negative total',
      () async {
    await products.insert(const Product(
        name: 'Z', category: 'Pens', costPrice: 1, sellingPrice: 50,
        stockQty: 10, unit: 'piece'));
    final p = await _first(products, 'Z');
    final c = SaleController();
    c.addToCart(p); // subtotal 50

    c.discountKind.value = DiscountKind.amount;
    c.discountValue.value = 999; // more than the bill
    expect(c.discountAmount, 50); // clamped to subtotal
    expect(c.total, 0); // never below zero
    expect(c.canComplete, isTrue);
  });

  test('LARGE NUMBERS: no overflow or formatting break', () async {
    await products.insert(const Product(
        name: 'Bulk', category: 'Pens', costPrice: 1000, sellingPrice: 100000,
        stockQty: 1000000, unit: 'piece'));
    final p = await _first(products, 'Bulk');
    final c = SaleController();
    c.addToCart(p);
    for (var i = 0; i < 999; i++) {
      c.increase(c.cart.first); // qty 1000
    }
    expect(c.subtotal, 100000000); // 100k * 1000
    final saved = await c.completeSale();
    expect(saved.sale.totalAmount, 100000000);
    expect((await _first(products, 'Bulk')).stockQty, 999000);
  });
}
