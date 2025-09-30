import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../checkout/checkout_page.dart';
import 'cart_provider.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  late final TextEditingController _discountController;

  @override
  void initState() {
    super.initState();
    final cart = context.read<CartProvider>();
    _discountController = TextEditingController(text: cart.discountPercent.toString());
  }

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: cart.items.isEmpty
                  ? const Center(child: Text('Your cart is empty.'))
                  : ListView.separated(
                      itemCount: cart.items.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final item = cart.items[index];
                        return ListTile(
                          title: Text(item.product.name),
                          subtitle: Text('ZMW ${item.product.price.toStringAsFixed(2)} x ${item.quantity}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => cart.updateQuantity(item.product, item.quantity - 1),
                              ),
                              Text('${item.quantity}'),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () => cart.updateQuantity(item.product, item.quantity + 1),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _discountController,
              decoration: const InputDecoration(labelText: 'Discount %'),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                final parsed = double.tryParse(value) ?? 0;
                cart.setDiscountPercent(parsed.clamp(0, 100));
              },
            ),
            const SizedBox(height: 12),
            _buildTotals(cart),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: cart.items.isEmpty ? null : () => _performCheckout(context, cart),
                child: const Text('Checkout'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotals(CartProvider cart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Subtotal: ZMW ${cart.subtotal.toStringAsFixed(2)}'),
        Text('Tax (~16%): ZMW ${cart.tax.toStringAsFixed(2)}'),
        Text('Discount: ZMW ${cart.discount.toStringAsFixed(2)}'),
        Text('Total (estimate): ZMW ${cart.total.toStringAsFixed(2)}'),
      ],
    );
  }

  Future<void> _performCheckout(BuildContext context, CartProvider cart) async {
    final api = context.read<ApiService>();
    try {
      final payload = cart.toCheckoutPayload();
      final receipt = await api.checkout(
        payload,
        discountPercent: cart.discountPercent,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CheckoutPage(receipt: receipt)),
      );
      cart.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Checkout failed: $e')));
    }
  }

}
