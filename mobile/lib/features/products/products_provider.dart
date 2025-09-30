import 'package:flutter/foundation.dart';

import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/static_catalog.dart';

class ProductsProvider extends ChangeNotifier {
  ProductsProvider(this.repository) {
    _recomputeProducts();
  }

  final ProductRepository repository;

  final Map<int, Product> _staticOverrides = {};
  List<Product> _remoteProducts = [];

  List<Product> _resolvedProducts = [];

  bool isLoading = false;
  String? error;

  List<Product> get products => List.unmodifiable(_resolvedProducts);

  List<Product> productsForCategory(String category) {
    final items = _resolvedProducts;

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

  Product? getById(int id) {
    for (final product in _resolvedProducts) {
      if (product.id == id) return product;
    }
    return null;
  }

  List<Product> _buildResolvedProducts() {
    final resolved = <Product>[];
    final consumedRemoteIds = <int>{};

    for (final staticProduct in kStaticProducts) {
      final override = _staticOverrides[staticProduct.id];
      if (override != null) {
        consumedRemoteIds.add(override.id);
        resolved.add(override);
        continue;
      }

      final remoteMatch = _findRemoteMatch(staticProduct.name);
      if (remoteMatch != null) {
        final merged = _mergeProduct(remoteMatch, staticProduct);
        _staticOverrides[staticProduct.id] = merged;
        consumedRemoteIds.add(merged.id);
        resolved.add(merged);
      } else {
        resolved.add(staticProduct);
      }
    }

    final remoteRemainder = _remoteProducts
        .where((product) => !consumedRemoteIds.contains(product.id))
        .toList();

    return [...resolved, ...remoteRemainder];
  }

  Future<void> loadProducts() async {
    isLoading = true;
    notifyListeners();
    try {
      _remoteProducts = await repository.fetchProducts();
      _recomputeProducts();
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
      final created = await repository.createProduct(
        name: name,
        price: price,
        stock: stock,
        description: description,
        category: category,
        imageUrl: imageUrl,
      );
      _remoteProducts = [created, ..._remoteProducts];
      _recomputeProducts();
      error = null;
      notifyListeners();
      return created;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<Product?> saveProduct(Product product) async {
    try {
      if (product.id < 0) {
        final existingOverride = _staticOverrides[product.id];
        Product resolved;

        if (existingOverride != null) {
          final updatedRemote = await repository.updateProduct(
            existingOverride.copyWith(
              name: product.name,
              price: product.price,
              stock: product.stock,
              description: product.description,
              category: product.category,
              imageUrl: product.imageUrl,
            ),
          );
          resolved = _mergeProduct(updatedRemote, product);
          _remoteProducts = _remoteProducts
              .map((p) => p.id == resolved.id ? resolved : p)
              .toList();
        } else {
          final remoteMatch = _findRemoteMatch(product.name);
          if (remoteMatch != null) {
            final updatedRemote = await repository.updateProduct(
              remoteMatch.copyWith(
                name: product.name,
                price: product.price,
                stock: product.stock,
                description: product.description,
                category: product.category,
                imageUrl: product.imageUrl,
              ),
            );
            resolved = _mergeProduct(updatedRemote, product);
            _remoteProducts = _remoteProducts
                .map((p) => p.id == resolved.id ? resolved : p)
                .toList();
          } else {
            final created = await repository.createProduct(
              name: product.name,
              price: product.price,
              stock: product.stock,
              description: product.description,
              category: product.category,
              imageUrl: product.imageUrl,
            );
            resolved = _mergeProduct(created, product);
            _remoteProducts = [resolved, ..._remoteProducts];
          }
        }

        _staticOverrides[product.id] = resolved;
        _recomputeProducts();
        error = null;
        notifyListeners();
        return resolved;
      }

      final updated = await repository.updateProduct(product);
      _remoteProducts =
          _remoteProducts.map((p) => p.id == updated.id ? updated : p).toList();
      for (final entry in _staticOverrides.entries.toList()) {
        if (entry.value.id == updated.id) {
          _staticOverrides[entry.key] = updated;
        }
      }
      _recomputeProducts();
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
      if (id < 0) {
        final override = _staticOverrides.remove(id);
        if (override != null) {
          await repository.deleteProduct(override.id);
          _remoteProducts =
              _remoteProducts.where((product) => product.id != override.id).toList();
        }
        _recomputeProducts();
        error = null;
        notifyListeners();
        return;
      }

      await repository.deleteProduct(id);
      _remoteProducts =
          _remoteProducts.where((product) => product.id != id).toList();
      for (final entry in _staticOverrides.entries.toList()) {
        if (entry.value.id == id) {
          _staticOverrides.remove(entry.key);
        }
      }
      _recomputeProducts();
      error = null;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }


  void _recomputeProducts() {
    _resolvedProducts = _buildResolvedProducts();
  }

  Product? _findRemoteMatch(String name) {
    final lower = name.toLowerCase();
    for (final product in _remoteProducts) {
      if (product.name.toLowerCase() == lower) {
        return product;
      }
    }
    return null;
  }

  Product _mergeProduct(Product remote, Product fallback) {
    return Product(
      id: remote.id,
      name: remote.name,
      price: remote.price,
      stock: remote.stock,
      createdAt: remote.createdAt,
      description: fallback.description ?? remote.description,
      category: fallback.category ?? remote.category,
      imageUrl: fallback.imageUrl ?? remote.imageUrl,
    );
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
