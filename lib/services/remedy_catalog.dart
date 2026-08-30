import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/remedy.dart';

class RemedyCatalog {
  static Future<List<Remedy>> load() async {
    try {
      final source = await rootBundle.loadString('assets/remedies.json');
      final decoded = jsonDecode(source) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map((item) => Remedy.fromJson(Map<String, Object?>.from(item)))
          .toList();
    } catch (_) {
      return fallback;
    }
  }

  static const fallback = <Remedy>[
    Remedy(
      id: 'ginger-tea',
      name: 'Ginger & Lemon Tea',
      scientificName: 'Zingiber officinale',
      localNames: {'en': 'Ginger', 'sn': 'Chinamute', 'nd': 'Ginger'},
      category: 'Digestive comfort',
      description: 'A warming caffeine-free blend for occasional nausea.',
      usage: 'Steep one sachet in hot water for 5–10 minutes.',
      preparation: 'Slice fresh rhizome and steep in boiled water.',
      dosage: 'One cup once or twice daily.',
      warning: 'Ask a clinician if pregnant or taking blood thinners.',
      evidenceSource: 'WHO monograph on selected medicinal plants',
      studyUrl: 'https://www.who.int/publications/i/item/9241545372',
      priceCents: 4500,
      tags: ['nausea', 'cold', 'digestive'],
    ),
    Remedy(
      id: 'saline-spray',
      name: 'Saline Nasal Spray',
      scientificName: 'Sodium chloride',
      localNames: {'en': 'Saline', 'sn': 'Munyu', 'nd': 'Ityuwa'},
      category: 'Respiratory comfort',
      description: 'Gentle, non-medicated moisture for a blocked nose.',
      usage: 'Use as directed on the label when needed.',
      preparation: 'Use a sterile, commercially prepared product.',
      dosage: 'Follow the product label.',
      warning: 'Do not share the nozzle.',
      evidenceSource: 'Cochrane Library respiratory review',
      studyUrl: 'https://doi.org/10.1002/14651858.CD006821.pub3',
      priceCents: 5999,
      tags: ['congestion', 'cold', 'allergy'],
    ),
  ];
}
