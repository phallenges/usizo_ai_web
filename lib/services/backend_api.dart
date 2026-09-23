import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/order.dart';
import '../models/product.dart';
import '../models/remedy.dart';
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

  static const _maxAttempts = 3;
  static const _requestTimeout = Duration(seconds: 10);
  static const _baseUrl = String.fromEnvironment(
    'USIZO_API_BASE_URL',
    defaultValue: 'https://usizoai.onrender.com',
  );
  static const _deviceIdKey = 'api_device_id';
  static const _deviceTokenKey = 'api_device_token';
  static const _vendorTokenKey = 'api_vendor_token';
  static const _vendorIdKey = 'api_vendor_id';
  static const _accountTokenKey = 'api_account_token';
  final http.Client _client;

  bool get isConfigured => _baseUrl.isNotEmpty;

  Future<String?> _accountToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accountTokenKey);
  }

  Future<bool> hasAccount() async => (await _accountToken()) != null;

  // ── App updates ──────────────────────────────────────────────────

  /// Ask the backend which Android release is published for [currentVersion].
  ///
  /// Returns null when the API is unconfigured, unreachable, or from an older
  /// backend that has no version endpoint.
  Future<Map<String, dynamic>?> fetchAppVersion({
    required String currentVersion,
  }) async {
    if (!isConfigured) return null;
    try {
      final uri = Uri.parse('$_baseUrl/api/app/version').replace(
        queryParameters: {'currentVersion': currentVersion},
      );
      final r = await _request(
        () => _client.get(uri),
        timeout: const Duration(seconds: 8),
      );
      if (r.statusCode != 200) return null;
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> registerAccount({
    required String name,
    required String password,
    String? email,
    String? phone,
    String allergies = '',
    String emergencyContact = '',
  }) async {
    if (!isConfigured) return null;
    try {
      final response = await _request(
        () => _client.post(
          Uri.parse('$_baseUrl/api/auth/register'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': name.trim(),
            'password': password,
            if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
            if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
            'allergies': allergies.trim(),
            'emergencyContact': emergencyContact.trim(),
          }),
        ),
      );
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = data['token'] as String?;
      if (token == null) return null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accountTokenKey, token);
      return data['account'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> loginAccount({
    required String identifier,
    required String password,
  }) async {
    if (!isConfigured) return null;
    try {
      final response = await _request(
        () => _client.post(
          Uri.parse('$_baseUrl/api/auth/login'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'identifier': identifier.trim(),
            'password': password,
          }),
        ),
      );
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = data['token'] as String?;
      if (token == null) return null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accountTokenKey, token);
      return data['account'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<void> signOutAccount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accountTokenKey);
  }

  Future<http.Response> _request(
    Future<http.Response> Function() operation, {
    Duration timeout = _requestTimeout,
  }) async {
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final response = await operation().timeout(timeout);
        if (!_shouldRetry(response.statusCode) || attempt == _maxAttempts) {
          return response;
        }
      } on SocketException {
        if (attempt == _maxAttempts) rethrow;
      } on TimeoutException {
        if (attempt == _maxAttempts) rethrow;
      }

      await Future<void>.delayed(
        Duration(milliseconds: 300 * (1 << (attempt - 1))),
      );
    }
    throw StateError('Request retry loop exited unexpectedly.');
  }

  bool _shouldRetry(int statusCode) =>
      statusCode == 408 ||
      statusCode == 429 ||
      statusCode == 500 ||
      statusCode == 502 ||
      statusCode == 503 ||
      statusCode == 504;

  Future<http.Response> _upload(File file, Uri uri) async {
    final bytes = await file.readAsBytes();
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final request = http.MultipartRequest('POST', uri);
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: file.uri.pathSegments.last,
          ),
        );
        final streamed = await _client.send(request).timeout(
              const Duration(seconds: 30),
            );
        final response = await http.Response.fromStream(streamed);
        if (!_shouldRetry(response.statusCode) || attempt == _maxAttempts) {
          return response;
        }
      } on SocketException {
        if (attempt == _maxAttempts) rethrow;
      } on TimeoutException {
        if (attempt == _maxAttempts) rethrow;
      }
      await Future<void>.delayed(
        Duration(milliseconds: 300 * (1 << (attempt - 1))),
      );
    }
    throw StateError('Upload retry loop exited unexpectedly.');
  }

  // ── Device identity ──────────────────────────────────────────────

  Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = const Uuid().v4();
    await prefs.setString(_deviceIdKey, id);
    return id;
  }

  Future<String?> deviceToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_deviceTokenKey);
  }

  /// Headers for device-scoped calls: the device token is the credential.
  /// The id in the URL alone proves nothing — ids leak through order data.
  Future<Map<String, String>> _deviceHeaders({bool json = false}) async {
    final token = await deviceToken();
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'X-Device-Token': token,
    };
  }

  /// Single-flight guard so concurrent screen calls cannot race the first
  /// registration for the same identity.
  Future<void>? _registerInFlight;

  Future<void> _ensureRegistered() {
    if (!isConfigured) return Future<void>.value();
    return _registerInFlight ??= _registerDevice().whenComplete(() {
      _registerInFlight = null;
    });
  }

  Future<void> _registerDevice() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdKey) ?? '';
    var storedToken = prefs.getString(_deviceTokenKey);
    final accountToken = await _accountToken();

    var response = await _postRegister(
      deviceId: id,
      deviceToken: storedToken,
      accountToken: accountToken,
    );
    if (response.statusCode == 401 || response.statusCode == 403) {
      // The stored identity predates device tokens or was rejected —
      // drop it and mint a fresh one on the next request.
      await prefs.remove(_deviceIdKey);
      await prefs.remove(_deviceTokenKey);
      id = '';
      storedToken = null;
      response = await _postRegister(
        deviceId: '',
        deviceToken: null,
        accountToken: accountToken,
      );
    }
    if (response.statusCode != 200) return;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final newId = data['deviceId'] as String?;
    final newToken = data['deviceToken'] as String?;
    if (newId != null && newId.isNotEmpty) {
      await prefs.setString(_deviceIdKey, newId);
    }
    if (newToken != null && newToken.isNotEmpty) {
      await prefs.setString(_deviceTokenKey, newToken);
    }
  }

  Future<http.Response> _postRegister({
    required String deviceId,
    required String? deviceToken,
    required String? accountToken,
  }) {
    return _request(
      () => _client.post(
        Uri.parse('$_baseUrl/api/devices/register'),
        headers: {
          'Content-Type': 'application/json',
          if (accountToken != null) 'Authorization': 'Bearer $accountToken',
          if (deviceToken != null && deviceToken.isNotEmpty)
            'X-Device-Token': deviceToken,
        },
        body: jsonEncode({
          if (deviceId.isNotEmpty) 'deviceId': deviceId,
        }),
      ),
      timeout: const Duration(seconds: 8),
    );
  }

  // ── Catalog ──────────────────────────────────────────────────────

  Future<List<Vendor>> fetchVendors() async {
    if (!isConfigured) return [];
    try {
      final r = await _request(
        () => _client.get(Uri.parse('$_baseUrl/api/catalog/vendors')),
      );
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
      final r = await _request(() => _client.get(Uri.parse(url)));
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

  Future<List<Remedy>> fetchApprovedRemedies() async {
    if (!isConfigured) return [];
    try {
      final r = await _request(
        () => _client.get(Uri.parse('$_baseUrl/api/catalog/remedies')),
        timeout: const Duration(seconds: 5),
      );
      if (r.statusCode != 200) return [];
      final data = jsonDecode(r.body) as Map;
      final list = data['remedies'] as List? ?? [];
      return list
          .map(
            (item) => Remedy.fromJson(Map<String, Object?>.from(item as Map)),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> submitRemedy({
    required String name,
    required String scientificName,
    required String category,
    required String description,
    required String usage,
    required String preparation,
    required String dosage,
    required String warning,
    required String evidenceSource,
    String studyUrl = '',
    List<String> tags = const [],
  }) async {
    if (!isConfigured) return false;
    await _ensureRegistered();
    final id = await deviceId();
    try {
      final response = await _request(
        () => _client.post(
          Uri.parse('$_baseUrl/api/remedy-submissions'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'deviceId': id,
            'name': name.trim(),
            'scientificName': scientificName.trim(),
            'category': category.trim(),
            'description': description.trim(),
            'usage': usage.trim(),
            'preparation': preparation.trim(),
            'dosage': dosage.trim(),
            'warning': warning.trim(),
            'evidenceSource': evidenceSource.trim(),
            'studyUrl': studyUrl.trim(),
            'tags': tags
                .map((tag) => tag.trim())
                .where((tag) => tag.isNotEmpty)
                .toList(),
          }),
        ),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Device state (profile, subscription, orders) ─────────────────

  Future<Map<String, dynamic>?> fetchDeviceState() async {
    if (!isConfigured) return null;
    await _ensureRegistered();
    final id = await deviceId();
    try {
      final headers = await _deviceHeaders();
      final r = await _request(
        () => _client.get(
          Uri.parse('$_baseUrl/api/devices/$id/state'),
          headers: headers,
        ),
      );
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
      final headers = await _deviceHeaders(json: true);
      final r = await _request(
        () => _client.put(
          Uri.parse('$_baseUrl/api/devices/$id/profile'),
          headers: headers,
          body: jsonEncode({
            'name': profile.name,
            'email': profile.email,
            'allergies': profile.allergies,
            'medicalConditions': profile.medicalConditions,
            'currentMedications': profile.currentMedications,
            'emergencyContact': profile.emergencyContact,
          }),
        ),
      );
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
      final headers = await _deviceHeaders();
      final r = await _request(
        () => _client.post(
          Uri.parse('$_baseUrl/api/devices/$id/check'),
          headers: headers,
        ),
      );
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
      final headers = await _deviceHeaders(json: true);
      final r = await _request(
        () => _client.post(
          Uri.parse('$_baseUrl/api/devices/$id/subscriptions/activate'),
          headers: headers,
          body: jsonEncode({'token': token.trim()}),
        ),
        timeout: const Duration(seconds: 12),
      );
      if (r.statusCode != 200) return false;
      final body = jsonDecode(r.body);
      return body is Map && body['isPremium'] == true;
    } catch (_) {
      return false;
    }

  }

  Future<bool> submitPlusPayment({
    required String merchantReference,
    required String confirmationMessage,
    required String deliveryEmail,
  }) async {
    if (!isConfigured) return false;
    await _ensureRegistered();
    final id = await deviceId();
    final token = await _accountToken();
    try {
      final headers = await _deviceHeaders(json: true);
      if (token != null) headers['Authorization'] = 'Bearer $token';
      final r = await _request(
        () => _client.post(
          Uri.parse('$_baseUrl/api/devices/$id/plus-payment-submissions'),
          headers: headers,
          body: jsonEncode({
            'merchantReference': merchantReference.trim(),
            'confirmationMessage': confirmationMessage.trim(),
            'deliveryEmail': deliveryEmail.trim(),
          }),
        ),
      );
      return r.statusCode == 200;
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
      final headers = await _deviceHeaders(json: true);
      final r = await _request(
        () => _client.post(
          Uri.parse('$_baseUrl/api/devices/$id/orders'),
          headers: headers,
          body: jsonEncode({
            'vendorId': vendorId,
            'items': items,
            if (reference != null) 'reference': reference,
          }),
        ),
        timeout: const Duration(seconds: 12),
      );
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
      final response = await _upload(
        imageFile,
        Uri.parse('$_baseUrl/api/orders/$orderId/payment-proof'),
      );
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
      final r = await _request(
        () => _client.post(
          Uri.parse('$_baseUrl/api/vendors/login'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'phone': phone, 'pin': pin}),
        ),
      );
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
      final r = await _request(
        () => _client.post(
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
        ),
      );
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
      final r = await _request(
        () => _client.get(
          Uri.parse('$_baseUrl/api/vendors/me'),
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
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
      final r = await _request(
        () => _client.get(
          Uri.parse('$_baseUrl/api/vendors/me/products'),
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
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
      final r = await _request(
        () => _client.patch(
          Uri.parse('$_baseUrl/api/vendors/me'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'name': name,
            'location': location,
            'description': description,
            'phone': phone,
            'ecocashNumber': ecocashNumber,
            'whatsapp': whatsapp,
          }),
        ),
      );
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
      final r = await _request(
        () => _client.post(
          Uri.parse('$_baseUrl/api/vendors/me/products'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
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
        ),
      );
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
      final r = await _request(
        () => _client.patch(
          Uri.parse('$_baseUrl/api/vendors/me/products/${product.id}'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
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
        ),
      );
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
      final r = await _request(
        () => _client.delete(
          Uri.parse('$_baseUrl/api/vendors/me/products/$productId'),
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
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
      final r = await _request(
        () => _client.get(
          Uri.parse('$_baseUrl/api/vendors/me/orders'),
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
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
      final r = await _request(
        () => _client.post(
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
        ),
        timeout: const Duration(seconds: 12),
      );
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
