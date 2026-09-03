import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/vendor.dart';

/// Loads vendor data from the bundled JSON asset.
class VendorCatalog {
  static Future<List<Vendor>> load() async {
    try {
      final source = await rootBundle.loadString('assets/vendors.json');
      final decoded = jsonDecode(source) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map((item) => Vendor.fromJson(Map<String, Object?>.from(item)))
          .toList();
    } catch (_) {
      return fallback;
    }
  }

  /// The single herbal vendor featured on the marketplace.
  static const fallback = <Vendor>[
    Vendor(
      id: 'vendor-01',
      name: 'Mama Rudo Herbs',
      location: 'Harare, Mbare',
      description:
          'Traditional herbal remedies sourced from local growers in Zimbabwe. '
          'Specialises in respiratory and digestive remedies.',
      phone: '+263 77 123 4567',
      whatsapp: '+263 77 123 4567',
      ecocashNumber: '+263 77 123 4567',
      rating: 4.8,
      reviewCount: 124,
    ),
  ];
}
