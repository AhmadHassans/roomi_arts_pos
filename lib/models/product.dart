/// A single product. Stock is always in smallest units (pieces).
class Product {
  final int? id;
  final String name;
  final String category;
  final double costPrice;
  final double sellingPrice;
  final int stockQty;
  final String unit;
  final String? barcode;


  const Product({
    this.id,
    required this.name,
    required this.category,
    required this.costPrice,
    required this.sellingPrice,
    required this.stockQty,
    required this.unit,
    this.barcode,
  });

  /// True when stock is running low (see kLowStockThreshold).
  bool isLowStock(int threshold) => stockQty < threshold;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'category': category,
        'cost_price': costPrice,
        'selling_price': sellingPrice,
        'stock_qty': stockQty,
        'unit': unit,
        'barcode': (barcode == null || barcode!.trim().isEmpty) ? null : barcode!.trim(),
      };

  factory Product.fromMap(Map<String, Object?> m) => Product(
        id: m['id'] as int?,
        name: m['name'] as String,
        category: m['category'] as String,
        costPrice: (m['cost_price'] as num).toDouble(),
        sellingPrice: (m['selling_price'] as num).toDouble(),
        stockQty: (m['stock_qty'] as num).toInt(),
        unit: m['unit'] as String,
        barcode: m['barcode'] as String?,
      );

  Product copyWith({
    int? id,
    String? name,
    String? category,
    double? costPrice,
    double? sellingPrice,
    int? stockQty,
    String? unit,
    String? barcode,
  }) =>
      Product(
        id: id ?? this.id,
        name: name ?? this.name,
        category: category ?? this.category,
        costPrice: costPrice ?? this.costPrice,
        sellingPrice: sellingPrice ?? this.sellingPrice,
        stockQty: stockQty ?? this.stockQty,
        unit: unit ?? this.unit,
        barcode: barcode ?? this.barcode,
      );
}
