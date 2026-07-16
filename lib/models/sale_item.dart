/// One line of a sale. Price and cost are frozen at the moment of sale so that
/// refunds use the actual price charged (discount-aware). Used from M2 onward.
class SaleItem {
  final int? id;
  final int? saleId;
  final int productId;
  final int qty;
  final double priceAtSale; // per-unit price AFTER discount
  final double costAtSale; // product cost_price at that moment

  const SaleItem({
    this.id,
    this.saleId,
    required this.productId,
    required this.qty,
    required this.priceAtSale,
    required this.costAtSale,
  });

  double get lineTotal => priceAtSale * qty;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'sale_id': saleId,
        'product_id': productId,
        'qty': qty,
        'price_at_sale': priceAtSale,
        'cost_at_sale': costAtSale,
      };

  factory SaleItem.fromMap(Map<String, Object?> m) => SaleItem(
        id: m['id'] as int?,
        saleId: m['sale_id'] as int?,
        productId: m['product_id'] as int,
        qty: (m['qty'] as num).toInt(),
        priceAtSale: (m['price_at_sale'] as num).toDouble(),
        costAtSale: (m['cost_at_sale'] as num).toDouble(),
      );
}
