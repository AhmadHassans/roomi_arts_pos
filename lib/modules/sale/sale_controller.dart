import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../core/constants.dart';
import '../../data/product_repository.dart';
import '../../data/sale_repository.dart';
import '../../models/product.dart';
import '../../models/sale.dart';
import '../../models/sale_item.dart';
import '../stock/stock_controller.dart';

/// One line in the cart: a product plus how many.
class CartLine {
  final Product product;
  int qty;
  CartLine(this.product, {this.qty = 1});

  double get unitPrice => product.sellingPrice;
  double get lineTotal => unitPrice * qty;
}

/// Kind of discount the owner is applying to the whole bill.
enum DiscountKind { percent, amount }

/// The result of completing a sale: the saved sale, its lines, and the product
/// names (everything the receipt needs).
typedef SaleCompletion = ({
  Sale sale,
  List<SaleItem> items,
  Map<int, String> names,
});

/// Drives the Sale (home) screen: search, cart, discount, total, complete sale.
class SaleController extends GetxController {
  final ProductRepository _products = ProductRepository();
  final SaleRepository _sales = SaleRepository();

  // Live product search results (for the search list).
  final results = <Product>[].obs;
  final search = ''.obs;
  final activeCategory = RxnString(); // set by the category buttons
  final searchController = TextEditingController();

  // The cart.
  final cart = <CartLine>[].obs;

  // Whole-bill discount.
  final discountKind = DiscountKind.percent.obs;
  final discountValue = 0.0.obs; // percent (0-100) OR fixed amount

  // Payment.
  final paymentCash = true.obs; // true = Cash, false = Card

  @override
  void onInit() {
    super.onInit();
    _loadResults();
  }

  // ---- Search ----
  void onSearchChanged(String value) {
    search.value = value;
    // Typing a search clears any active category filter.
    if (value.trim().isNotEmpty) activeCategory.value = null;
    _loadResults();
  }

  /// Tap a category button: filter by that category (tap again to clear).
  void selectCategory(String cat) {
    activeCategory.value = activeCategory.value == cat ? null : cat;
    search.value = '';
    searchController.clear();
    _loadResults();
  }

  Future<void> _loadResults() async {
    results.value = await _products.getAll(
      search: search.value,
      category: activeCategory.value,
    );
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  // ---- Barcode: scanner types the code + Enter. Find by exact barcode. ----
  Future<void> onBarcodeSubmitted(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;
    final p = await _products.getByBarcode(trimmed);
    if (p == null) {
      Get.snackbar('Not found', 'No product with that barcode',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    addToCart(p);
  }

  // ---- Cart actions ----
  void addToCart(Product p) {
    final i = cart.indexWhere((l) => l.product.id == p.id);
    if (i >= 0) {
      cart[i].qty += 1;
    } else {
      cart.add(CartLine(p));
    }
    cart.refresh();
  }

  void increase(CartLine line) {
    line.qty += 1;
    cart.refresh();
  }

  void decrease(CartLine line) {
    line.qty -= 1;
    if (line.qty <= 0) {
      cart.remove(line);
    }
    cart.refresh();
  }

  void removeLine(CartLine line) {
    cart.remove(line);
    cart.refresh();
  }

  void clearCart() {
    cart.clear();
    discountValue.value = 0;
  }

  // ---- Money ----
  double get subtotal =>
      cart.fold(0.0, (sum, l) => sum + l.lineTotal);

  /// Discount in money, clamped so it never exceeds the subtotal.
  double get discountAmount {
    if (subtotal <= 0) return 0;
    final raw = discountKind.value == DiscountKind.percent
        ? subtotal * (discountValue.value / 100.0)
        : discountValue.value;
    return raw.clamp(0, subtotal).toDouble();
  }

  double get total => subtotal - discountAmount;

  bool get canComplete => cart.isNotEmpty && total >= 0;

  /// The discount expressed as a percentage of the subtotal (0 when empty).
  double get discountPercentOfSubtotal =>
      subtotal <= 0 ? 0 : (discountAmount / subtotal) * 100;

  /// True when the discount is larger than a cashier is allowed to give on
  /// their own — the UI requires an owner to be logged in for this.
  bool get isBigDiscount =>
      discountPercentOfSubtotal > kCashierMaxDiscountPercent + 0.0001;

  /// First cart line asking for more than the product's known stock, or null.
  /// A friendly pre-check; the database is the real guard against overselling.
  CartLine? get overStockLine {
    for (final l in cart) {
      if (l.qty > l.product.stockQty) return l;
    }
    return null;
  }

  // ---- Complete sale ----
  /// Builds sale + lines with discount-aware per-unit price, saves, reduces
  /// stock. Returns the saved sale + items so the receipt can be shown (M3).
  ///
  /// Throws [InsufficientStockException] (and leaves the cart untouched) if the
  /// database rejects the sale for lack of stock.
  Future<SaleCompletion> completeSale() async {
    final sub = subtotal;
    final disc = discountAmount;
    // Fraction of price the customer actually pays after the whole-bill discount.
    final payFraction = sub <= 0 ? 1.0 : (sub - disc) / sub;

    final items = cart.map((l) {
      final priceAfter = l.unitPrice * payFraction; // per-unit AFTER discount
      return SaleItem(
        productId: l.product.id!,
        qty: l.qty,
        priceAtSale: priceAfter,
        costAtSale: l.product.costPrice,
      );
    }).toList();

    // Product names for the receipt (cart still holds them here).
    final names = {for (final l in cart) l.product.id!: l.product.name};

    final draft = Sale(
      invoiceNo: '', // the real number is assigned inside the transaction
      date: DateTime.now().toIso8601String(),
      totalAmount: total,
      discountAmount: disc,
      paymentType: paymentCash.value ? 'cash' : 'card',
      type: 'sale',
    );

    // May throw InsufficientStockException -> nothing below runs, cart stays.
    final result = await _sales.completeSale(sale: draft, items: items);

    final sale = Sale(
      invoiceNo: result.invoiceNo,
      date: draft.date,
      totalAmount: draft.totalAmount,
      discountAmount: draft.discountAmount,
      paymentType: draft.paymentType,
      type: 'sale',
    );

    // If the Stock screen is loaded, refresh it so stock shows the new numbers.
    if (Get.isRegistered<StockController>()) {
      await Get.find<StockController>().load();
    }

    final saved = (sale: sale, items: items, names: names);
    clearCart();
    _loadResults(); // stock numbers in the search list changed
    return saved;
  }
}
