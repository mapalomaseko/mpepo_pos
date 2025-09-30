import 'package:flutter/foundation.dart';

import '../../data/models/product.dart';

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, required this.quantity});

  double get lineTotal => product.price * quantity;
}

class CartProvider extends ChangeNotifier {
  static const double taxRate = 0.16;
  final Map<int, CartItem> _items = {};
  double discountPercent = 0;

  List<CartItem> get items => _items.values.toList();

  int quantityFor(Product product) => _items[product.id]?.quantity ?? 0;

  void add(Product product) {
    final item = _items[product.id];
    if (item != null) {
      item.quantity += 1;
    } else {
      _items[product.id] = CartItem(product: product, quantity: 1);
    }
    notifyListeners();
  }

  void remove(Product product) {
    _items.remove(product.id);
    notifyListeners();
  }

  void updateQuantity(Product product, int quantity) {
    if (quantity <= 0) {
      _items.remove(product.id);
    } else {
      _items[product.id] = CartItem(product: product, quantity: quantity);
    }
    notifyListeners();
  }

  void clear() {
    _items.clear();
    discountPercent = 0;
    notifyListeners();
  }

  void setDiscountPercent(double value) {
    discountPercent = value;
    notifyListeners();
  }

  double get subtotal => _items.values.fold(0.0, (sum, item) => sum + item.lineTotal);

  double get tax => subtotal * taxRate;

  double get discount => subtotal * (discountPercent / 100);

  double get total => subtotal + tax - discount;

  List<Map<String, dynamic>> toCheckoutPayload() {
    return _items.values
        .map((item) => {'product_id': item.product.id, 'qty': item.quantity})
        .toList();
  }
}
