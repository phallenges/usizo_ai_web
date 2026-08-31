import 'package:flutter/material.dart';

import '../models/remedy.dart';
import '../services/app_store.dart';
import 'dart:async';

import '../services/integration_stubs.dart';
import '../widgets/remedy_card.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({
    required this.store,
    required this.remedies,
    super.key,
  });

  final AppStore store;
  final List<Remedy> remedies;

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final searchController = TextEditingController();
  String query = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void showBasket() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your basket',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (widget.store.cart.isEmpty)
                const Text('Your basket is empty.')
              else ...[
                ...widget.store.cart.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.name),
                    trailing: IconButton(
                      onPressed: () => widget.store.removeFromCart(item),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                ),
                Text(
                  'Total: \$${(widget.store.cartTotalCents / 100).toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => unawaited(_processCheckout()),
                  child: const Text('Place Order'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processCheckout() async {
    if (widget.store.cart.isEmpty) return;

    Navigator.pop(context);

    // Show loading dialog
    if (!mounted) return;
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: SizedBox(
          height: 80,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Processing payment...'),
            ],
          ),
        ),
      ),
    ),
    );

    try {
      final gateway = ProductionPaymentGateway();
      final result = await gateway.checkoutCart(
        userEmail: widget.store.profile.email,
        userName: widget.store.profile.name,
        items: widget.store.cart,
        context: context,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (result.isSuccess) {
        widget.store.clearCart();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Order confirmed!\nRef: ${result.transactionRef}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Payment failed: ${result.errorReason}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.remedies.where((remedy) {
      final haystack =
          '${remedy.name} ${remedy.category} ${remedy.tags.join(' ')}'
              .toLowerCase();
      return haystack.contains(query.toLowerCase());
    }).toList();
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text('Wellness market'),
            actions: [
              AnimatedBuilder(
                animation: widget.store,
                builder: (context, _) => IconButton(
                  onPressed: showBasket,
                  tooltip: 'Basket',
                  icon: Badge(
                    isLabelVisible: widget.store.cartCount > 0,
                    label: Text('${widget.store.cartCount}'),
                    child: const Icon(Icons.shopping_basket_outlined),
                  ),
                ),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const Text(
                  'Premium wellness remedies with expert guidance.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: searchController,
                  onChanged: (value) => setState(() => query = value),
                  decoration: const InputDecoration(
                    hintText: 'Search remedies',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 16),
                ...filtered.map(
                  (remedy) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: RemedyCard(
                      remedy: remedy,
                      compact: true,
                      onAdd: () {
                        widget.store.addToCart(remedy);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${remedy.name} added.')),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'UsizoAI is not a replacement for professional medical care. Always consult a doctor for serious conditions.',
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
