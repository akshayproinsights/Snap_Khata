class VendorMappingExportItem {
  final int rowNumber;
  final String vendorDescription;
  final String? partNumber;
  final String? customerItemName;
  final int? stock;
  final int? reorder;
  final String? notes;

  VendorMappingExportItem({
    required this.rowNumber,
    required this.vendorDescription,
    this.partNumber,
    this.customerItemName,
    this.stock,
    this.reorder,
    this.notes,
  });

  factory VendorMappingExportItem.fromJson(Map<String, dynamic> json) {
    return VendorMappingExportItem(
      rowNumber: json['row_number'],
      vendorDescription: json['vendor_description'],
      partNumber: json['part_number'],
      customerItemName: json['customer_item_name'],
      stock: json['stock'],
      reorder: json['reorder'],
      notes: json['notes'],
    );
  }
}

class VendorMappingEntry {
  final int? id;
  final int rowNumber;
  final String vendorDescription;
  final String? partNumber;
  final String? customerItemName;
  final int? stock;
  final int? reorder;
  final String? notes;
  final String status;
  final int? systemQty;
  final int? variance;

  VendorMappingEntry({
    this.id,
    required this.rowNumber,
    required this.vendorDescription,
    this.partNumber,
    this.customerItemName,
    this.stock,
    this.reorder,
    this.notes,
    required this.status,
    this.systemQty,
    this.variance,
  });

  factory VendorMappingEntry.fromJson(Map<String, dynamic> json) {
    return VendorMappingEntry(
      id: json['id'],
      rowNumber: json['row_number'],
      vendorDescription: json['vendor_description'],
      partNumber: json['part_number'],
      customerItemName: json['customer_item_name'],
      stock: json['stock'],
      reorder: json['reorder'],
      notes: json['notes'],
      status: json['status'] ?? 'Pending',
      systemQty: json['system_qty'],
      variance: json['variance'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'row_number': rowNumber,
      'vendor_description': vendorDescription,
      'part_number': partNumber,
      'customer_item_name': customerItemName,
      'stock': stock,
      'reorder': reorder,
      'notes': notes,
      'status': status,
      'system_qty': systemQty,
      'variance': variance,
    };
  }
}
