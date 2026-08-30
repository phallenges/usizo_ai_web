class Remedy {
  const Remedy({
    required this.id,
    required this.name,
    required this.scientificName,
    required this.localNames,
    required this.category,
    required this.description,
    required this.usage,
    required this.preparation,
    required this.dosage,
    required this.warning,
    required this.evidenceSource,
    required this.studyUrl,
    required this.priceCents,
    required this.tags,
  });

  final String id;
  final String name;
  final String scientificName;
  final Map<String, String> localNames;
  final String category;
  final String description;
  final String usage;
  final String preparation;
  final String dosage;
  final String warning;
  final String evidenceSource;
  final String studyUrl;
  final int priceCents;
  final List<String> tags;

  String get priceLabel => '\$${(priceCents / 100).toStringAsFixed(2)}';

  factory Remedy.fromJson(Map<String, Object?> json) {
    final rawTags = json['tags'];
    return Remedy(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unnamed remedy',
      scientificName: json['scientificName'] as String? ?? '',
      localNames: (json['localNames'] is Map)
          ? Map<String, String>.from(
              (json['localNames'] as Map).map(
                (key, value) => MapEntry(key.toString(), value.toString()),
              ),
            )
          : const <String, String>{},
      category: json['category'] as String? ?? 'General wellness',
      description: json['description'] as String? ?? '',
      usage: json['usage'] as String? ?? '',
      preparation: json['preparation'] as String? ?? '',
      dosage: json['dosage'] as String? ?? '',
      warning: json['warning'] as String? ?? '',
      evidenceSource: json['evidenceSource'] as String? ?? '',
      studyUrl: json['studyUrl'] as String? ?? '',
      priceCents: (json['priceCents'] as num?)?.toInt() ?? 0,
      tags: rawTags is List
          ? rawTags.whereType<String>().toList()
          : const <String>[],
    );
  }
}
