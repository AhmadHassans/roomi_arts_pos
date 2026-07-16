/// A completed sale or return. (Fully used from M2 onward.)
class Sale {
  final int? id;
  final String invoiceNo;
  final String date; // ISO8601
  final double totalAmount;
  final double discountAmount;
  final String paymentType; // 'cash' | 'card'
  final String type; // 'sale' | 'return'

  const Sale({
    this.id,
    required this.invoiceNo,
    required this.date,
    required this.totalAmount,
    required this.discountAmount,
    required this.paymentType,
    required this.type,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'invoice_no': invoiceNo,
        'date': date,
        'total_amount': totalAmount,
        'discount_amount': discountAmount,
        'payment_type': paymentType,
        'type': type,
      };

  factory Sale.fromMap(Map<String, Object?> m) => Sale(
        id: m['id'] as int?,
        invoiceNo: m['invoice_no'] as String,
        date: m['date'] as String,
        totalAmount: (m['total_amount'] as num).toDouble(),
        discountAmount: (m['discount_amount'] as num).toDouble(),
        paymentType: m['payment_type'] as String,
        type: m['type'] as String,
      );
}
