import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/order.dart';
import '../models/product.dart';
import '../models/user_profile.dart';
import 'payment_service.dart';

class AppStore extends ChangeNotifier {
  UserProfile _profile = const UserProfile();
  bool _premium = false;
  int _checksUsed = 0;
  String _languageCode = 'en';
  final List<Product> _cart = [];
  final List<Order> _orders = [];

  UserProfile get profile => _profile;
  bool get isPremium => _premium;
  int get checksUsed => _checksUsed;
  int get checksRemaining {
    if (_premium) return 999;
    return (3 - _checksUsed).clamp(0, 3).toInt();
  }

  List<Product> get cart => List.unmodifiable(_cart);
  int get cartCount => _cart.length;
  int get cartTotalCents =>
      _cart.fold(0, (total, product) => total + product.priceCents);

  String get cartTotalLabel =>
      '\$${(cartTotalCents / 100).toStringAsFixed(2)}';

  bool isInCart(String productId) =>
      _cart.any((item) => item.id == productId);

  List<Order> get orders => List.unmodifiable(_orders);

  String get languageCode => _languageCode;

  bool get canCheck => _premium || _checksUsed < 3;

  Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final profileJson = preferences.getString('profile');
      if (profileJson != null) {
        _profile = UserProfile.fromJson(
          Map<String, Object?>.from(jsonDecode(profileJson) as Map),
        );
      }
      _premium = preferences.getBool('premium') ?? false;
      _checksUsed = preferences.getInt('checksUsed') ?? 0;
      _languageCode = preferences.getString('languageCode') ?? 'en';

      final ordersJson = preferences.getString('orders');
      if (ordersJson != null) {
        final decoded = jsonDecode(ordersJson) as List<dynamic>;
        _orders.clear();
        for (final item in decoded) {
          _orders.add(Order.fromJson(Map<String, Object?>.from(item as Map)));
        }
      }

      final cartJson = preferences.getString('cart');
      if (cartJson != null) {
        final decoded = jsonDecode(cartJson) as List<dynamic>;
        _cart.clear();
        for (final item in decoded) {
          _cart.add(Product.fromJson(Map<String, Object?>.from(item as Map)));
        }
      }
    } catch (_) {
      // The app remains fully usable when local storage is unavailable.
    }
  }

  void updateProfile(UserProfile profile) {
    _profile = profile;
    notifyListeners();
    _persist();
  }

  void setPremium(bool value) {
    _premium = value;
    notifyListeners();
    _persist();
  }

  void setLanguageCode(String code) {
    if (_languageCode == code) return;
    _languageCode = code;
    notifyListeners();
    _persist();
  }

  /// Activate premium with a token.
  /// Returns true if the token is valid, false otherwise.
  bool activateWithToken(String token) {
    if (TokenValidator.isValid(token)) {
      _premium = true;
      notifyListeners();
      _persist();
      return true;
    }
    return false;
  }

  bool recordCheck() {
    if (!canCheck) return false;
    if (!_premium) _checksUsed++;
    notifyListeners();
    _persist();
    return true;
  }

  // ── Cart ──────────────────────────────────────────────────────────

  void addToCart(Product product) {
    if (!product.inStock) return;
    if (_cart.every((item) => item.id != product.id)) {
      _cart.add(product);
      notifyListeners();
      _persist();
    }
  }

  void removeFromCart(Product product) {
    _cart.removeWhere((item) => item.id == product.id);
    notifyListeners();
    _persist();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
    _persist();
  }

  /// Group cart items by vendor for checkout.
  Map<String, List<Product>> cartByVendor() {
    final grouped = <String, List<Product>>{};
    for (final product in _cart) {
      grouped.putIfAbsent(product.vendorId, () => []).add(product);
    }
    return grouped;
  }

  /// Create pending orders from the cart and clear it.
  /// Returns the orders that were created.
  List<Order> checkoutCart() {
    if (_cart.isEmpty) return const [];

    final grouped = cartByVendor();
    final created = <Order>[];

    for (final entry in grouped.entries) {
      final items = entry.value
          .map(
            (product) => OrderItem(
              productId: product.id,
              name: product.name,
              priceCents: product.priceCents,
            ),
          )
          .toList();
      final total = items.fold(0, (sum, item) => sum + item.lineTotal);
      final reference =
          'ORD-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';

      final order = Order(
        id: reference,
        items: items,
        totalCents: total,
        vendorId: entry.key,
        reference: reference,
        createdAt: DateTime.now(),
      );
      created.add(order);
      _orders.insert(0, order);
    }

    _cart.clear();
    notifyListeners();
    _persist();
    return created;
  }

  // ── Orders ────────────────────────────────────────────────────────

  void addOrder(Order order) {
    _orders.insert(0, order);
    notifyListeners();
    _persist();
  }

  // ── Persistence ───────────────────────────────────────────────────

  Future<void> _persist() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('profile', jsonEncode(_profile.toJson()));
      await preferences.setBool('premium', _premium);
      await preferences.setInt('checksUsed', _checksUsed);
      await preferences.setString('languageCode', _languageCode);
      await preferences.setString(
        'orders',
        jsonEncode(_orders.map((o) => o.toJson()).toList()),
      );
      await preferences.setString(
        'cart',
        jsonEncode(_cart.map((p) => p.toJson()).toList()),
      );
    } catch (_) {
      // App remains functional without persistence; data will reset on restart.
    }
  }
}
