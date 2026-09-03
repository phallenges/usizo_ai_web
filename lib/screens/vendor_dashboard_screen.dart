import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/product.dart';
import '../services/app_store.dart';
import '../services/vendor_store.dart';
import 'vendor_product_form_screen.dart';

/// Vendor dashboard for managing products and shop profile.
class VendorDashboardScreen extends StatelessWidget {
  const VendorDashboardScreen({
    required this.vendorStore,
    required this.store,
    super.key,
  });

  final VendorStore vendorStore;
  final AppStore store;

  Future<void> _rejectPayment(BuildContext context, Order order) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject payment proof'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason for buyer',
            hintText: 'For example: amount or reference is unclear',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Reject proof'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null) return;
    store.reviewPaymentProof(order.id, approved: false, reason: reason);
  }

  void _confirmOrder(BuildContext context, Order order, {required String action}) {
    final priceController = TextEditingController(
      text: order.totalCents > 0 ? (order.totalCents / 100).toStringAsFixed(2) : '',
    );
    final deliveryAreaController = TextEditingController(text: order.deliveryArea);
    final collectionPointController = TextEditingController(text: order.collectionPoint);
    final turnaroundController = TextEditingController(text: order.turnaroundTime);
    final paymentInstructionsController = TextEditingController(text: order.paymentInstructions);
    final deliveryInstructionsController = TextEditingController(text: order.deliveryInstructions);
    final notesController = TextEditingController(text: order.vendorNotes);
    String deliveryMethod = order.deliveryMethod.isEmpty ? 'delivery' : order.deliveryMethod;

    if (action == 'decline') {
      showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Decline order'),
          content: TextField(
            controller: notesController,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason (shown to customer)',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, notesController.text),
              child: const Text('Decline'),
            ),
          ],
        ),
      ).then((reason) {
        if (reason != null) {
          vendorStore.declineOrder(orderId: order.id, reason: reason);
        }
        _disposeControllers([priceController, deliveryAreaController,
          collectionPointController, turnaroundController,
          paymentInstructionsController, deliveryInstructionsController, notesController]);
      });
      return;
    }

    // Confirm flow — show details form
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Confirm order'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Final price (USD)',
                    prefixText: '\$ ',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: deliveryMethod,
                  decoration: const InputDecoration(labelText: 'Delivery method'),
                  items: const [
                    DropdownMenuItem(value: 'delivery', child: Text('Delivery')),
                    DropdownMenuItem(value: 'collection', child: Text('Collection')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => deliveryMethod = v);
                  },
                ),
                const SizedBox(height: 12),
                if (deliveryMethod == 'delivery')
                  TextField(
                    controller: deliveryAreaController,
                    decoration: const InputDecoration(labelText: 'Delivery area'),
                  ),
                if (deliveryMethod == 'collection')
                  TextField(
                    controller: collectionPointController,
                    decoration: const InputDecoration(labelText: 'Collection point'),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: turnaroundController,
                  decoration: const InputDecoration(
                    labelText: 'Turnaround time',
                    hintText: 'e.g. 2 hours, next day',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: paymentInstructionsController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Payment instructions',
                    hintText: 'e.g. Send to 077 123 4567, reference ORD-XXX',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: deliveryInstructionsController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Delivery / collection instructions',
                    hintText: 'e.g. Deliver after 5pm, or collect from Shop 3',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx, {
                  'finalPrice': priceController.text.trim(),
                  'deliveryMethod': deliveryMethod,
                  'deliveryArea': deliveryAreaController.text.trim(),
                  'collectionPoint': collectionPointController.text.trim(),
                  'turnaround': turnaroundController.text.trim(),
                  'paymentInstructions': paymentInstructionsController.text.trim(),
                  'deliveryInstructions': deliveryInstructionsController.text.trim(),
                });
              },
              child: const Text('Confirm order'),
            ),
          ],
        ),
      ),
    ).then((result) {
      _disposeControllers([priceController, deliveryAreaController,
        collectionPointController, turnaroundController,
        paymentInstructionsController, deliveryInstructionsController, notesController]);
      if (result == null) return;
      final priceDollars = double.tryParse(result['finalPrice'] as String? ?? '');
      final priceCents = priceDollars != null ? (priceDollars * 100).round() : order.totalCents;
      vendorStore.confirmOrder(
        orderId: order.id,
        finalPriceCents: priceCents,
        deliveryMethod: result['deliveryMethod'] as String? ?? 'delivery',
        deliveryArea: result['deliveryArea'] as String? ?? '',
        collectionPoint: result['collectionPoint'] as String? ?? '',
        turnaroundTime: result['turnaround'] as String? ?? '',
        paymentInstructions: result['paymentInstructions'] as String? ?? '',
        deliveryInstructions: result['deliveryInstructions'] as String? ?? '',
      );
    });
  }

  void _disposeControllers(List<TextEditingController> controllers) {
    for (final c in controllers) {
      c.dispose();
    }
  }

  String _statusLabel(OrderStatus status) => switch (status) {
        OrderStatus.pending => 'Awaiting payment proof',
        OrderStatus.paymentProofSubmitted => 'Proof awaiting verification',
        OrderStatus.paymentRejected => 'Proof rejected',
        OrderStatus.confirmed => 'Payment verified',
        OrderStatus.delivered => 'Delivered',
        OrderStatus.cancelled => 'Cancelled',
      };

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
    final ecocashController = TextEditingController(text: vendor.ecocashNumber);
    final whatsappController = TextEditingController(text: vendor.whatsapp);
    final descriptionController =
        TextEditingController(text: vendor.description);

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
                controller: ecocashController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'EcoCash number'),
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
                  ecocashNumber: ecocashController.text.trim(),
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
      ecocashController.dispose();
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
        animation: Listenable.merge([vendorStore, store]),
        builder: (context, _) {
          // Fetch orders from backend on first build.
          if (vendorStore.isSignedIn && vendorStore.currentVendorOrders.isEmpty) {
            vendorStore.fetchOrders();
          }
          final vendor = vendorStore.currentVendor;
          final products = vendorStore.currentVendorProducts;
          final orders = vendorStore.currentVendorOrders;

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
                'Payment verification',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (orders.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No customer orders yet.'),
                  ),
                )
              else
                ...orders.map((order) {
                  final awaitingReview =
                      order.status == OrderStatus.paymentProofSubmitted;
                  final proofBytes = order.paymentProofBase64.isEmpty
                      ? null
                      : base64Decode(order.paymentProofBase64);
                  final awaitingConfirmation =
                      order.status == OrderStatus.pending;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(order.reference,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                              ),
                              Chip(label: Text(_statusLabel(order.status))),
                            ],
                          ),
                          Text(
                              '${order.totalLabel} · ${order.items.map((item) => '${item.name} × ${item.quantity}').join(', ')}'),
                          // Show vendor confirmation details if confirmed
                          if (order.status == OrderStatus.confirmed &&
                              order.paymentInstructions.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (order.finalPriceCents != null)
                                    Text('Confirmed total: ${order.confirmedTotalLabel}',
                                        style: const TextStyle(fontWeight: FontWeight.w600)),
                                  if (order.deliveryMethod.isNotEmpty)
                                    Text('Delivery: ${order.deliveryMethod}${order.deliveryArea.isNotEmpty ? ' — ${order.deliveryArea}' : ''}'),
                                  if (order.collectionPoint.isNotEmpty)
                                    Text('Collection: ${order.collectionPoint}'),
                                  if (order.turnaroundTime.isNotEmpty)
                                    Text('Turnaround: ${order.turnaroundTime}'),
                                  if (order.paymentInstructions.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text('Payment: ${order.paymentInstructions}',
                                        style: const TextStyle(fontSize: 12)),
                                  ],
                                  if (order.deliveryInstructions.isNotEmpty)
                                    Text('Delivery info: ${order.deliveryInstructions}',
                                        style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                          if (proofBytes != null) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(proofBytes,
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover),
                            ),
                          ],
                          if (order.paymentRejectionReason.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text('Reason: ${order.paymentRejectionReason}',
                                style:
                                    TextStyle(color: theme.colorScheme.error)),
                          ],
                          if (awaitingConfirmation) ...[
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () =>
                                      _confirmOrder(context, order, action: 'decline'),
                                  child: const Text('Decline'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () =>
                                      _confirmOrder(context, order, action: 'confirm'),
                                  child: const Text('Confirm order'),
                                ),
                              ),
                            ]),
                          ],
                          if (awaitingReview) ...[
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () =>
                                      _rejectPayment(context, order),
                                  child: const Text('Reject'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () => store.reviewPaymentProof(
                                      order.id,
                                      approved: true),
                                  child: const Text('Approve payment'),
                                ),
                              ),
                            ]),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 12),
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
