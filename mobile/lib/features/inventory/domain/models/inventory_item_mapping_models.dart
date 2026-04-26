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

  CustomerItem({
    required this.customerItem,
    required this.occurrenceCount,
    required this.totalQty,
    this.normalizedDescription,
    this.variationCount,
    this.variations,
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
    );
  }

  /// All raw name strings (including main + all variations)
  List<String> get allVariationDescriptions {
    if (variations == null || variations!.isEmpty) return [customerItem];
    return variations!.map((v) => v.originalDescription).toList();
  }
}

class MappedItem {
  final int? id;
  final String customerItem;
  final String? normalizedDescription;
  final String? vendorDescription;
  final String? vendorPartNumber;
  final int priority;
  final String status;
  final String? mappedOn;

  MappedItem({
    this.id,
    required this.customerItem,
    this.normalizedDescription,
    this.vendorDescription,
    this.vendorPartNumber,
    this.priority = 0,
    required this.status,
    this.mappedOn,
  });

  factory MappedItem.fromJson(Map<String, dynamic> json) {
    return MappedItem(
      id: json['id'],
      customerItem: json['customer_item'] ?? '',
      normalizedDescription: json['normalized_description'],
      vendorDescription: json['vendor_description'],
      vendorPartNumber: json['vendor_part_number'],
      priority: json['priority'] ?? 0,
      status: json['status'] ?? 'Pending',
      mappedOn: json['mapped_on'],
    );
  }
}

class VendorItem {
  final int id;
  final String description;
  final String partNumber;
  final double? quantity;
  final double? rate;
  final double? matchScore;

  VendorItem({
    required this.id,
    required this.description,
    required this.partNumber,
    this.quantity,
    this.rate,
    this.matchScore,
  });

  factory VendorItem.fromJson(Map<String, dynamic> json) {
    return VendorItem(
      id: json['id'] ?? 0,
      description: json['description'] ?? '',
      partNumber: json['part_number'] ?? '',
      quantity: ((json['quantity'] ?? json['qty']) as num?)?.toDouble(),
      rate: (json['rate'] as num?)?.toDouble(),
      matchScore: (json['match_score'] as num?)?.toDouble(),
    );
  }
}
