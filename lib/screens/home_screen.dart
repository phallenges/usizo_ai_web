import 'package:flutter/material.dart';

import '../models/remedy.dart';
import '../services/app_store.dart';
import '../services/symptom_checker.dart';
import 'marketplace_screen.dart';
import 'profile_screen.dart';
import 'symptom_checker_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.store,
    required this.remedies,
    required this.checker,
    super.key,
  });

  final AppStore store;
  final List<Remedy> remedies;
  final SymptomChecker checker;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  var selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      SymptomCheckerScreen(
        store: widget.store,
        remedies: widget.remedies,
        checker: widget.checker,
      ),
      MarketplaceScreen(store: widget.store, remedies: widget.remedies),
      ProfileScreen(store: widget.store),
    ];
    return Scaffold(
      body: IndexedStack(index: selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => setState(() => selectedIndex = index),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.health_and_safety_outlined),
            selectedIcon: Icon(Icons.health_and_safety),
            label: 'Check',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: widget.store.cartCount > 0,
              label: Text('${widget.store.cartCount}'),
              child: const Icon(Icons.storefront_outlined),
            ),
            selectedIcon: const Icon(Icons.storefront),
            label: 'Market',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

