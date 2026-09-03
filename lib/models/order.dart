/// A marketplace order recording products purchased from a vendor.
class Order {
  const Order({
    required this.id,
    required this.items,
    required this.totalCents,
    required this.vendorId,
    this.reference = '',
    this.status = OrderStatus.pending,
    this.paymentProofBase64 = '',
    this.paymentRejectionReason = '',
    this.finalPriceCents,
    this.deliveryMethod = '',
    this.deliveryArea = '',
    this.collectionPoint = '',
    this.turnaroundTime = '',
    this.paymentInstructions = '',
    this.deliveryInstructions = '',
    this.vendorNotes = '',
    this.createdAt,
  });

  final String id;
  final List<OrderItem> items;
  final int totalCents;
  final String vendorId;
  final String reference;
  final OrderStatus status;

  /// Base64-encoded buyer screenshot/photo of the EcoCash transfer.
  final String paymentProofBase64;
  final String paymentRejectionReason;

  /// Vendor confirmation details.
  final int? finalPriceCents;
  final String deliveryMethod;
  final String deliveryArea;
  final String collectionPoint;
  final String turnaroundTime;
  final String paymentInstructions;
  final String deliveryInstructions;
  final String vendorNotes;
  final DateTime? createdAt;

  /// The confirmed total, or the estimated total if vendor hasn't confirmed yet.
  int get confirmedTotalCents => finalPriceCents ?? totalCents;
  String get confirmedTotalLabel => '\$${(confirmedTotalCents / 100).toStringAsFixed(2)}';

  String get totalLabel => '\$${(totalCents / 100).toStringAsFixed(2)}';

  DateTime get date => createdAt ?? DateTime.now();

  factory Order.fromJson(Map<String, Object?> json) {
    final rawItems = json['items'];
    return Order(
      id: json['id'] as String? ?? '',
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((e) => OrderItem.fromJson(Map<String, Object?>.from(e)))
              .toList()
          : const [],
      totalCents: (json['totalCents'] as num?)?.toInt() ?? 0,
      vendorId: json['vendorId'] as String? ?? '',
      reference: json['reference'] as String? ?? '',
      status: OrderStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => OrderStatus.pending,
      ),
      paymentProofBase64: json['paymentProofBase64'] as String? ?? '',
      paymentRejectionReason: json['paymentRejectionReason'] as String? ?? '',
      finalPriceCents: (json['finalPriceCents'] as num?)?.toInt(),
      deliveryMethod: json['deliveryMethod'] as String? ?? '',
      deliveryArea: json['deliveryArea'] as String? ?? '',
      collectionPoint: json['collectionPoint'] as String? ?? '',
      turnaroundTime: json['turnaroundTime'] as String? ?? '',
      paymentInstructions: json['paymentInstructions'] as String? ?? '',
      deliveryInstructions: json['deliveryInstructions'] as String? ?? '',
      vendorNotes: json['vendorNotes'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String? ?? '')
          : null,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'items': items.map((e) => e.toJson()).toList(),
        'totalCents': totalCents,
        'vendorId': vendorId,
        'reference': reference,
        'status': status.name,
        'paymentProofBase64': paymentProofBase64,
        'paymentRejectionReason': paymentRejectionReason,
        'finalPriceCents': finalPriceCents,
        'deliveryMethod': deliveryMethod,
        'deliveryArea': deliveryArea,
        'collectionPoint': collectionPoint,
        'turnaroundTime': turnaroundTime,
        'paymentInstructions': paymentInstructions,
        'deliveryInstructions': deliveryInstructions,
        'vendorNotes': vendorNotes,
        'createdAt': date.toIso8601String(),
      };

  Order copyWith({
    OrderStatus? status,
    String? paymentProofBase64,
    String? paymentRejectionReason,
    int? finalPriceCents,
    String? deliveryMethod,
    String? deliveryArea,
    String? collectionPoint,
    String? turnaroundTime,
    String? paymentInstructions,
    String? deliveryInstructions,
    String? vendorNotes,
  }) =>
      Order(
        id: id,
        items: items,
        totalCents: totalCents,
        vendorId: vendorId,
        reference: reference,
        status: status ?? this.status,
        paymentProofBase64: paymentProofBase64 ?? this.paymentProofBase64,
        paymentRejectionReason:
            paymentRejectionReason ?? this.paymentRejectionReason,
        finalPriceCents: finalPriceCents ?? this.finalPriceCents,
        deliveryMethod: deliveryMethod ?? this.deliveryMethod,
        deliveryArea: deliveryArea ?? this.deliveryArea,
        collectionPoint: collectionPoint ?? this.collectionPoint,
        turnaroundTime: turnaroundTime ?? this.turnaroundTime,
        paymentInstructions: paymentInstructions ?? this.paymentInstructions,
        deliveryInstructions: deliveryInstructions ?? this.deliveryInstructions,
        vendorNotes: vendorNotes ?? this.vendorNotes,
        createdAt: createdAt,
      );
}

/// A single line item within an order.
class OrderItem {
  const OrderItem({
    required this.productId,
    required this.name,
    required this.priceCents,
    this.quantity = 1,
  });

  final String productId;
  final String name;
  final int priceCents;
  final int quantity;

  int get lineTotal => priceCents * quantity;

  factory OrderItem.fromJson(Map<String, Object?> json) {
    return OrderItem(
      productId: json['productId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      priceCents: (json['priceCents'] as num?)?.toInt() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, Object?> toJson() => {
        'productId': productId,
        'name': name,
        'priceCents': priceCents,
        'quantity': quantity,
      };
}

enum OrderStatus {
  pending,
  paymentProofSubmitted,
  paymentRejected,
  confirmed,
  delivered,
  cancelled,
}
