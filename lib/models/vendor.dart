/// A vendor who sells herbal remedies on the UsizoAI marketplace.
class Vendor {
  const Vendor({
    required this.id,
    required this.name,
    required this.location,
    this.description = '',
    this.phone = '',
    this.whatsapp = '',
    this.rating = 0.0,
    this.reviewCount = 0,
    this.lat,
    this.lng,
  });

  final String id;
  final String name;

  /// City or area, e.g. "Harare", "Bulawayo", "Chitungwiza".
  final String location;
  final String description;
  final String phone;
  final String whatsapp;
  final double rating;
  final int reviewCount;

  /// GPS coordinates for proximity calculations.
  final double? lat;
  final double? lng;

  String get ratingLabel => rating > 0 ? rating.toStringAsFixed(1) : 'New';

  bool get hasCoordinates => lat != null && lng != null;

  Vendor copyWith({
    String? id,
    String? name,
    String? location,
    String? description,
    String? phone,
    String? whatsapp,
    double? rating,
    int? reviewCount,
    double? lat,
    double? lng,
  }) {
    return Vendor(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      description: description ?? this.description,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
    );
  }

  factory Vendor.fromJson(Map<String, Object?> json) {
    return Vendor(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown vendor',
      location: json['location'] as String? ?? '',
      description: json['description'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      whatsapp: json['whatsapp'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'location': location,
        'description': description,
        'phone': phone,
        'whatsapp': whatsapp,
        'rating': rating,
        'reviewCount': reviewCount,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      };
}
