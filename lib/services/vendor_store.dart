import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/product.dart';
import '../models/vendor.dart';

/// Local vendor accounts, sessions, and product listings.
///
/// Vendors sign up on-device. Products they post are merged into the
/// marketplace alongside bundled catalog data.
class VendorStore extends ChangeNotifier {
  final List<Vendor> _vendors = [];
  final List<Product> _products = [];
  final Map<String, String> _pinsByVendorId = {};
  String? _sessionVendorId;

  List<Vendor> get registeredVendors => List.unmodifiable(_vendors);
  List<Product> get vendorProducts => List.unmodifiable(_products);
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
    } catch (_) {
      // Vendor portal remains usable with empty state.
    }
    notifyListeners();
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
  String? signUp({
    required String businessName,
    required String location,
    required String phone,
    required String pin,
    String whatsapp = '',
    String description = '',
  }) {
    final trimmedName = businessName.trim();
    final trimmedLocation = location.trim();
    final trimmedPhone = phone.trim();
    final trimmedPin = pin.trim();

    if (trimmedName.isEmpty) return 'Enter your business name.';
    if (trimmedLocation.isEmpty) return 'Enter your location.';
    if (trimmedPhone.isEmpty) return 'Enter your phone number.';
    if (trimmedPin.length < 4) return 'PIN must be at least 4 digits.';

    if (vendorByPhone(trimmedPhone) != null) {
      return 'A vendor with this phone number is already registered.';
    }

    final vendor = Vendor(
      id: 'vendor-${const Uuid().v4().substring(0, 8)}',
      name: trimmedName,
      location: trimmedLocation,
      description: description.trim(),
      phone: trimmedPhone,
      whatsapp: whatsapp.trim().isNotEmpty ? whatsapp.trim() : trimmedPhone,
    );

    _vendors.add(vendor);
    _pinsByVendorId[vendor.id] = trimmedPin;
    _sessionVendorId = vendor.id;
    notifyListeners();
    _persist();
    return null;
  }

  /// Sign in with phone + PIN. Returns null on success or an error message.
  String? signIn({required String phone, required String pin}) {
    final vendor = vendorByPhone(phone);
    if (vendor == null) return 'No vendor account found for this phone number.';
    if (_pinsByVendorId[vendor.id] != pin.trim()) {
      return 'Incorrect PIN. Please try again.';
    }

    _sessionVendorId = vendor.id;
    notifyListeners();
    _persist();
    return null;
  }

  void signOut() {
    _sessionVendorId = null;
    notifyListeners();
    _persist();
  }

  void updateProfile(Vendor updated) {
    final index = _vendors.indexWhere((v) => v.id == updated.id);
    if (index < 0) return;
    _vendors[index] = updated;
    notifyListeners();
    _persist();
  }

  Product addProduct({
    required String name,
    required String description,
    required String category,
    required int priceCents,
    required List<String> tags,
    bool inStock = true,
    bool canBuyOnline = false,
  }) {
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

    _products.add(product);
    notifyListeners();
    _persist();
    return product;
  }

  void updateProduct(Product product) {
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index < 0) return;
    _products[index] = product;
    notifyListeners();
    _persist();
  }

  void removeProduct(String productId) {
    _products.removeWhere((p) => p.id == productId);
    notifyListeners();
    _persist();
  }

  void toggleProductStock(String productId) {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index < 0) return;
    final product = _products[index];
    _products[index] = product.copyWith(inStock: !product.inStock);
    notifyListeners();
    _persist();
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
