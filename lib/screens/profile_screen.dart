import 'package:flutter/material.dart';

import '../l10n/localized.dart';
import '../models/user_profile.dart';
import '../services/app_store.dart';
import '../services/vendor_store.dart';
import 'activate_screen.dart';
import 'payment_details_screen.dart';
import 'vendor_auth_screen.dart';
import 'vendor_dashboard_screen.dart';
import '../services/integration_stubs.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.store,
    required this.vendorStore,
    super.key,
  });

  final AppStore store;
  final VendorStore vendorStore;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController nameController;
  late final TextEditingController emailController;
  late final TextEditingController allergiesController;
  late final TextEditingController emergencyController;

  @override
  void initState() {
    super.initState();
    final profile = widget.store.profile;
    nameController = TextEditingController(text: profile.name);
    emailController = TextEditingController(text: profile.email);
    allergiesController = TextEditingController(text: profile.allergies);
    emergencyController = TextEditingController(text: profile.emergencyContact);
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    allergiesController.dispose();
    emergencyController.dispose();
    super.dispose();
  }

  void save() {
    widget.store.updateProfile(
      UserProfile(
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        allergies: allergiesController.text.trim(),
        emergencyContact: emergencyController.text.trim(),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('profile.saved'))),
    );
  }

  Future<void> _subscribePremium() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();

    final gateway = ProductionPaymentGateway();
    final instruction = gateway.subscribePremium(
      userEmail: email,
      userName: name.isNotEmpty ? name : 'User',
    );

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentDetailsScreen(instruction: instruction),
      ),
    );
  }

  void _activateToken() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivateScreen(store: widget.store),
      ),
    );
  }

  void _openVendorPortal() {
    if (widget.vendorStore.isSignedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VendorDashboardScreen(
              vendorStore: widget.vendorStore, store: widget.store),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VendorAuthScreen(
              vendorStore: widget.vendorStore, store: widget.store),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text(
            context.tr('profile.title'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(context.tr('profile.staysOnDevice')),
          const SizedBox(height: 22),
          TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: context.tr('profile.name'),
              prefixIcon: const Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: context.tr('profile.emailOptional'),
              prefixIcon: const Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: allergiesController,
            decoration: InputDecoration(
              labelText: context.tr('profile.allergies'),
              prefixIcon: const Icon(Icons.warning_amber_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: emergencyController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: context.tr('profile.emergencyContact'),
              prefixIcon: const Icon(Icons.contact_phone_outlined),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: save,
            icon: const Icon(Icons.save_outlined),
            label: Text(context.tr('profile.saveProfile')),
          ),
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: widget.store,
            builder: (context, _) {
              if (widget.store.isPremium) {
                return Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Colors.green),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('profile.usizoPlus'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                  context.tr('profile.unlimitedChecksEnabled')),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: Colors.orange),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr('profile.unlockPlus'),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(context.tr('profile.plusDescription')),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _subscribePremium,
                        child: Text(context.tr('profile.payWithEcoCash')),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _activateToken,
                        child: Text(context.tr('profile.hasToken')),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: widget.vendorStore,
            builder: (context, _) {
              final signedIn = widget.vendorStore.isSignedIn;
              final vendor = widget.vendorStore.currentVendor;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            signedIn ? Icons.store : Icons.storefront_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  signedIn
                                      ? context.tr('profile.yourVendorShop')
                                      : context.tr('profile.sellOnUsizo'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  signedIn
                                      ? '${vendor?.name ?? 'Shop'} · ${widget.vendorStore.currentVendorProducts.length} ${context.tr('profile.products')}'
                                      : context.tr('profile.signupDescription'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _openVendorPortal,
                        child: Text(
                          signedIn
                              ? context.tr('profile.manageShop')
                              : context.tr('profile.becomeVendor'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: widget.store,
            builder: (context, _) {
              final orders = widget.store.orders;
              if (orders.isEmpty) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('profile.orderHistory'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ...orders.take(5).map(
                        (order) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.receipt_long_outlined),
                            title: Text(order.reference),
                            subtitle: Text(
                              '${order.items.length} item(s) · ${order.status.name}',
                            ),
                            trailing: Text(
                              order.totalLabel,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                  const SizedBox(height: 4),
                ],
              );
            },
          ),
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
        ],
      ),
    );
  }
}
