import 'package:flutter/material.dart';

import '../l10n/localized.dart';
import '../models/vendor.dart';
import '../services/app_store.dart';
import '../services/marketplace_catalog.dart';
import '../services/vendor_store.dart';
import 'order_confirmation_screen.dart';

/// Shopping cart for marketplace products.
///
/// Checkout creates a pending order per vendor and offers WhatsApp contact.
class CartScreen extends StatefulWidget {
  const CartScreen({
    required this.store,
    required this.vendorStore,
    super.key,
  });

  final AppStore store;
  final VendorStore vendorStore;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<Vendor> vendors = [];
  bool isLoadingVendors = true;

  @override
  void initState() {
    super.initState();
    _loadVendors();
  }

  Future<void> _loadVendors() async {
    final catalog = await MarketplaceCatalog.load(widget.vendorStore, widget.store.backendApi);
    if (mounted) {
      setState(() {
        vendors = catalog.vendors;
        isLoadingVendors = false;
      });
    }
  }

  Future<void> _checkout() async {
    if (widget.store.cart.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('cart.placeOrderTitle')),
        content: Text(
          '${context.tr('cart.placeOrderBody')} ${widget.store.cartCount} item(s) '
          'totalling ${widget.store.cartTotalLabel}?\n\n'
          '${context.tr('cart.ordersNote')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('cart.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('cart.placeOrder')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final orders = widget.store.checkoutCart();

    if (!mounted) return;

    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OrderConfirmationScreen(
          store: widget.store,
          orders: orders,
          vendors: vendors,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('cart.title')),
      ),
      body: AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) {
          final cart = widget.store.cart;
          if (cart.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: 72,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.tr('cart.empty'),
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('cart.emptySubtitle'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  itemCount: cart.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final product = cart[index];
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        title: Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              product.priceLabel,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Remove',
                              onPressed: () =>
                                  widget.store.removeFromCart(product),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total (${cart.length} item${cart.length == 1 ? '' : 's'})',
                            style: theme.textTheme.titleMedium,
                          ),
                          Text(
                            widget.store.cartTotalLabel,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: isLoadingVendors ? null : _checkout,
                        child: Text(
                          isLoadingVendors
                              ? context.tr('cart.loading')
                              : context.tr('cart.placeOrder'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.tr('cart.ordersNote'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
