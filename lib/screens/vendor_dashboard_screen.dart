import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/vendor_store.dart';
import 'vendor_product_form_screen.dart';

/// Vendor dashboard for managing products and shop profile.
class VendorDashboardScreen extends StatelessWidget {
  const VendorDashboardScreen({required this.vendorStore, super.key});

  final VendorStore vendorStore;

  void _openProductForm(BuildContext context, {Product? product}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VendorProductFormScreen(
          vendorStore: vendorStore,
          product: product,
        ),
      ),
    );
  }

  void _editProfile(BuildContext context, VendorStore store) {
    final vendor = store.currentVendor;
    if (vendor == null) return;

    final nameController = TextEditingController(text: vendor.name);
    final locationController = TextEditingController(text: vendor.location);
    final phoneController = TextEditingController(text: vendor.phone);
    final whatsappController = TextEditingController(text: vendor.whatsapp);
    final descriptionController = TextEditingController(text: vendor.description);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit shop profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Business name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(labelText: 'Location'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: whatsappController,
                decoration: const InputDecoration(labelText: 'WhatsApp'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              store.updateProfile(
                vendor.copyWith(
                  name: nameController.text.trim(),
                  location: locationController.text.trim(),
                  phone: phoneController.text.trim(),
                  whatsapp: whatsappController.text.trim(),
                  description: descriptionController.text.trim(),
                ),
              );
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((_) {
      nameController.dispose();
      locationController.dispose();
      phoneController.dispose();
      whatsappController.dispose();
      descriptionController.dispose();
    });
  }

  Future<void> _confirmDelete(BuildContext context, Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove product'),
        content: Text('Remove "${product.name}" from your shop?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      vendorStore.removeProduct(product.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My shop'),
        actions: [
          IconButton(
            onPressed: () => _editProfile(context, vendorStore),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Edit profile',
          ),
          IconButton(
            onPressed: () {
              vendorStore.signOut();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openProductForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Add product'),
      ),
      body: AnimatedBuilder(
        animation: vendorStore,
        builder: (context, _) {
          final vendor = vendorStore.currentVendor;
          final products = vendorStore.currentVendorProducts;

          if (vendor == null) {
            return const Center(child: Text('No vendor session found.'));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 88),
            children: [
              Card(
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: theme.colorScheme.primary,
                            child: Text(
                              vendor.name.isNotEmpty ? vendor.name[0] : '?',
                              style: TextStyle(
                                color: theme.colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
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
                                Text(vendor.location),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (vendor.description.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(vendor.description),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        '${products.length} product${products.length == 1 ? '' : 's'} listed',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Your products',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (products.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 48,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No products yet',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tap "Add product" to list your first herbal product.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...products.map(
                  (product) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      title: Text(
                        product.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${product.category} · ${product.priceLabel}'
                        '${product.inStock ? '' : ' · Out of stock'}',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          switch (value) {
                            case 'edit':
                              _openProductForm(context, product: product);
                            case 'stock':
                              vendorStore.toggleProductStock(product.id);
                            case 'delete':
                              _confirmDelete(context, product);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          PopupMenuItem(
                            value: 'stock',
                            child: Text(
                              product.inStock
                                  ? 'Mark out of stock'
                                  : 'Mark in stock',
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Remove'),
                          ),
                        ],
                      ),
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
