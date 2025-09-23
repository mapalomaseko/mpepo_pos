class ReceiptItem {
  final int productId;
  final String name;
  final int qty;
  final double unitPrice;
  final double lineTotal;

  ReceiptItem({
    required this.productId,
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.lineTotal,
  });

  factory ReceiptItem.fromJson(Map<String, dynamic> json) {
    return ReceiptItem(
      productId: json['product_id'] as int,
      name: json['name'] as String,
      qty: json['qty'] as int,
      unitPrice: (json['unit_price'] as num).toDouble(),
      lineTotal: (json['line_total'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'name': name,
      'qty': qty,
      'unit_price': unitPrice,
      'line_total': lineTotal,
    };
  }
}

class Receipt {
  final int id;
  final List<ReceiptItem> items;
  final double subtotal;
  final double tax;
  final double discount;
  final double total;
  final DateTime createdAt;

  Receipt({
    required this.id,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.discount,
    required this.total,
    required this.createdAt,
  });

  factory Receipt.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List<dynamic>;
    return Receipt(
      id: json['id'] as int,
      items: itemsJson.map((e) => ReceiptItem.fromJson(e as Map<String, dynamic>)).toList(),
      subtotal: (json['subtotal'] as num).toDouble(),
      tax: (json['tax'] as num).toDouble(),
      discount: (json['discount'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
