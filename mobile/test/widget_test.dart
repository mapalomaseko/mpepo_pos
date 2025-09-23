import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:smart_pos_mobile/features/products/products_page.dart';
import 'package:smart_pos_mobile/features/products/products_provider.dart';
import 'package:smart_pos_mobile/features/cart/cart_provider.dart';
import 'package:smart_pos_mobile/data/models/product.dart';
import 'package:smart_pos_mobile/data/repositories/product_repository.dart';
import 'package:smart_pos_mobile/services/api_service.dart';

class _FakeProductRepository extends ProductRepository {
  _FakeProductRepository() : super(ApiService(baseUrl: 'http://localhost'));

  @override
  Future<List<Product>> fetchProducts() async {
    return [
      Product(
        id: 1,
        name: 'Chapati',
        price: 10,
        stock: 100,
        createdAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<Product> createProduct(String name, double price, int stock) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteProduct(int id) {
    throw UnimplementedError();
  }

  @override
  Future<Product> updateProduct(Product product) {
    throw UnimplementedError();
  }
}

void main() {
  testWidgets('ProductsPage renders provided products', (tester) async {
    final provider = ProductsProvider(_FakeProductRepository());
    provider.products = [
      Product(
        id: 1,
        name: 'Chapati',
        price: 10,
        stock: 100,
        createdAt: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProductsProvider>.value(value: provider),
          ChangeNotifierProvider<CartProvider>(create: (_) => CartProvider()),
        ],
        child: const MaterialApp(home: ProductsPage()),
      ),
    );

    expect(find.text('Chapati'), findsOneWidget);
  });
}
