import 'package:flutter/foundation.dart';

import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';

class ProductsProvider extends ChangeNotifier {
  final ProductRepository repository;
  List<Product> products = [];
  bool isLoading = false;
  String? error;

  ProductsProvider(this.repository);

  Future<void> loadProducts() async {
    isLoading = true;
    notifyListeners();
    try {
      products = await repository.fetchProducts();
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
      products = [product, ...products];
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
      products = products.map((p) => p.id == updated.id ? updated : p).toList();
      notifyListeners();
      return updated;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> deleteProduct(int id) async {
    try {
      await repository.deleteProduct(id);
      products = products.where((p) => p.id != id).toList();
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Product? getById(int id) {
    try {
      return products.firstWhere((element) => element.id == id);
    } catch (_) {
      return null;
    }
  }
}
