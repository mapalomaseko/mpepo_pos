import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../widgets/app_text_field.dart';
import '../cart/cart_provider.dart';
import 'products_provider.dart';

class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final productsProvider = context.watch<ProductsProvider>();
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Products')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductDialog(context),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => productsProvider.loadProducts(),
        child: Builder(
          builder: (context) {
            if (productsProvider.isLoading && productsProvider.products.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (productsProvider.products.isEmpty) {
              return const Center(child: Text('No products yet. Tap + to add one.'));
            }
            return ListView.builder(
              itemCount: productsProvider.products.length,
              itemBuilder: (context, index) {
                final product = productsProvider.products[index];
                return Dismissible(
                  key: ValueKey(product.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => productsProvider.deleteProduct(product.id),
                  child: ListTile(
                    title: Text(product.name),
                    subtitle: Text('KES ${product.price.toStringAsFixed(2)} • Stock ${product.stock}'),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showProductDialog(context, productId: product.id),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_shopping_cart),
                          onPressed: () {
                            cart.add(product);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${product.name} added to cart')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _showProductDialog(BuildContext context, {int? productId}) async {
    final provider = context.read<ProductsProvider>();
    final product = productId != null ? provider.getById(productId) : null;
    final nameController = TextEditingController(text: product?.name ?? '');
    final priceController = TextEditingController(text: product?.price.toString() ?? '');
    final stockController = TextEditingController(text: product?.stock.toString() ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(product == null ? 'Add product' : 'Edit product'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(
                    controller: nameController,
                    label: 'Name',
                    validator: (value) => value == null || value.isEmpty ? 'Enter name' : null,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: priceController,
                    label: 'Price',
                    keyboardType: TextInputType.number,
                    validator: (value) => value == null || value.isEmpty ? 'Enter price' : null,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: stockController,
                    label: 'Stock',
                    keyboardType: TextInputType.number,
                    validator: (value) => value == null || value.isEmpty ? 'Enter stock' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final name = nameController.text;
                final price = double.tryParse(priceController.text) ?? 0;
                final stock = int.tryParse(stockController.text) ?? 0;
                if (product == null) {
                  await provider.createProduct(name, price, stock);
                } else {
                  await provider.saveProduct(
                    product.copyWith(name: name, price: price, stock: stock),
                  );
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
