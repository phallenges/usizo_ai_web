import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/order.dart';
import '../models/product.dart';
import '../models/user_profile.dart';
import 'backend_api.dart';

class AppStore extends ChangeNotifier {
  AppStore({BackendApi? backendApi}) : _backendApi = backendApi ?? BackendApi();

  final BackendApi _backendApi;

  BackendApi get backendApi => _backendApi;
  UserProfile _profile = const UserProfile();
  bool _premium = false;
  int _checksUsed = 0;
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

  String get cartTotalLabel => '\$${(cartTotalCents / 100).toStringAsFixed(2)}';

  bool isInCart(String productId) => _cart.any((item) => item.id == productId);

  List<Order> get orders => List.unmodifiable(_orders);

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

    // Sync with backend when configured (non-blocking).
    unawaited(_syncWithBackend());
  }

  /// Pull latest state from the backend and merge with local data.
  Future<void> _syncWithBackend() async {
    try {
      final state = await _backendApi.fetchDeviceState();
      if (state == null) return;

      // Sync profile
      final profileData = state['profile'] as Map<String, dynamic>?;
      if (profileData != null) {
        _profile = UserProfile(
          name: profileData['name'] as String? ?? _profile.name,
          email: profileData['email'] as String? ?? _profile.email,
          allergies: profileData['allergies'] as String? ?? _profile.allergies,
          medicalConditions: profileData['medicalConditions'] as String? ??
              _profile.medicalConditions,
          currentMedications: profileData['currentMedications'] as String? ??
              _profile.currentMedications,
          emergencyContact: profileData['emergencyContact'] as String? ??
              _profile.emergencyContact,
        );
      }

      // Sync subscription
      final sub = state['subscription'] as Map<String, dynamic>?;
      if (sub != null) {
        _premium = sub['isPremium'] == true;
        _checksUsed = (sub['checksUsed'] as num?)?.toInt() ?? 0;
      }

      // Sync orders
      final ordersList = state['orders'] as List? ?? [];
      if (ordersList.isNotEmpty) {
        final backendOrders = ordersList
            .map((o) => Order.fromJson(Map<String, Object?>.from(o as Map)))
            .toList();
        // Merge: keep local orders not in backend, add/update backend orders
        final backendIds = {for (final o in backendOrders) o.id};
        final localOnly =
            _orders.where((o) => !backendIds.contains(o.id)).toList();
        _orders
          ..clear()
          ..addAll(backendOrders)
          ..addAll(localOnly);
      }

      notifyListeners();
      _persist();
    } catch (_) {
      // Sync failure is silent — local state remains valid.
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

  /// Activate Plus only after the server redeems a single-use payment token.
  Future<bool> activateWithToken(String token) async {
    try {
      final activated = await _backendApi.activateSubscription(token);
      if (!activated) return false;
      _premium = true;
      notifyListeners();
      unawaited(_persist());
      return true;
    } catch (_) {
      return false;
    }
  }

  bool recordCheck() {
    if (!canCheck) return false;
    if (!_premium) _checksUsed++;
    notifyListeners();
    _persist();
    // Also record on backend (non-blocking).
    unawaited(_recordCheckOnBackend());
    return true;
  }

  Future<void> _recordCheckOnBackend() async {
    try {
      final result = await _backendApi.recordCheck();
      if (result != null) {
        _premium = result['isPremium'] == true;
        _checksUsed = (result['checksUsed'] as num?)?.toInt() ?? _checksUsed;
        notifyListeners();
        _persist();
      }
    } catch (_) {}
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

      // Create order on backend (non-blocking).
      unawaited(_createOrderOnBackend(order));
    }

    _cart.clear();
    notifyListeners();
    _persist();
    return created;
  }

  Future<void> _createOrderOnBackend(Order order) async {
    try {
      final items = order.items
          .map((i) => {
                'productId': i.productId,
                'quantity': i.quantity,
              })
          .toList();
      final serverOrder = await _backendApi.createOrder(
        vendorId: order.vendorId,
        items: items,
        reference: order.reference,
      );
      if (serverOrder != null) {
        // Replace local order with server version (has correct ID and pricing).
        final index = _orders.indexWhere((o) => o.id == order.id);
        if (index >= 0) {
          _orders[index] = serverOrder;
          notifyListeners();
          _persist();
        }
      }
    } catch (_) {}
  }

  // ── Orders ────────────────────────────────────────────────────────

  void addOrder(Order order) {
    _orders.insert(0, order);
    notifyListeners();
    _persist();
  }

  /// Records the buyer's EcoCash confirmation image for vendor review.
  void submitPaymentProof(String orderId, String proofBase64) {
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index < 0 || proofBase64.isEmpty) return;
    _orders[index] = _orders[index].copyWith(
      status: OrderStatus.paymentProofSubmitted,
      paymentProofBase64: proofBase64,
      paymentRejectionReason: '',
    );
    notifyListeners();
    _persist();
  }

  /// Upload payment proof image to the backend (non-blocking).
  void submitPaymentProofToBackend(String orderId,
      {required String imagePath}) {
    unawaited(_uploadPaymentProof(orderId, imagePath));
  }

  Future<void> _uploadPaymentProof(String orderId, String imagePath) async {
    try {
      final serverOrder = await _backendApi.uploadPaymentProof(
        orderId: orderId,
        imageFile: File(imagePath),
      );
      if (serverOrder != null) {
        final index = _orders.indexWhere((o) => o.id == orderId);
        if (index >= 0) {
          _orders[index] = serverOrder;
          notifyListeners();
          _persist();
        }
      }
    } catch (_) {}
  }

  /// Vendor-only action in the local vendor dashboard.
  void reviewPaymentProof(String orderId,
      {required bool approved, String reason = ''}) {
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index < 0) return;
    _orders[index] = _orders[index].copyWith(
      status: approved ? OrderStatus.confirmed : OrderStatus.paymentRejected,
      paymentRejectionReason: approved ? '' : reason.trim(),
    );
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
