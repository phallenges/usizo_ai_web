import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/localized.dart';
import '../models/product.dart';
import '../models/vendor.dart';
import '../services/app_store.dart';
import '../services/marketplace_catalog.dart';
import 'cart_screen.dart';

/// Marketplace screen showing the single herbal vendor's products.
///
/// Products marked as available online can be added to the cart or bought now.
/// Customers can also contact the supplier directly.
class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({
    required this.store,
    super.key,
  });

  final AppStore store;

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final searchController = TextEditingController();

  String query = '';
  List<Product> products = [];
  List<Vendor> vendors = [];
  bool isLoading = true;
  Vendor? selectedVendor;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final catalog = await MarketplaceCatalog.load(widget.store.backendApi);
    if (mounted) {
      setState(() {
        products = catalog.products;
        vendors = catalog.vendors;
        if (selectedVendor != null) {
          final selectedId = selectedVendor!.id;
          selectedVendor = null;
          for (final vendor in catalog.vendors) {
            if (vendor.id == selectedId) {
              selectedVendor = vendor;
              break;
            }
          }
        }
        isLoading = false;
      });
    }
  }

  void _openCart() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CartScreen(
          store: widget.store,
        ),
      ),
    );
  }

  void _addToCart(Product product) {
    widget.store.addToCart(product);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} ${context.tr('market.addedToCart')}'),
        action: SnackBarAction(
          label: context.tr('market.viewCart'),
          onPressed: _openCart,
        ),
      ),
    );
  }

  void _contactVendor(Vendor vendor) async {
    final phone = vendor.whatsapp.isNotEmpty ? vendor.whatsapp : vendor.phone;
    if (phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('market.noContact'))),
      );
      return;
    }

    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final whatsappUri = Uri.parse('https://wa.me/$cleanPhone');
    final telUri = Uri(scheme: 'tel', path: cleanPhone);

    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(telUri)) {
      await launchUrl(telUri);
    }
  }

  void _buyOnline(Product product) {
    _addToCart(product);
    _openCart();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedProducts = products.where((product) {
      return selectedVendor != null && product.vendorId == selectedVendor!.id;
    });
    final filtered = selectedProducts.where((product) {
      final haystack =
          '${product.name} ${product.category} ${product.description} ${product.tags.join(' ')}'
              .toLowerCase();
      return haystack.contains(query.toLowerCase());
    }).toList();

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: Text(context.tr('market.title')),
            actions: [
              AnimatedBuilder(
                animation: widget.store,
                builder: (context, _) {
                  final count = widget.store.cartCount;
                  return IconButton(
                    onPressed: _openCart,
                    tooltip: context.tr('market.viewCart'),
                    icon: Badge(
                      isLabelVisible: count > 0,
                      label: Text('$count'),
                      child: const Icon(Icons.shopping_cart_outlined),
                    ),
                  );
                },
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (selectedVendor == null) ...[
                  Text('Choose a supplier to view their products.'),
                  const SizedBox(height: 14),
                ],
                if (isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (selectedVendor == null && vendors.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No suppliers are available right now.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else if (selectedVendor == null)
                  ...vendors.map(
                    (vendor) => _VendorHeroCard(
                      vendor: vendor,
                      onTap: () => setState(() {
                        selectedVendor = vendor;
                        query = '';
                        searchController.clear();
                      }),
                    ),
                  )
                else ...[
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => setState(() {
                          selectedVendor = null;
                          query = '';
                          searchController.clear();
                        }),
                        icon: const Icon(Icons.arrow_back),
                        tooltip: 'All suppliers',
                      ),
                      Expanded(
                        child: Text(
                          selectedVendor!.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  _VendorHeroCard(vendor: selectedVendor!),
                  const SizedBox(height: 14),
                  TextField(
                    controller: searchController,
                    onChanged: (value) => setState(() => query = value),
                    decoration: const InputDecoration(
                      hintText: "Search this supplier's products",
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (filtered.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'This supplier has no products available yet.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ...filtered.map(
                      (product) => AnimatedBuilder(
                        animation: widget.store,
                        builder: (context, _) {
                          final inCart = widget.store.isInCart(product.id);
                          return _ProductCard(
                            product: product,
                            vendor: selectedVendor,
                            inCart: inCart,
                            onAddToCart: () => _addToCart(product),
                            onRemoveFromCart: () =>
                                widget.store.removeFromCart(product),
                            onContactVendor: () =>
                                _contactVendor(selectedVendor!),
                            onBuyNow: () => _buyOnline(product),
                          );
                        },
                      ),
                    ),
                ],
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      context.tr('market.safetyFirst'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr('market.disclaimer'),
                  textAlign: TextAlign.center,
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Vendor Hero Card ─────────────────────────────────────────────────────

class _VendorHeroCard extends StatelessWidget {
  const _VendorHeroCard({required this.vendor, this.onTap});

  final Vendor vendor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primary,
                radius: 28,
                child: Text(
                  vendor.name.isNotEmpty ? vendor.name[0] : '?',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vendor.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      vendor.location,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer
                            .withValues(alpha: 0.7),
                      ),
                    ),
                    if (vendor.rating > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star, size: 16, color: Colors.amber[700]),
                          const SizedBox(width: 4),
                          Text(
                            vendor.ratingLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${vendor.reviewCount} reviews)',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
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

// ── Product Card ───────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.vendor,
    required this.inCart,
    required this.onAddToCart,
    required this.onRemoveFromCart,
    required this.onContactVendor,
    required this.onBuyNow,
  });

  final Product product;
  final Vendor? vendor;
  final bool inCart;
  final VoidCallback onAddToCart;
  final VoidCallback onRemoveFromCart;
  final VoidCallback onContactVendor;
  final VoidCallback onBuyNow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product name + price + stock badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (product.category.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          product.category,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!product.inStock)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          Localized.of(context).t('market.outOfStock'),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Description
            if (product.description.isNotEmpty)
              Text(product.description, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),

            // Action buttons
            if (product.inStock) ...[
              SizedBox(
                width: double.infinity,
                child: inCart
                    ? OutlinedButton.icon(
                        onPressed: onRemoveFromCart,
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(
                            Localized.of(context).t('market.inCartRemove')),
                      )
                    : FilledButton.icon(
                        onPressed: onAddToCart,
                        icon: const Icon(Icons.add_shopping_cart),
                        label:
                            Text(Localized.of(context).t('market.addToCart')),
                      ),
              ),
              const SizedBox(height: 8),
              if (product.canBuyOnline)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: onBuyNow,
                    icon: const Icon(Icons.flash_on_outlined),
                    label: Text(Localized.of(context).t('market.buyNow')),
                  ),
                ),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onContactVendor,
                icon: const Icon(Icons.chat_bubble_outline),
                label: Text(
                  !product.inStock
                      ? '${Localized.of(context).t('market.outOfStockContact')} ${vendor?.name ?? ''}'
                      : '${Localized.of(context).t('market.contactOnWhatsApp')} ${vendor?.name ?? ''}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
