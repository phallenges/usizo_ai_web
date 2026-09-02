import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/localized.dart';
import '../models/product.dart';
import '../models/vendor.dart';
import '../services/app_store.dart';
import '../services/connectivity_service.dart';
import '../services/location_service.dart';
import '../services/marketplace_catalog.dart';
import '../services/vendor_store.dart';
import 'cart_screen.dart';
import 'vendor_auth_screen.dart';
import 'vendor_dashboard_screen.dart';

/// Marketplace screen showing vendor products for sale.
///
/// - Online + product canBuyOnline → "Buy now" button
/// - Online + product !canBuyOnline → "Contact vendor on WhatsApp"
/// - Offline → all products show "Contact vendor" (WhatsApp intent opens offline too)
///
/// Vendors are sorted by distance from the user's current location.
class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({
    required this.store,
    required this.vendorStore,
    super.key,
  });

  final AppStore store;
  final VendorStore vendorStore;

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final searchController = TextEditingController();
  final connectivity = ConnectivityService();
  final locationService = LocationService();

  String query = '';
  List<Product> products = [];
  List<Vendor> vendors = [];
  bool isLoading = true;
  bool isOnline = true;

  // User's current position
  double? userLat;
  double? userLng;
  bool locationLoaded = false;

  @override
  void initState() {
    super.initState();
    connectivity.init();
    _subscription = connectivity.onConnectivityChanged.listen((online) {
      if (mounted) setState(() => isOnline = online);
    });
    isOnline = connectivity.isOnline;
    widget.vendorStore.addListener(_loadData);
    _loadData();
    _loadLocation();
  }

  StreamSubscription<bool>? _subscription;

  Future<void> _loadData() async {
    final catalog = await MarketplaceCatalog.load(widget.vendorStore);
    if (mounted) {
      setState(() {
        products = catalog.products;
        vendors = catalog.vendors;
        isLoading = false;
      });
    }
  }

  void _openVendorPortal() {
    if (widget.vendorStore.isSignedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              VendorDashboardScreen(vendorStore: widget.vendorStore),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VendorAuthScreen(vendorStore: widget.vendorStore),
        ),
      );
    }
  }

  Future<void> _loadLocation() async {
    final position = await locationService.getCurrentPosition();
    if (mounted && position != null) {
      setState(() {
        userLat = position.latitude;
        userLng = position.longitude;
        locationLoaded = true;
      });
    } else if (mounted) {
      setState(() => locationLoaded = true);
    }
  }

  Vendor? _vendorFor(String vendorId) {
    try {
      return vendors.firstWhere((v) => v.id == vendorId);
    } catch (_) {
      return null;
    }
  }

  /// Sort vendors by distance from user (nearest first).
  /// Vendors without coordinates go last.
  List<Vendor> _sortedVendors() {
    if (userLat == null || userLng == null) return vendors;

    final sorted = List<Vendor>.from(vendors);
    sorted.sort((a, b) {
      if (!a.hasCoordinates && !b.hasCoordinates) return 0;
      if (!a.hasCoordinates) return 1;
      if (!b.hasCoordinates) return -1;
      final distA = LocationService.distanceKm(
        lat1: userLat!,
        lng1: userLng!,
        lat2: a.lat!,
        lng2: a.lng!,
      );
      final distB = LocationService.distanceKm(
        lat1: userLat!,
        lng1: userLng!,
        lat2: b.lat!,
        lng2: b.lng!,
      );
      return distA.compareTo(distB);
    });
    return sorted;
  }

  /// Distance from user to a vendor in km, or null if unknown.
  double? _distanceTo(Vendor vendor) {
    if (userLat == null || userLng == null || !vendor.hasCoordinates) return null;
    return LocationService.distanceKm(
      lat1: userLat!,
      lng1: userLng!,
      lat2: vendor.lat!,
      lng2: vendor.lng!,
    );
  }

  void _openCart() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CartScreen(
          store: widget.store,
          vendorStore: widget.vendorStore,
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
  }

  @override
  void dispose() {
    widget.vendorStore.removeListener(_loadData);
    _subscription?.cancel();
    connectivity.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sortedVendors = _sortedVendors();
    final filtered = products.where((product) {
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
              IconButton(
                onPressed: _openVendorPortal,
                tooltip: widget.vendorStore.isSignedIn
                    ? context.tr('market.myShop')
                    : context.tr('market.sellOnUsizo'),
                icon: Icon(
                  widget.vendorStore.isSignedIn
                      ? Icons.store
                      : Icons.storefront_outlined,
                ),
              ),
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
              // Connectivity indicator
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOnline ? Colors.green.shade100 : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOnline ? Icons.wifi : Icons.wifi_off,
                          size: 14,
                          color: isOnline ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isOnline ? context.tr('market.online') : context.tr('market.offline'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isOnline ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  isOnline
                      ? context.tr('market.shopOnline')
                      : context.tr('market.shopOffline'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: searchController,
                  onChanged: (value) => setState(() => query = value),
                  decoration: InputDecoration(
                    hintText: context.tr('market.searchProducts'),
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Location banner ────────────────────────────────
                if (!locationLoaded)
                  const SizedBox.shrink()
                else if (userLat == null)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.location_off, color: Colors.grey),
                      title: Text(context.tr('market.locationUnavailable')),
                      subtitle: Text(context.tr('market.enableLocation')),
                      trailing: TextButton(
                        onPressed: _loadLocation,
                        child: Text(context.tr('market.retry')),
                      ),
                    ),
                  )
                else
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.my_location, color: Colors.blue),
                      title: Text(context.tr('market.nearbyVendors')),
                      subtitle: Text(
                        context.tr('market.sortedByDistance'),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // ── Products ───────────────────────────────────────
                if (isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (filtered.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        context.tr('market.noProducts'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ...filtered.map(
                    (product) {
                      final vendor = _vendorFor(product.vendorId);
                      final distance = vendor != null ? _distanceTo(vendor) : null;

                      return AnimatedBuilder(
                        animation: widget.store,
                        builder: (context, _) {
                          final inCart = widget.store.isInCart(product.id);
                          return _ProductCard(
                            product: product,
                            vendor: vendor,
                            distance: distance,
                            isOnline: isOnline,
                            inCart: inCart,
                            onAddToCart: () => _addToCart(product),
                            onRemoveFromCart: () =>
                                widget.store.removeFromCart(product),
                            onContactVendor: () {
                              if (vendor != null) _contactVendor(vendor);
                            },
                            onBuyNow: () => _buyOnline(product),
                          );
                        },
                      );
                    },
                  ),
                const SizedBox(height: 20),

                // ── Nearby vendors section ─────────────────────────
                if (sortedVendors.isNotEmpty) ...[
                  Text(
                    userLat != null ? context.tr('market.vendorsNearYou') : context.tr('market.ourVendors'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ...sortedVendors.map(
                    (vendor) => _VendorCard(
                      vendor: vendor,
                      distance: _distanceTo(vendor),
                      onContact: () => _contactVendor(vendor),
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

// ── Product Card ───────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.vendor,
    required this.distance,
    required this.isOnline,
    required this.inCart,
    required this.onAddToCart,
    required this.onRemoveFromCart,
    required this.onContactVendor,
    required this.onBuyNow,
  });

  final Product product;
  final Vendor? vendor;
  final double? distance;
  final bool isOnline;
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
                    Text(
                      product.priceLabel,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    if (!product.inStock)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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

            // Vendor info with distance
            if (vendor != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.store, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      vendor!.name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      vendor!.location,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    if (distance != null) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.near_me, size: 14, color: Colors.blue[600]),
                      Text(
                        LocationService.formatDistance(distance!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.blue[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (vendor!.rating > 0) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.star, size: 14, color: Colors.amber[700]),
                      Text(
                        vendor!.ratingLabel,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 12),

            // Action buttons
            if (product.inStock) ...[
              SizedBox(
                width: double.infinity,
                child: inCart
                    ? OutlinedButton.icon(
                        onPressed: onRemoveFromCart,
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(Localized.of(context).t('market.inCartRemove')),
                      )
                    : FilledButton.icon(
                        onPressed: onAddToCart,
                        icon: const Icon(Icons.add_shopping_cart),
                        label: Text(Localized.of(context).t('market.addToCart')),
                      ),
              ),
              const SizedBox(height: 8),
              if (isOnline && product.canBuyOnline)
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

// ── Vendor Card ────────────────────────────────────────────────────────────

class _VendorCard extends StatelessWidget {
  const _VendorCard({
    required this.vendor,
    required this.distance,
    required this.onContact,
  });

  final Vendor vendor;
  final double? distance;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            vendor.name.isNotEmpty ? vendor.name[0] : '?',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(vendor.name),
        subtitle: Row(
          children: [
            Flexible(
              child: Text(
                vendor.location,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (distance != null) ...[
              Text(' · ${LocationService.formatDistance(distance!)}'),
            ],
            if (vendor.rating > 0) ...[
              Text(' · ${vendor.ratingLabel}'),
            ],
          ],
        ),
        trailing: FilledButton.tonal(
          onPressed: onContact,
          child: Text(Localized.of(context).t('market.contactVendor')),
        ),
      ),
    );
  }
}
