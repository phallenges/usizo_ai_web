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

  /// Placeholder vendors until real data is provided.
  static const fallback = <Vendor>[
    Vendor(
      id: 'vendor-01',
      name: 'Mama Rudo Herbs',
      location: 'Harare',
      description: 'Traditional herbal remedies sourced from local growers.',
      phone: '+263 77 000 0001',
      rating: 4.8,
      reviewCount: 124,
    ),
    Vendor(
      id: 'vendor-02',
      name: 'Zim Natural Wellness',
      location: 'Bulawayo',
      description: 'Organic herbs and natural health products.',
      phone: '+263 78 000 0002',
      rating: 4.5,
      reviewCount: 87,
    ),
    Vendor(
      id: 'vendor-03',
      name: 'Chiedza Herbalist',
      location: 'Chitungwiza',
      description: 'Certified traditional healer with 15+ years experience.',
      phone: '+263 71 000 0003',
      rating: 4.9,
      reviewCount: 203,
    ),
  ];
}
