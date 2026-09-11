import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/order.dart';
import '../models/vendor.dart';
import '../services/app_store.dart';
import 'payment_proof_screen.dart';

/// Guides a buyer through manual EcoCash payment and proof submission.
class OrderConfirmationScreen extends StatelessWidget {
  const OrderConfirmationScreen(
      {required this.store,
      required this.orders,
      required this.vendors,
      super.key});

  final AppStore store;
  final List<Order> orders;
  final List<Vendor> vendors;

  Vendor? _vendorFor(String id) {
    for (final vendor in vendors) {
      if (vendor.id == id) return vendor;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Complete your EcoCash order')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          ...orders.map((order) {
            final vendor = _vendorFor(order.vendorId);
            final isConfirmed = order.status == OrderStatus.confirmed;
            final isPending = order.status == OrderStatus.pending;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vendor?.name ?? 'Treasure Motsu',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 6),
                      ...order.items.map(
                          (item) => Text('${item.name} × ${item.quantity}')),
                      const Divider(height: 22),
                      Text('Reference: ${order.reference}'),
                      if (isConfirmed && order.finalPriceCents != null)
                        Text('Confirmed total: ${order.confirmedTotalLabel}',
                            style: const TextStyle(fontWeight: FontWeight.w600))
                      else
                        Text('Estimated total: ${order.totalLabel}'),

                      // Vendor confirmation details
                      if (isConfirmed &&
                          order.paymentInstructions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Vendor instructions:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                              const SizedBox(height: 4),
                              Text('Payment: ${order.paymentInstructions}',
                                  style: const TextStyle(fontSize: 13)),
                              if (order.deliveryMethod.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  order.deliveryMethod == 'collection'
                                      ? 'Collection: ${order.collectionPoint}'
                                      : 'Delivery: ${order.deliveryArea}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                              if (order.turnaroundTime.isNotEmpty)
                                Text('Ready in: ${order.turnaroundTime}',
                                    style: const TextStyle(fontSize: 13)),
                              if (order.deliveryInstructions.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(order.deliveryInstructions,
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                              ],
                            ],
                          ),
                        ),
                      ],

                      if (isPending) ...[
                        const SizedBox(height: 8),
                        Card(
                          color: Colors.orange.shade50,
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                                'Waiting for vendor to confirm your order. You\'ll see payment instructions once confirmed.'),
                          ),
                        ),
                      ],

                      if (isPending)
                        const SizedBox.shrink()
                      else ...[
                        const SizedBox(height: 12),
                        Row(children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: order.reference));
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Order reference copied')));
                            },
                            icon: const Icon(Icons.copy_outlined),
                            label: const Text('Copy reference'),
                          ),
                          const SizedBox(width: 8),
                          if (order.status != OrderStatus.cancelled &&
                              order.status != OrderStatus.delivered)
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: vendor == null
                                    ? null
                                    : () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => PaymentProofScreen(
                                              store: store,
                                              order: order,
                                              vendor: vendor,
                                            ),
                                          ),
                                        ),
                                icon: const Icon(Icons.upload_file_outlined),
                                label: const Text('Pay & upload proof'),
                              ),
                            ),
                        ]),
                      ],
                    ]),
              ),
            );
          }),
        ],
      ),
    );
  }
}
