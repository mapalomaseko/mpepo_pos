import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/product.dart';
import '../../widgets/app_text_field.dart';
import '../cart/cart_page.dart';
import '../cart/cart_provider.dart';
import 'products_provider.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  static const _tabs = ['All', 'Appetizers', 'Main Courses', 'Extras & Drinks'];
  final Map<int, int> _quantities = {};

  @override
  Widget build(BuildContext context) {
    final productsProvider = context.watch<ProductsProvider>();
    final cart = context.watch<CartProvider>();

    final hasItemsInCart = cart.items.isNotEmpty;
    final cartItemCount =
        cart.items.fold<int>(0, (previousValue, element) => previousValue + element.quantity);
    final theme = Theme.of(context);

    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Menu'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showProductDialog(context),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: _tabs.map((label) => Tab(text: label)).toList(),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Stack(
            children: [
              Column(
                children: [
                  if (productsProvider.isLoading)
                    const LinearProgressIndicator(minHeight: 2),
                  Expanded(
                    child: TabBarView(
                      children: _tabs
                          .map(
                            (category) => _CategoryGrid(
                              category: category,
                              provider: productsProvider,
                              cart: cart,
                              onQuantityChanged: _updateQuantity,
                              quantityBuilder: _getQuantity,
                              onEditProduct: (product) => _showProductDialog(
                                context,
                                productId: product.id,
                              ),
                              onDeleteProduct: _confirmDelete,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  top: false,
                  left: false,
                  right: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: IgnorePointer(
                      ignoring: !hasItemsInCart,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 250),
                        opacity: hasItemsInCart ? 1 : 0,
                        child: AnimatedSlide(
                          duration: const Duration(milliseconds: 250),
                          offset: hasItemsInCart ? Offset.zero : const Offset(0, 1),
                          child: GestureDetector(
                            onTap: hasItemsInCart ? () => _showCartSummary(context) : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withOpacity(0.3),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.shopping_bag, color: Colors.white),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '$cartItemCount item${cartItemCount == 1 ? '' : 's'} in cart',
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'Total: ZMW ${cart.total.toStringAsFixed(2)}',
                                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.keyboard_arrow_up, color: Colors.white),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _updateQuantity(int productId, int quantity) {
    setState(() {
      _quantities[productId] = quantity;
    });
  }

  int _getQuantity(int productId) => _quantities[productId] ?? 1;

  Future<void> _confirmDelete(Product product) async {
    final provider = context.read<ProductsProvider>();
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete product'),
            content: Text('Are you sure you want to remove ${product.name}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldDelete) {
      await provider.deleteProduct(product.id);
    }
  }

  Future<void> _showCartSummary(BuildContext context) async {
    final cart = context.read<CartProvider>();
    final theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final items = cart.items;
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Your Cart', style: theme.textTheme.headlineSmall),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: items.isEmpty
                      ? const Center(child: Text('Your cart is empty.'))
                      : ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return ListTile(
                              title: Text(item.product.name),
                              subtitle: Text(
                                'ZMW ${item.product.price.toStringAsFixed(2)} x ${item.quantity}',
                              ),
                              trailing: Text(
                                'ZMW ${item.lineTotal.toStringAsFixed(2)}',
                                style: theme.textTheme.titleMedium,
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
                Text('Total: ZMW ${cart.total.toStringAsFixed(2)}',
                    style:
                        theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: cart.items.isEmpty
                        ? null
                        : () {
                            Navigator.pop(context);
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const CartPage()),
                            );
                          },
                    child: const Text('Go to checkout'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showProductDialog(BuildContext context, {int? productId}) async {
    final provider = context.read<ProductsProvider>();
    final product = productId != null ? provider.getById(productId) : null;
    if (product != null && product.isStatic) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preloaded menu items cannot be edited.')),
      );
      return;
    }

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

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.category,
    required this.provider,
    required this.cart,
    required this.onQuantityChanged,
    required this.quantityBuilder,
    required this.onEditProduct,
    required this.onDeleteProduct,
  });

  final String category;
  final ProductsProvider provider;
  final CartProvider cart;
  final void Function(int productId, int quantity) onQuantityChanged;
  final int Function(int productId) quantityBuilder;
  final void Function(Product product) onEditProduct;
  final Future<void> Function(Product product) onDeleteProduct;

  @override
  Widget build(BuildContext context) {
    final products = provider.productsForCategory(category);
    if (products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('No items available in $category yet.'),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = _columnCountForWidth(width);
        const horizontalPadding = 32.0;
        const spacing = 16.0;
        final bottomInset = MediaQuery.of(context).padding.bottom;
        final usableWidth = width - horizontalPadding - (crossAxisCount - 1) * spacing;
        final itemWidth = usableWidth > 0 ? usableWidth / crossAxisCount : width / crossAxisCount;
        final cardHeight = _cardHeightForColumns(crossAxisCount);
        final rawAspectRatio = itemWidth / cardHeight;
        final clampedAspectRatio = rawAspectRatio.clamp(0.35, 1.1);

        return RefreshIndicator(
          onRefresh: () => provider.loadProducts(),
          child: GridView.builder(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 176 + bottomInset),
            itemCount: products.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              childAspectRatio: clampedAspectRatio.toDouble(),
            ),
            physics: const AlwaysScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final product = products[index];
              final quantity = quantityBuilder(product.id);
              final existingQuantity = cart.quantityFor(product);

              return _ProductCard(
                product: product,
                quantity: quantity,
                existingQuantity: existingQuantity,
                onQuantityChanged: (value) => onQuantityChanged(product.id, value),
                onAddToCart: () {
                  final newQuantity = existingQuantity + quantity;
                  cart.updateQuantity(product, newQuantity);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${product.name} added to cart')),
                  );
                },
                onEdit: product.isStatic ? null : () => onEditProduct(product),
                onDelete: product.isStatic
                    ? null
                    : () {
                        onDeleteProduct(product);
                      },
              );
            },
          ),
        );
      },
    );
  }

  int _columnCountForWidth(double width) {
    if (width >= 1200) {
      return 4;
    }
    if (width >= 900) {
      return 3;
    }
    return 2;
  }

  double _cardHeightForColumns(int columns) {
    if (columns >= 4) {
      return 360.0;
    }
    if (columns == 3) {
      return 380.0;
    }
    return 420.0;
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.quantity,
    required this.existingQuantity,
    required this.onQuantityChanged,
    required this.onAddToCart,
    this.onEdit,
    this.onDelete,
  });

  final Product product;
  final int quantity;
  final int existingQuantity;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onAddToCart;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Material(
      color: theme.colorScheme.surface,
      elevation: 2,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onLongPress: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: _ProductImage(imageUrl: product.imageUrl),
                    ),
                  ),
                  if (onEdit != null || onDelete != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Material(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(16),
                        clipBehavior: Clip.antiAlias,
                        child: PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                          onSelected: (value) {
                            if (value == 'edit' && onEdit != null) {
                              onEdit!();
                            } else if (value == 'delete' && onDelete != null) {
                              onDelete!();
                            }
                          },
                          itemBuilder: (context) => [
                            if (onEdit != null)
                              const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            if (onDelete != null)
                              const PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (product.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        product.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: textTheme.bodySmall?.color?.withOpacity(0.7),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'ZMW ${product.price.toStringAsFixed(2)}',
                      style: textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        _QuantityButton(
                          icon: Icons.remove_circle_outline,
                          onPressed: quantity > 1 ? () => onQuantityChanged(quantity - 1) : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('$quantity', style: textTheme.titleMedium),
                        ),
                        _QuantityButton(
                          icon: Icons.add_circle_outline,
                          onPressed: () => onQuantityChanged(quantity + 1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.shopping_cart_outlined),
                        onPressed: onAddToCart,
                        label: Text(
                          existingQuantity > 0
                              ? 'Update (${existingQuantity + quantity})'
                              : 'Add to cart',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _FallbackImage(name: 'No image');
    }

    if (imageUrl!.startsWith('assets/')) {
      return Image.asset(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _FallbackImage(name: imageUrl!),
      );
    }

    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _FallbackImage(name: imageUrl!),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}

class _FallbackImage extends StatelessWidget {
  const _FallbackImage({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceVariant,
      child: Center(
        child: Icon(Icons.image_not_supported, color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
