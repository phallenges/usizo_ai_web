import 'package:flutter/material.dart';

import '../l10n/localized.dart';
import '../models/remedy.dart';
import '../services/app_store.dart';
import '../services/symptom_checker.dart';
import '../services/vendor_store.dart';
import 'marketplace_screen.dart';
import 'profile_screen.dart';
import 'symptom_checker_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.store,
    required this.vendorStore,
    required this.remedies,
    required this.checker,
    super.key,
  });

  final AppStore store;
  final VendorStore vendorStore;
  final List<Remedy> remedies;
  final SymptomChecker checker;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  var selectedIndex = 0;

  void _goToProfile() => setState(() => selectedIndex = 2);

  @override
  Widget build(BuildContext context) {
    final pages = [
      SymptomCheckerScreen(
        store: widget.store,
        remedies: widget.remedies,
        checker: widget.checker,
        onUpgrade: _goToProfile,
      ),
      MarketplaceScreen(store: widget.store, vendorStore: widget.vendorStore),
      ProfileScreen(store: widget.store, vendorStore: widget.vendorStore),
    ];
    return Scaffold(
      body: IndexedStack(index: selectedIndex, children: pages),
      bottomNavigationBar: AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) {
          final cartCount = widget.store.cartCount;
          return NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) =>
                setState(() => selectedIndex = index),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.health_and_safety_outlined),
                selectedIcon: const Icon(Icons.health_and_safety),
                label: context.tr('nav.check'),
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: cartCount > 0,
                  label: Text('$cartCount'),
                  child: const Icon(Icons.storefront_outlined),
                ),
                selectedIcon: const Icon(Icons.storefront),
                label: context.tr('nav.market'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline),
                selectedIcon: const Icon(Icons.person),
                label: context.tr('nav.profile'),
              ),
            ],
          );
        },
      ),
    );
  }
}

