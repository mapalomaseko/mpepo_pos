import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../checkout/checkout_page.dart';
import '../products/products_provider.dart';
import '../reports/reports_provider.dart';
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
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurface.withOpacity(0.65);
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(color: mutedColor) ??
        TextStyle(color: mutedColor, fontSize: 14);
    final valueStyle =
        theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600) ??
            TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: theme.colorScheme.onSurface);
    String format(double value) => 'ZMW ${value.toStringAsFixed(2)}';

    Widget buildLine(String label, double value) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: labelStyle),
          Text(format(value), style: valueStyle),
        ],
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildLine('Subtotal', cart.subtotal),
            const SizedBox(height: 8),
            buildLine('Tax (~16%)', cart.tax),
            const SizedBox(height: 8),
            buildLine('Discount', cart.discount),
            const SizedBox(height: 16),
            const Divider(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total (estimate)',
                        style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ) ??
                            TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Includes tax and discounts',
                        style: theme.textTheme.bodySmall?.copyWith(color: mutedColor) ??
                            TextStyle(color: mutedColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  format(cart.total),
                  style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ) ??
                      TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performCheckout(BuildContext context, CartProvider cart) async {
    final api = context.read<ApiService>();
    final productsProvider = context.read<ProductsProvider>();
    try {
      final payload = cart.toCheckoutPayload();
      final receipt = await api.checkout(
        payload,
        discountPercent: cart.discountPercent,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Checkout successful'),
            content: const Text('The transaction was completed successfully.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('View receipt'),
              ),
            ],
          );
        },
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CheckoutPage(receipt: receipt)),
      );
      cart.clear();
      if (mounted) {
        context.read<ReportsProvider>().loadReport();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Checkout failed: $e')));
    }
  }

}
