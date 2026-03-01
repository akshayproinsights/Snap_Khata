class CustomerItemVariation {
  final String originalDescription;
  final int occurrenceCount;
  final double totalQty;

  CustomerItemVariation({
    required this.originalDescription,
    required this.occurrenceCount,
    required this.totalQty,
  });

  factory CustomerItemVariation.fromJson(Map<String, dynamic> json) {
    return CustomerItemVariation(
      originalDescription: json['original_description'] ?? '',
      occurrenceCount: json['occurrence_count'] ?? 0,
      totalQty: (json['total_qty'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class CustomerItem {
  final String customerItem;
  final int occurrenceCount;
  final double totalQty;
  final String? normalizedDescription;
  final int? variationCount;
  final List<CustomerItemVariation>? variations;
  // Stock-mapping fields
  final int? stockLevelId;
  final String? partNumber;

  CustomerItem({
    required this.customerItem,
    required this.occurrenceCount,
    required this.totalQty,
    this.normalizedDescription,
    this.variationCount,
    this.variations,
    this.stockLevelId,
    this.partNumber,
  });

  factory CustomerItem.fromJson(Map<String, dynamic> json) {
    return CustomerItem(
      customerItem: json['customer_item'] ?? '',
      occurrenceCount: json['occurrence_count'] ?? 0,
      totalQty: (json['total_qty'] as num?)?.toDouble() ?? 0.0,
      normalizedDescription: json['normalized_description'],
      variationCount: json['variation_count'],
      variations: json['variations'] != null
          ? (json['variations'] as List)
              .map((v) => CustomerItemVariation.fromJson(v))
              .toList()
          : null,
      stockLevelId: json['stock_level_id'],
      partNumber: json['part_number'],
    );
  }
}

class VendorItem {
  final int id;
  final String description;
  final String partNumber;
  final double? qty;
  final double? rate;
  final double? matchScore;

  VendorItem({
    required this.id,
    required this.description,
    required this.partNumber,
    this.qty,
    this.rate,
    this.matchScore,
  });

  factory VendorItem.fromJson(Map<String, dynamic> json) {
    return VendorItem(
      id: json['id'] ?? 0,
      description: json['description'] ?? '',
      partNumber: json['part_number'] ?? '',
      qty: (json['qty'] as num?)?.toDouble(),
      rate: (json['rate'] as num?)?.toDouble(),
      matchScore: (json['match_score'] as num?)?.toDouble(),
    );
  }
}
