import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/order.dart';
import '../models/product.dart';
import '../models/vendor.dart';
import 'backend_api.dart';

/// Vendor accounts, sessions, and product listings.
///
/// Vendors sign in through the backend API when configured,
/// falling back to on-device local accounts when offline.
class VendorStore extends ChangeNotifier {
  VendorStore({BackendApi? backendApi}) : _backendApi = backendApi;

  final BackendApi? _backendApi;
  final List<Vendor> _vendors = [];
  final List<Product> _products = [];
  final List<Order> _orders = [];
  final Map<String, String> _pinsByVendorId = {};
  String? _sessionVendorId;
  String? _backendToken;

  List<Vendor> get registeredVendors => List.unmodifiable(_vendors);
  List<Product> get vendorProducts => List.unmodifiable(_products);
  List<Order> get currentVendorOrders =>
      _orders.where((o) => o.vendorId == _sessionVendorId).toList();
  bool get isSignedIn => _sessionVendorId != null;

  Vendor? get currentVendor {
    final id = _sessionVendorId;
    if (id == null) return null;
    try {
      return _vendors.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Product> get currentVendorProducts =>
      _products.where((p) => p.vendorId == _sessionVendorId).toList();

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final vendorsJson = prefs.getString('vendor_accounts');
      if (vendorsJson != null) {
        final decoded = jsonDecode(vendorsJson) as List<dynamic>;
        _vendors
          ..clear()
          ..addAll(
            decoded.map(
              (item) => Vendor.fromJson(Map<String, Object?>.from(item as Map)),
            ),
          );
      }

      final productsJson = prefs.getString('vendor_products');
      if (productsJson != null) {
        final decoded = jsonDecode(productsJson) as List<dynamic>;
        _products
          ..clear()
          ..addAll(
            decoded.map(
              (item) =>
                  Product.fromJson(Map<String, Object?>.from(item as Map)),
            ),
          );
      }

      final pinsJson = prefs.getString('vendor_pins');
      if (pinsJson != null) {
        final decoded = Map<String, Object?>.from(jsonDecode(pinsJson) as Map);
        _pinsByVendorId
          ..clear()
          ..addAll(decoded.map((k, v) => MapEntry(k, v.toString())));
      }

      _sessionVendorId = prefs.getString('vendor_session');
      _backendToken = prefs.getString('vendor_backend_token');
    } catch (_) {
      // Vendor portal remains usable with empty state.
    }

    // Sync with backend if we have a token (non-blocking).
    if (_backendToken != null) {
      unawaited(_syncFromBackend());
    }
    notifyListeners();
  }

  /// Pull vendor profile and products from the backend.
  Future<void> _syncFromBackend() async {
    if (_backendApi == null || !_backendApi.isConfigured) return;
    try {
      final vendor = await _backendApi.fetchVendorProfile();
      if (vendor != null) {
        final index = _vendors.indexWhere((v) => v.id == vendor.id);
        if (index >= 0) {
          _vendors[index] = vendor;
        } else {
          _vendors.add(vendor);
        }
        _sessionVendorId = vendor.id;
      }
      final products = await _backendApi.fetchVendorProducts();
      if (products.isNotEmpty) {
        // Replace local products with server state.
        _products
          ..removeWhere((p) => p.vendorId == _sessionVendorId)
          ..addAll(products);
      }
      notifyListeners();
      unawaited(_persist());
    } catch (_) {}
  }

  static String normalizePhone(String phone) =>
      phone.replaceAll(RegExp(r'[^0-9+]'), '');

  Vendor? vendorByPhone(String phone) {
    final normalized = normalizePhone(phone);
    try {
      return _vendors.firstWhere(
        (v) => normalizePhone(v.phone) == normalized,
      );
    } catch (_) {
      return null;
    }
  }

  /// Register a new vendor account. Returns null on success or an error message.
  Future<String?> signUp({
    required String businessName,
    required String location,
    required String phone,
    required String ecocashNumber,
    required String pin,
    String whatsapp = '',
    String description = '',
  }) async {
    final trimmedName = businessName.trim();
    final trimmedLocation = location.trim();
    final trimmedPhone = phone.trim();
    final trimmedEcocashNumber = ecocashNumber.trim();
    final trimmedPin = pin.trim();

    if (trimmedName.isEmpty) return 'Enter your business name.';
    if (trimmedLocation.isEmpty) return 'Enter your location.';
    if (trimmedPhone.isEmpty) return 'Enter your phone number.';
    if (trimmedEcocashNumber.isEmpty) return 'Enter your EcoCash number.';
    if (trimmedPin.length < 4) return 'PIN must be at least 4 digits.';

    // Try backend API first.
    if (_backendApi != null && _backendApi.isConfigured) {
      final token = await _backendApi.vendorRegister(
        businessName: trimmedName,
        location: trimmedLocation,
        phone: trimmedPhone,
        ecocashNumber: trimmedEcocashNumber,
        pin: trimmedPin,
        whatsapp: whatsapp,
        description: description,
      );
      if (token != null) {
        _backendToken = token;
        final vendor = await _backendApi.fetchVendorProfile();
        if (vendor != null) {
          _vendors.add(vendor);
          _sessionVendorId = vendor.id;
          unawaited(_persist());
          _saveBackendToken();
          notifyListeners();
          return null;
        }
      }
    }

    // Fallback: local registration.
    if (vendorByPhone(trimmedPhone) != null) {
      return 'A vendor with this phone number is already registered.';
    }

    final vendor = Vendor(
      id: 'vendor-${const Uuid().v4().substring(0, 8)}',
      name: trimmedName,
      location: trimmedLocation,
      description: description.trim(),
      phone: trimmedPhone,
      ecocashNumber: trimmedEcocashNumber,
      whatsapp: whatsapp.trim().isNotEmpty ? whatsapp.trim() : trimmedPhone,
    );

    _vendors.add(vendor);
    _pinsByVendorId[vendor.id] = trimmedPin;
    _sessionVendorId = vendor.id;
    notifyListeners();
    unawaited(_persist());
    return null;
  }

  /// Sign in with phone + PIN. Returns null on success or an error message.
  Future<String?> signIn({required String phone, required String pin}) async {
    // Try backend API first.
    if (_backendApi != null && _backendApi.isConfigured) {
      final token = await _backendApi.vendorLogin(phone: phone, pin: pin);
      if (token != null) {
        _backendToken = token;
        final vendor = await _backendApi.fetchVendorProfile();
        if (vendor != null) {
          final index = _vendors.indexWhere((v) => v.id == vendor.id);
          if (index >= 0) {
            _vendors[index] = vendor;
          } else {
            _vendors.add(vendor);
          }
          _sessionVendorId = vendor.id;
          _saveBackendToken();
          notifyListeners();
          unawaited(_persist());
          // Fetch products from backend.
          unawaited(_syncFromBackend());
          return null;
        }
      }
    }

    // Fallback: local sign-in.
    final vendor = vendorByPhone(phone);
    if (vendor == null) return 'No vendor account found for this phone number.';
    if (_pinsByVendorId[vendor.id] != pin.trim()) {
      return 'Incorrect PIN. Please try again.';
    }

    _sessionVendorId = vendor.id;
    notifyListeners();
    unawaited(_persist());
    return null;
  }

  void signOut() {
    _sessionVendorId = null;
    _backendToken = null;
    _backendApi?.vendorSignOut();
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> _saveBackendToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_backendToken != null) {
        await prefs.setString('vendor_backend_token', _backendToken!);
      } else {
        await prefs.remove('vendor_backend_token');
      }
    } catch (_) {}
  }

  Future<void> updateProfile(Vendor updated) async {
    final index = _vendors.indexWhere((v) => v.id == updated.id);
    if (index < 0) return;
    if (_backendApi != null &&
        _backendApi.isConfigured &&
        _backendToken != null) {
      final serverVendor = await _backendApi.updateVendorProfile(
        name: updated.name,
        location: updated.location,
        description: updated.description,
        phone: updated.phone,
        ecocashNumber: updated.ecocashNumber,
        whatsapp: updated.whatsapp,
      );
      if (serverVendor == null) return;
      updated = serverVendor;
    }
    _vendors[index] = updated;
    notifyListeners();
    unawaited(_persist());
  }

  Future<Product> addProduct({
    required String name,
    required String description,
    required String category,
    required int priceCents,
    required List<String> tags,
    bool inStock = true,
    bool canBuyOnline = false,
  }) async {
    final vendorId = _sessionVendorId;
    if (vendorId == null) {
      throw StateError('No vendor signed in');
    }

    final product = Product(
      id: 'prod-${const Uuid().v4().substring(0, 8)}',
      name: name.trim(),
      vendorId: vendorId,
      priceCents: priceCents,
      description: description.trim(),
      category: category.trim(),
      tags: tags,
      inStock: inStock,
      canBuyOnline: canBuyOnline,
    );

    if (_backendApi != null &&
        _backendApi.isConfigured &&
        _backendToken != null) {
      final serverProduct = await _backendApi.createVendorProduct(
        name: product.name,
        description: product.description,
        category: product.category,
        priceCents: product.priceCents,
        tags: product.tags,
        inStock: product.inStock,
        canBuyOnline: product.canBuyOnline,
      );
      if (serverProduct == null) return product;
      _products.add(serverProduct);
      notifyListeners();
      unawaited(_persist());
      return serverProduct;
    }
    _products.add(product);
    notifyListeners();
    unawaited(_persist());
    return product;
  }

  Future<void> updateProduct(Product product) async {
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index < 0) return;
    if (_backendApi != null &&
        _backendApi.isConfigured &&
        _backendToken != null) {
      final serverProduct = await _backendApi.updateVendorProduct(product);
      if (serverProduct == null) return;
      product = serverProduct;
    }
    _products[index] = product;
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> removeProduct(String productId) async {
    if (_backendApi != null &&
        _backendApi.isConfigured &&
        _backendToken != null) {
      final deleted = await _backendApi.deleteVendorProduct(productId);
      if (!deleted) return;
    }
    _products.removeWhere((p) => p.id == productId);
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> toggleProductStock(String productId) async {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index < 0) return;
    final product = _products[index];
    final updated = product.copyWith(inStock: !product.inStock);
    if (_backendApi != null &&
        _backendApi.isConfigured &&
        _backendToken != null) {
      final serverProduct = await _backendApi.updateVendorProduct(updated);
      if (serverProduct == null) return;
      _products[index] = serverProduct;
    } else {
      _products[index] = updated;
    }
    notifyListeners();
    unawaited(_persist());
  }

  // ── Orders ───────────────────────────────────────────────────────

  /// Fetch orders from the backend for the signed-in vendor.
  Future<void> fetchOrders() async {
    if (_backendApi == null || !_backendApi.isConfigured) return;
    try {
      final orders = await _backendApi.fetchVendorOrders();
      // Replace local orders with server state.
      final vendorOrders =
          orders.where((o) => o.vendorId == _sessionVendorId).toList();
      final nonVendorOrders =
          _orders.where((o) => o.vendorId != _sessionVendorId).toList();
      _orders
        ..clear()
        ..addAll(nonVendorOrders)
        ..addAll(vendorOrders);
      notifyListeners();
    } catch (_) {}
  }

  /// Confirm an order with vendor details (final price, delivery, instructions).
  Future<bool> confirmOrder({
    required String orderId,
    required int finalPriceCents,
    required String deliveryMethod,
    String deliveryArea = '',
    String collectionPoint = '',
    String turnaroundTime = '',
    String paymentInstructions = '',
    String deliveryInstructions = '',
  }) async {
    if (_backendApi == null || !_backendApi.isConfigured) return false;
    try {
      final token = await _backendApi.getVendorToken();
      if (token == null) return false;
      final r = await _backendApi.confirmOrder(
        orderId: orderId,
        action: 'confirm',
        finalPriceCents: finalPriceCents,
        deliveryMethod: deliveryMethod,
        deliveryArea: deliveryArea,
        collectionPoint: collectionPoint,
        turnaroundTime: turnaroundTime,
        paymentInstructions: paymentInstructions,
        deliveryInstructions: deliveryInstructions,
      );
      if (r != null) {
        // Update local order.
        final index = _orders.indexWhere((o) => o.id == orderId);
        if (index >= 0) {
          _orders[index] = r;
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Decline an order with a reason.
  Future<bool> declineOrder({
    required String orderId,
    required String reason,
  }) async {
    if (_backendApi == null || !_backendApi.isConfigured) return false;
    try {
      final r = await _backendApi.confirmOrder(
        orderId: orderId,
        action: 'decline',
        declineReason: reason,
      );
      if (r != null) {
        final index = _orders.indexWhere((o) => o.id == orderId);
        if (index >= 0) {
          _orders[index] = r;
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'vendor_accounts',
        jsonEncode(_vendors.map((v) => v.toJson()).toList()),
      );
      await prefs.setString(
        'vendor_products',
        jsonEncode(_products.map((p) => p.toJson()).toList()),
      );
      await prefs.setString('vendor_pins', jsonEncode(_pinsByVendorId));
      if (_sessionVendorId != null) {
        await prefs.setString('vendor_session', _sessionVendorId!);
      } else {
        await prefs.remove('vendor_session');
      }
    } catch (_) {
      // Data remains in memory for the current session.
    }
  }
}
