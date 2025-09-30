import 'package:flutter/foundation.dart';

import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/static_products.dart';

class ProductsProvider extends ChangeNotifier {
  final ProductRepository repository;
  List<Product> _remoteProducts = [];
  final Map<int, Product> _staticOverrides = {};
  bool isLoading = false;
  String? error;

  ProductsProvider(this.repository);

  Future<void> loadProducts() async {
    isLoading = true;
    notifyListeners();
    try {
      _remoteProducts = await repository.fetchProducts();
      _reconcileStaticOverrides();
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
      _reconcileStaticOverrides();
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
      _reconcileStaticOverrides();
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
      _staticOverrides.removeWhere((_, value) => value.id == id);
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
    final combined = menuProducts;
    for (final product in combined) {
      if (product.id == id) return product;
    }
    return null;
  }

  List<Product> get menuProducts {
    final overrideIds = _staticOverrides.values.map((p) => p.id).toSet();
    final staticEntries = staticProducts
        .map((product) => _staticOverrides[product.id] ?? product)
        .toList();
    final remotes = _remoteProducts.where((p) => !overrideIds.contains(p.id));
    return [...staticEntries, ...remotes];
  }

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

  void _reconcileStaticOverrides() {
    final overrides = <int, Product>{};
    final staticByName = {
      for (final product in staticProducts) product.name.toLowerCase(): product
    };

    _remoteProducts = _remoteProducts.map((remote) {
      final template = staticByName[remote.name.toLowerCase()];
      if (template == null) {
        return remote;
      }
      final merged = _mergeProduct(remote, template);
      overrides[template.id] = merged;
      return merged;
    }).toList();

    _staticOverrides
      ..clear()
      ..addAll(overrides);
  }

  Product _mergeProduct(Product remote, Product template) {
    return Product(
      id: remote.id,
      name: remote.name,
      price: remote.price,
      stock: remote.stock,
      createdAt: remote.createdAt,
      description: template.description ?? remote.description,
      category: template.category ?? remote.category,
      imageUrl: template.imageUrl ?? remote.imageUrl,
    );
  }
}
