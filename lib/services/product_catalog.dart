import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/product.dart';

/// Loads marketplace products from the bundled JSON asset.
class ProductCatalog {
  static Future<List<Product>> load() async {
    try {
      final source = await rootBundle.loadString('assets/products.json');
      final decoded = jsonDecode(source) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map((item) => Product.fromJson(Map<String, Object?>.from(item)))
          .toList();
    } catch (_) {
      return fallback;
    }
  }

  /// Placeholder products until real vendor data is provided.
  static const fallback = <Product>[
    Product(
      id: 'prod-01',
      name: 'Dried Moringa Leaves (100g)',
      vendorId: 'vendor-01',
      priceCents: 3100,
      description: 'Sun-dried Moringa oleifera leaves. Rich in vitamins and minerals.',
      category: 'Herbal remedy',
      tags: ['moringa', 'immunity', 'nutrition'],
    ),
    Product(
      id: 'prod-02',
      name: 'Zumbani Tea (50g)',
      vendorId: 'vendor-01',
      priceCents: 2500,
      description: 'Lippia javanica loose-leaf tea. Traditionally used for colds and flu.',
      category: 'Herbal tea',
      tags: ['zumbani', 'cold', 'flu', 'tea'],
    ),
    Product(
      id: 'prod-03',
      name: 'Neem Capsules (60ct)',
      vendorId: 'vendor-02',
      priceCents: 5500,
      description: 'Azadirachta indica capsules for skin and immune support.',
      category: 'Capsules',
      tags: ['neem', 'skin', 'immunity'],
    ),
    Product(
      id: 'prod-04',
      name: 'Ginger & Turmeric Mix (200g)',
      vendorId: 'vendor-02',
      priceCents: 4200,
      description: 'Fresh-ground ginger and turmeric blend. Anti-inflammatory properties.',
      category: 'Herbal blend',
      tags: ['ginger', 'turmeric', 'inflammation', 'digestive'],
    ),
    Product(
      id: 'prod-05',
      name: 'Aloe Vera Gel (250ml)',
      vendorId: 'vendor-03',
      priceCents: 3800,
      description: 'Pure aloe vera gel for skin soothing and wound healing.',
      category: 'Topical',
      tags: ['aloe', 'skin', 'burns', 'wound'],
    ),
    Product(
      id: 'prod-06',
      name: 'African Wormwood Bundle',
      vendorId: 'vendor-03',
      priceCents: 2800,
      description: 'Artemisia afra dried herb bundle. Traditional respiratory remedy.',
      category: 'Herbal remedy',
      tags: ['wormwood', 'respiratory', 'cough', 'cold'],
    ),
  ];
}
