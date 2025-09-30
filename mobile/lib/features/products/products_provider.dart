import 'package:flutter/foundation.dart';

import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';
class ProductsProvider extends ChangeNotifier {
  final ProductRepository repository;
  List<Product> _products = [];
  bool isLoading = false;
  String? error;

  ProductsProvider(this.repository);

  Future<void> loadProducts() async {
    isLoading = true;
    notifyListeners();
    try {
      _products = await repository.fetchProducts();
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Product?> createProduct({
    required String name,
    required double price,
    required int stock,
    String? description,
    String? category,
    String? imageUrl,
  }) async {
    try {
      final product = await repository.createProduct(
        name: name,
        price: price,
        stock: stock,
        description: description,
        category: category,
        imageUrl: imageUrl,
      );
      _products = [product, ..._products];
      error = null;
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
      _products = _products.map((p) => p.id == updated.id ? updated : p).toList();
      error = null;
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
      _products = _products.where((p) => p.id != id).toList();
      error = null;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<Product> ensureRemoteProduct(Product product) async {
    if (product.id > 0) {
      return product;
    }

    final existingOverride = _staticOverrides[product.id];
    if (existingOverride != null) {
      return existingOverride;
    }

    Product? matchedRemote;
    for (final remote in _remoteProducts) {
      if (remote.name.toLowerCase() == product.name.toLowerCase()) {
        matchedRemote = remote;
        break;
      }
    }

    Product resolved;
    if (matchedRemote != null) {
      resolved = _mergeProduct(matchedRemote, product);
      _remoteProducts = _remoteProducts
          .map((p) => p.id == resolved.id ? resolved : p)
          .toList();
    } else {
      final created = await repository.createProduct(
        product.name,
        product.price,
        product.stock,
      );
      resolved = _mergeProduct(created, product);
      _remoteProducts = [resolved, ..._remoteProducts];
    }

    _staticOverrides[product.id] = resolved;
    notifyListeners();
    return resolved;
  }

  Product? getById(int id) {
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }

  List<Product> get products => List.unmodifiable(_products);

  List<Product> productsForCategory(String category) {
    final items = _products;
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
