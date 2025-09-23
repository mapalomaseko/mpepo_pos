class Product {
  final int id;
  final String name;
  final double price;
  final int stock;
  final DateTime createdAt;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    required this.createdAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      stock: json['stock'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'stock': stock,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Product copyWith({String? name, double? price, int? stock}) {
    return Product(
      id: id,
      name: name ?? this.name,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      createdAt: createdAt,
    );
  }
}
