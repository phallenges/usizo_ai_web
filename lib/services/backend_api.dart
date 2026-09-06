import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/order.dart';
import '../models/product.dart';
import '../models/user_profile.dart';
import '../models/vendor.dart';

/// Authenticated-device API surface used by the customer app.
///
/// The API origin is supplied at build time so no development
/// endpoint or secret is shipped in a release binary.
///
/// When the API is unavailable (offline, not configured), callers
/// fall back to local/bundled data.
class BackendApi {
  BackendApi({http.Client? client}) : _client = client ?? http.Client();

  static const _baseUrl = String.fromEnvironment('USIZO_API_BASE_URL');
  static const _deviceIdKey = 'api_device_id';
  static const _vendorTokenKey = 'api_vendor_token';
  static const _vendorIdKey = 'api_vendor_id';
  final http.Client _client;

  bool get isConfigured => _baseUrl.isNotEmpty;

  // ── Device identity ──────────────────────────────────────────────

  Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = const Uuid().v4();
    await prefs.setString(_deviceIdKey, id);
    return id;
  }

  Future<void> _ensureRegistered() async {
    if (!isConfigured) return;
    final id = await deviceId();
    try {
      await _client
          .post(
            Uri.parse('$_baseUrl/api/devices/register'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'deviceId': id}),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Offline or server down — continue with local state.
    }
  }

  // ── Catalog ──────────────────────────────────────────────────────

  Future<List<Vendor>> fetchVendors() async {
    if (!isConfigured) return [];
    try {
      final r = await _client
          .get(Uri.parse('$_baseUrl/api/catalog/vendors'))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return [];
      final data = jsonDecode(r.body) as Map;
      final list = data['vendors'] as List? ?? [];
      return list
          .map((v) => Vendor.fromJson(Map<String, Object?>.from(v as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Product>> fetchProducts({String? vendorId}) async {
    if (!isConfigured) return [];
    try {
      var url = '$_baseUrl/api/catalog/products';
      if (vendorId != null) url += '?vendorId=$vendorId';
      final r = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return [];
      final data = jsonDecode(r.body) as Map;
      final list = data['products'] as List? ?? [];
      return list
          .map((p) => Product.fromJson(Map<String, Object?>.from(p as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Device state (profile, subscription, orders) ─────────────────

  Future<Map<String, dynamic>?> fetchDeviceState() async {
    if (!isConfigured) return null;
    await _ensureRegistered();
    final id = await deviceId();
    try {
      final r = await _client
          .get(Uri.parse('$_baseUrl/api/devices/$id/state'))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateProfile(UserProfile profile) async {
    if (!isConfigured) return false;
    await _ensureRegistered();
    final id = await deviceId();
    try {
      final r = await _client
          .put(
            Uri.parse('$_baseUrl/api/devices/$id/profile'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': profile.name,
              'email': profile.email,
              'allergies': profile.allergies,
              'emergencyContact': profile.emergencyContact,
            }),
          )
          .timeout(const Duration(seconds: 10));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Symptom check ────────────────────────────────────────────────

  Future<Map<String, dynamic>?> recordCheck() async {
    if (!isConfigured) return null;
    await _ensureRegistered();
    final id = await deviceId();
    try {
      final r = await _client
          .post(Uri.parse('$_baseUrl/api/devices/$id/check'))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ── Subscription activation ──────────────────────────────────────

  Future<bool> activateSubscription(String token) async {
    if (!isConfigured || token.trim().isEmpty) return false;
    await _ensureRegistered();
    final id = await deviceId();
    try {
      final r = await _client
          .post(
            Uri.parse('$_baseUrl/api/devices/$id/subscriptions/activate'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'token': token.trim()}),
          )
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return false;
      final body = jsonDecode(r.body);
      return body is Map && body['isPremium'] == true;
    } catch (_) {
      return false;
    }
  }

  // ── Orders ───────────────────────────────────────────────────────

  Future<Order?> createOrder({
    required String vendorId,
    required List<Map<String, dynamic>> items,
    String? reference,
  }) async {
    if (!isConfigured) return null;
    await _ensureRegistered();
    final id = await deviceId();
    try {
      final r = await _client
          .post(
            Uri.parse('$_baseUrl/api/devices/$id/orders'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'vendorId': vendorId,
              'items': items,
              if (reference != null) 'reference': reference,
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return null;
      final data = jsonDecode(r.body) as Map;
      final orderData = data['order'] as Map?;
      if (orderData == null) return null;
      return Order.fromJson(Map<String, Object?>.from(orderData));
    } catch (_) {
      return null;
    }
  }

  Future<Order?> uploadPaymentProof({
    required String orderId,
    required File imageFile,
  }) async {
    if (!isConfigured) return null;
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/orders/$orderId/payment-proof'),
      );
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );
      final streamed = await _client.send(request).timeout(
            const Duration(seconds: 30),
          );
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map;
      final orderData = data['order'] as Map?;
      if (orderData == null) return null;
      return Order.fromJson(Map<String, Object?>.from(orderData));
    } catch (_) {
      return null;
    }
  }

  // ── Vendor auth ──────────────────────────────────────────────────

  Future<String?> vendorLogin({
    required String phone,
    required String pin,
  }) async {
    if (!isConfigured) return null;
    try {
      final r = await _client
          .post(
            Uri.parse('$_baseUrl/api/vendors/login'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'phone': phone, 'pin': pin}),
          )
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      final data = jsonDecode(r.body) as Map;
      final token = data['token'] as String?;
      if (token == null) return null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_vendorTokenKey, token);
      final vendor = data['vendor'] as Map?;
      if (vendor != null) {
        await prefs.setString(_vendorIdKey, vendor['id'] as String);
      }
      return token;
    } catch (_) {
      return null;
    }
  }

  Future<String?> vendorRegister({
    required String businessName,
    required String location,
    required String phone,
    required String ecocashNumber,
    required String pin,
    String whatsapp = '',
    String description = '',
  }) async {
    if (!isConfigured) return null;
    try {
      final r = await _client
          .post(
            Uri.parse('$_baseUrl/api/vendors/register'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'businessName': businessName,
              'location': location,
              'phone': phone,
              'ecocashNumber': ecocashNumber,
              'pin': pin,
              'whatsapp': whatsapp,
              'description': description,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      final data = jsonDecode(r.body) as Map;
      final token = data['token'] as String?;
      if (token == null) return null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_vendorTokenKey, token);
      final vendor = data['vendor'] as Map?;
      if (vendor != null) {
        await prefs.setString(_vendorIdKey, vendor['id'] as String);
      }
      return token;
    } catch (_) {
      return null;
    }
  }

  Future<String?> getVendorToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_vendorTokenKey);
  }

  Future<String?> getVendorId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_vendorIdKey);
  }

  Future<void> vendorSignOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_vendorTokenKey);
    await prefs.remove(_vendorIdKey);
  }

  Future<Vendor?> fetchVendorProfile() async {
    final token = await getVendorToken();
    if (!isConfigured || token == null) return null;
    try {
      final r = await _client.get(
        Uri.parse('$_baseUrl/api/vendors/me'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      final data = jsonDecode(r.body) as Map;
      final v = data['vendor'] as Map?;
      if (v == null) return null;
      return Vendor.fromJson(Map<String, Object?>.from(v));
    } catch (_) {
      return null;
    }
  }

  Future<List<Product>> fetchVendorProducts() async {
    final token = await getVendorToken();
    if (!isConfigured || token == null) return [];
    try {
      final r = await _client.get(
        Uri.parse('$_baseUrl/api/vendors/me/products'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return [];
      final data = jsonDecode(r.body) as Map;
      final list = data['products'] as List? ?? [];
      return list
          .map((p) => Product.fromJson(Map<String, Object?>.from(p as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<Vendor?> updateVendorProfile({
    required String name,
    required String location,
    required String description,
    required String phone,
    required String ecocashNumber,
    required String whatsapp,
  }) async {
    final token = await getVendorToken();
    if (!isConfigured || token == null) return null;
    try {
      final r = await _client
          .patch(
            Uri.parse('$_baseUrl/api/vendors/me'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': '******',
            },
            body: jsonEncode({
              'name': name,
              'location': location,
              'description': description,
              'phone': phone,
              'ecocashNumber': ecocashNumber,
              'whatsapp': whatsapp,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      final data = jsonDecode(r.body) as Map;
      final vendor = data['vendor'] as Map?;
      return vendor == null
          ? null
          : Vendor.fromJson(Map<String, Object?>.from(vendor));
    } catch (_) {
      return null;
    }
  }

  Future<Product?> createVendorProduct({
    required String name,
    required String description,
    required String category,
    required int priceCents,
    required List<String> tags,
    required bool inStock,
    required bool canBuyOnline,
  }) async {
    final token = await getVendorToken();
    if (!isConfigured || token == null) return null;
    try {
      final r = await _client
          .post(
            Uri.parse('$_baseUrl/api/vendors/me/products'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': '******',
            },
            body: jsonEncode({
              'name': name,
              'description': description,
              'category': category,
              'priceCents': priceCents,
              'tags': tags,
              'inStock': inStock,
              'canBuyOnline': canBuyOnline,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      final data = jsonDecode(r.body) as Map;
      final product = data['product'] as Map?;
      return product == null
          ? null
          : Product.fromJson(Map<String, Object?>.from(product));
    } catch (_) {
      return null;
    }
  }

  Future<Product?> updateVendorProduct(Product product) async {
    final token = await getVendorToken();
    if (!isConfigured || token == null) return null;
    try {
      final r = await _client
          .patch(
            Uri.parse('$_baseUrl/api/vendors/me/products/${product.id}'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': '******',
            },
            body: jsonEncode({
              'name': product.name,
              'description': product.description,
              'category': product.category,
              'priceCents': product.priceCents,
              'tags': product.tags,
              'inStock': product.inStock,
              'canBuyOnline': product.canBuyOnline,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      final data = jsonDecode(r.body) as Map;
      final updated = data['product'] as Map?;
      return updated == null
          ? null
          : Product.fromJson(Map<String, Object?>.from(updated));
    } catch (_) {
      return null;
    }
  }

  Future<bool> deleteVendorProduct(String productId) async {
    final token = await getVendorToken();
    if (!isConfigured || token == null) return false;
    try {
      final r = await _client.delete(
        Uri.parse('$_baseUrl/api/vendors/me/products/$productId'),
        headers: {'Authorization': '******'},
      ).timeout(const Duration(seconds: 10));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Order?> vendorCreateOrder({
    required String vendorId,
    required List<Map<String, dynamic>> items,
    String? reference,
  }) async {
    // Vendor creates order on behalf of customer (server-side).
    // For now, the customer app creates orders directly.
    return createOrder(vendorId: vendorId, items: items, reference: reference);
  }

  Future<List<Order>> fetchVendorOrders() async {
    final token = await getVendorToken();
    if (!isConfigured || token == null) return [];
    try {
      final r = await _client.get(
        Uri.parse('$_baseUrl/api/vendors/me/orders'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return [];
      final data = jsonDecode(r.body) as Map;
      final list = data['orders'] as List? ?? [];
      return list
          .map((o) => Order.fromJson(Map<String, Object?>.from(o as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Vendor order confirmation ────────────────────────────────────

  Future<Order?> confirmOrder({
    required String orderId,
    required String action,
    int? finalPriceCents,
    String deliveryMethod = '',
    String deliveryArea = '',
    String collectionPoint = '',
    String turnaroundTime = '',
    String paymentInstructions = '',
    String deliveryInstructions = '',
    String declineReason = '',
  }) async {
    final token = await getVendorToken();
    if (!isConfigured || token == null) return null;
    try {
      final r = await _client
          .post(
            Uri.parse('$_baseUrl/api/vendors/me/orders/$orderId/confirm'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'action': action,
              'finalPriceCents': finalPriceCents,
              'deliveryMethod': deliveryMethod,
              'deliveryArea': deliveryArea,
              'collectionPoint': collectionPoint,
              'turnaroundTime': turnaroundTime,
              'paymentInstructions': paymentInstructions,
              'deliveryInstructions': deliveryInstructions,
              'declineReason': declineReason,
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return null;
      final data = jsonDecode(r.body) as Map;
      final orderData = data['order'] as Map?;
      if (orderData == null) return null;
      return Order.fromJson(Map<String, Object?>.from(orderData));
    } catch (_) {
      return null;
    }
  }
}
