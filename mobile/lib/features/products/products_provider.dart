import 'package:flutter/foundation.dart';

import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/static_products.dart';

class ProductsProvider extends ChangeNotifier {
  final ProductRepository repository;
  List<Product> _remoteProducts = [];
  bool isLoading = false;
  String? error;

  ProductsProvider(this.repository);

  Future<void> loadProducts() async {
    isLoading = true;
    notifyListeners();
    try {
      _remoteProducts = await repository.fetchProducts();
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Product?> createProduct(String name, double price, int stock) async {
    try {
      final product = await repository.createProduct(name, price, stock);
      _remoteProducts = [product, ..._remoteProducts];
      notifyListeners();
      return product;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<Product?> saveProduct(Product product) async {
    try {
      final updated = await repository.updateProduct(product);
      _remoteProducts =
          _remoteProducts.map((p) => p.id == updated.id ? updated : p).toList();
      notifyListeners();
      return updated;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> deleteProduct(int id) async {
    if (id < 0) return;
    try {
      await repository.deleteProduct(id);
      _remoteProducts = _remoteProducts.where((p) => p.id != id).toList();
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Product? getById(int id) {
    final combined = menuProducts;
    for (final product in combined) {
      if (product.id == id) return product;
    }
    return null;
  }

  List<Product> get menuProducts => [...staticProducts, ..._remoteProducts];

  List<Product> productsForCategory(String category) {
    final items = menuProducts;
    if (category == 'All') {
      return items;
    }
    if (category == 'Extras & Drinks') {
      return items
          .where((product) =>
              product.category == 'Extras' ||
              product.category == 'Drinks' ||
              product.category == 'Extras & Drinks')
          .toList();
    }
    return items.where((product) => product.category == category).toList();
  }
}
