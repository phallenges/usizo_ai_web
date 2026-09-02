/// A marketplace order recording products purchased from a vendor.
class Order {
  const Order({
    required this.id,
    required this.items,
    required this.totalCents,
    required this.vendorId,
    this.reference = '',
    this.status = OrderStatus.pending,
    this.createdAt,
  });

  final String id;
  final List<OrderItem> items;
  final int totalCents;
  final String vendorId;
  final String reference;
  final OrderStatus status;
  final DateTime? createdAt;

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
        'createdAt': date.toIso8601String(),
      };
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
  confirmed,
  delivered,
  cancelled,
}
