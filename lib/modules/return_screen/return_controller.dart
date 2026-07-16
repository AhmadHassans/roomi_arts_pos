import 'package:get/get.dart';
import '../../data/product_repository.dart';
import '../../data/sale_repository.dart';
import '../../models/product.dart';
import '../../models/sale.dart';
import '../../models/sale_item.dart';
import '../sale/sale_controller.dart' show CartLine;
import '../stock/stock_controller.dart';

/// Result of confirming a return/exchange: the new invoice numbers and the net
/// money difference (positive = customer pays, negative = refund).
typedef ReturnResult = ({
  String returnInvoice,
  String? saleInvoice,
  double difference,
});

/// A returnable line from the looked-up sale, plus how many the owner ticked.
class ReturnLine {
  final SaleItem original; // carries price_at_sale + cost_at_sale
  final String name;
  final int alreadyReturned; // pieces returned on earlier returns of this sale
  int returnQty; // 0 = not returning this item
  ReturnLine({
    required this.original,
    required this.name,
    this.alreadyReturned = 0,
    this.returnQty = 0,
  });

  double get refundEach => original.priceAtSale; // discount-aware
  double get refundTotal => refundEach * returnQty;

  /// Pieces still returnable = sold minus what was already returned.
  int get maxQty => (original.qty - alreadyReturned).clamp(0, original.qty);
}

/// Drives the Return & exchange screen.
class ReturnController extends GetxController {
  final SaleRepository _sales = SaleRepository();
  final ProductRepository _products = ProductRepository();

  final invoiceInput = ''.obs;
  final loading = false.obs;
  final notFound = false.obs;

  final Rxn<Sale> sale = Rxn<Sale>();
  final lines = <ReturnLine>[].obs; // items of the looked-up sale

  // Exchange: replacement products the customer takes instead (at today's price).
  final replacements = <CartLine>[].obs;
  // Products available to add as replacements (searchable).
  final productResults = <Product>[].obs;
  final productSearch = ''.obs;

  // ---- Look up a past sale ----
  Future<void> lookup() async {
    final inv = invoiceInput.value.trim();
    if (inv.isEmpty) return;
    loading.value = true;
    notFound.value = false;
    _reset();

    final found = await _sales.getSaleByInvoice(inv);
    if (found == null || found.type != 'sale') {
      // Only original sales can be returned.
      notFound.value = true;
      loading.value = false;
      return;
    }
    final items = await _sales.itemsForSale(found.id!);
    final names = await _sales.namesForProductIds(
        items.map((e) => e.productId).toList());
    // How many of each product were already returned on earlier returns, so we
    // only offer the pieces still returnable.
    final alreadyReturned = await _sales.returnedQtyForInvoice(found.invoiceNo);

    sale.value = found;
    lines.value = items
        .map((it) => ReturnLine(
              original: it,
              name: names[it.productId] ?? 'Item',
              alreadyReturned: alreadyReturned[it.productId] ?? 0,
            ))
        .toList();
    loading.value = false;
  }

  void _reset() {
    sale.value = null;
    lines.clear();
    replacements.clear();
    productSearch.value = '';
    productResults.clear();
  }

  void clear() {
    invoiceInput.value = '';
    notFound.value = false;
    _reset();
  }

  // ---- Choose return quantities ----
  void setReturnQty(ReturnLine line, int qty) {
    line.returnQty = qty.clamp(0, line.maxQty);
    lines.refresh();
  }

  void incReturn(ReturnLine line) => setReturnQty(line, line.returnQty + 1);
  void decReturn(ReturnLine line) => setReturnQty(line, line.returnQty - 1);

  // ---- Replacement products (exchange) ----
  Future<void> searchProducts(String q) async {
    productSearch.value = q;
    productResults.value = await _products.getAll(search: q);
  }

  void addReplacement(Product p) {
    final i = replacements.indexWhere((l) => l.product.id == p.id);
    if (i >= 0) {
      replacements[i].qty += 1;
    } else {
      replacements.add(CartLine(p));
    }
    replacements.refresh();
  }

  void incReplacement(CartLine l) {
    l.qty += 1;
    replacements.refresh();
  }

  void decReplacement(CartLine l) {
    l.qty -= 1;
    if (l.qty <= 0) replacements.remove(l);
    replacements.refresh();
  }

  // ---- Money ----
  double get refundTotal =>
      lines.fold(0.0, (s, l) => s + l.refundTotal);

  double get replacementTotal =>
      replacements.fold(0.0, (s, l) => s + l.lineTotal);

  /// Positive = customer pays this. Negative = we refund this.
  double get difference => replacementTotal - refundTotal;

  bool get hasReturn => lines.any((l) => l.returnQty > 0);
  bool get hasReplacement => replacements.isNotEmpty;
  bool get canConfirm => hasReturn || hasReplacement;

  // ---- Confirm return / exchange ----
  /// Saves a return row (restores stock) and, for an exchange, a sale row for
  /// the replacement items (reduces stock). Returns a short result summary.
  Future<ReturnResult> confirm() async {
    final original = sale.value!;
    String? saleInvoice;
    String returnInvoice = '';

    // 1) The return part.
    if (hasReturn) {
      final returnedItems = lines
          .where((l) => l.returnQty > 0)
          .map((l) => SaleItem(
                productId: l.original.productId,
                qty: l.returnQty,
                priceAtSale: l.original.priceAtSale, // NEVER current price
                costAtSale: l.original.costAtSale,
              ))
          .toList();

      final returnSale = Sale(
        invoiceNo: '', // assigned inside the transaction
        date: DateTime.now().toIso8601String(),
        totalAmount: refundTotal,
        discountAmount: 0,
        paymentType: original.paymentType,
        type: 'return',
      );
      // Throws OverReturnException (and rolls back) if it exceeds what was sold.
      final saved = await _sales.saveReturn(
        returnSale: returnSale,
        returnedItems: returnedItems,
        originalSaleId: original.id!,
        originalInvoiceNo: original.invoiceNo,
      );
      returnInvoice = saved.invoiceNo;
    }

    // 2) The exchange part (new items sold at today's price).
    if (hasReplacement) {
      final items = replacements
          .map((l) => SaleItem(
                productId: l.product.id!,
                qty: l.qty,
                priceAtSale: l.unitPrice,
                costAtSale: l.product.costPrice,
              ))
          .toList();
      final newSale = Sale(
        invoiceNo: '', // assigned inside the transaction
        date: DateTime.now().toIso8601String(),
        totalAmount: replacementTotal,
        discountAmount: 0,
        paymentType: original.paymentType,
        type: 'sale',
      );
      // Throws InsufficientStockException (and rolls back) if not enough stock.
      final saved = await _sales.completeSale(sale: newSale, items: items);
      saleInvoice = saved.invoiceNo;
    }

    final diff = difference;

    // Refresh stock screen if open.
    if (Get.isRegistered<StockController>()) {
      await Get.find<StockController>().load();
    }

    clear();
    return (
      returnInvoice: returnInvoice,
      saleInvoice: saleInvoice,
      difference: diff
    );
  }
}
