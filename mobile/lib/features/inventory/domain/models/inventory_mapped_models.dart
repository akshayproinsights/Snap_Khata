double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

class VendorMappingEntry {
  final int? id;
  final String vendorDescription;
  final String? partNumber;
  final String? customerItemName;
  final double? stock;
  final double? reorder;
  final String status;
  final DateTime? createdAt;

  VendorMappingEntry({
    this.id,
    required this.vendorDescription,
    this.partNumber,
    this.customerItemName,
    this.stock,
    this.reorder,
    required this.status,
    this.createdAt,
  });

  factory VendorMappingEntry.fromJson(Map<String, dynamic> json) {
    return VendorMappingEntry(
      id: json['id'] != null ? _parseInt(json['id']) : null,
      vendorDescription: json['vendor_description']?.toString() ?? '',
      partNumber: json['part_number']?.toString(),
      customerItemName: json['customer_item_name']?.toString(),
      stock: json['stock'] != null ? _parseDouble(json['stock']) : null,
      reorder: json['reorder_point'] != null
          ? _parseDouble(json['reorder_point'])
          : null,
      status: json['status']?.toString() ?? 'Pending',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }
}
