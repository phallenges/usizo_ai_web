/// A product listed in the wellness marketplace for sale.
///
/// Different from Remedy — remedies are health guidance content,
/// while products are actual items users can buy from a vendor.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.vendorId,
    required this.priceCents,
    this.description = '',
    this.category = 'Herbal remedy',
    this.tags = const [],
    this.imageAsset,
    this.inStock = true,
    this.canBuyOnline = false,
  });

  final String id;
  final String name;
  final String vendorId;
  final int priceCents;
  final String description;
  final String category;
  final List<String> tags;
  final String? imageAsset;
  final bool inStock;

  /// Whether this product can be purchased directly in the app (requires internet + vendor API).
  /// If false, user is directed to contact the vendor on WhatsApp.
  final bool canBuyOnline;

  String get priceLabel => '\$${(priceCents / 100).toStringAsFixed(2)}';

  Product copyWith({
    String? id,
    String? name,
    String? vendorId,
    int? priceCents,
    String? description,
    String? category,
    List<String>? tags,
    String? imageAsset,
    bool? inStock,
    bool? canBuyOnline,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      vendorId: vendorId ?? this.vendorId,
      priceCents: priceCents ?? this.priceCents,
      description: description ?? this.description,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      imageAsset: imageAsset ?? this.imageAsset,
      inStock: inStock ?? this.inStock,
      canBuyOnline: canBuyOnline ?? this.canBuyOnline,
    );
  }

  factory Product.fromJson(Map<String, Object?> json) {
    final rawTags = json['tags'];
    return Product(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unnamed product',
      vendorId: json['vendorId'] as String? ?? '',
      priceCents: (json['priceCents'] as num?)?.toInt() ?? 0,
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'Herbal remedy',
      tags: rawTags is List ? rawTags.whereType<String>().toList() : const [],
      imageAsset: json['imageAsset'] as String?,
      inStock: json['inStock'] as bool? ?? true,
      canBuyOnline: json['canBuyOnline'] as bool? ?? false,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'vendorId': vendorId,
        'priceCents': priceCents,
        'description': description,
        'category': category,
        'tags': tags,
        if (imageAsset != null) 'imageAsset': imageAsset,
        'inStock': inStock,
        'canBuyOnline': canBuyOnline,
      };
}
