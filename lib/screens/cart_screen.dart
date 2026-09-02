import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/localized.dart';
import '../models/order.dart';
import '../models/vendor.dart';
import '../services/app_store.dart';
import '../services/marketplace_catalog.dart';
import '../services/vendor_store.dart';

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
    final catalog = await MarketplaceCatalog.load(widget.vendorStore);
    if (mounted) {
      setState(() {
        vendors = catalog.vendors;
        isLoadingVendors = false;
      });
    }
  }

  Vendor? _vendorFor(String vendorId) {
    try {
      return vendors.firstWhere((v) => v.id == vendorId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _contactVendorForOrder(Order order, Vendor vendor) async {
    final phone = vendor.whatsapp.isNotEmpty ? vendor.whatsapp : vendor.phone;
    if (phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No contact number for this vendor.')),
      );
      return;
    }

    final lines = order.items
        .map((item) => '• ${item.name} (${_formatCents(item.priceCents)})')
        .join('\n');
    final message = Uri.encodeComponent(
      'Hi ${vendor.name}, I would like to order:\n\n'
      '$lines\n\n'
      'Total: ${order.totalLabel}\n'
      'Reference: ${order.reference}',
    );

    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final whatsappUri = Uri.parse('https://wa.me/$cleanPhone?text=$message');

    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatCents(int cents) =>
      '\$${(cents / 100).toStringAsFixed(2)}';

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

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('cart.orderPlaced')),
        content: Text(
          orders.length == 1
              ? 'Your order ${orders.first.reference} has been saved. '
                  'Contact the vendor on WhatsApp to complete payment.'
              : '${orders.length} orders placed (one per vendor). '
                  'Contact each vendor on WhatsApp to complete payment.',
        ),
        actions: [
          if (orders.length == 1)
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                final vendor = _vendorFor(orders.first.vendorId);
                if (vendor != null) {
                  _contactVendorForOrder(orders.first, vendor);
                }
              },
              child: Text(context.tr('cart.contactVendor')),
            )
          else
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('cart.done')),
            ),
        ],
      ),
    );

    if (orders.length > 1 && mounted) {
      Navigator.pop(context);
    }
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
                    final vendor = _vendorFor(product.vendorId);
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
                        subtitle: Text(
                          vendor?.name ?? 'Vendor',
                          style: TextStyle(color: Colors.grey[600]),
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
