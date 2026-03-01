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

class StockLevel {
  final int id;
  final String partNumber;
  final String internalItemName;
  final String? customerItems;
  final int currentStock;
  final int reorderPoint;
  final int? manualAdjustment;
  final String? priority;
  final String? status;
  final double? unitValue;

  StockLevel({
    required this.id,
    required this.partNumber,
    required this.internalItemName,
    this.customerItems,
    this.currentStock = 0,
    this.reorderPoint = 0,
    this.manualAdjustment,
    this.priority,
    this.status,
    this.unitValue,
  });

  factory StockLevel.fromJson(Map<String, dynamic> json) {
    return StockLevel(
      id: _parseInt(json['id']),
      partNumber: json['part_number']?.toString() ?? '',
      internalItemName: json['internal_item_name']?.toString() ?? '',
      customerItems: json['customer_items']?.toString(),
      currentStock: _parseInt(json['current_stock']),
      reorderPoint: _parseInt(json['reorder_point']),
      manualAdjustment: json['manual_adjustment'] != null
          ? _parseInt(json['manual_adjustment'])
          : null,
      priority: json['priority']?.toString(),
      status: json['status']?.toString(),
      unitValue:
          json['unit_value'] != null ? _parseDouble(json['unit_value']) : null,
    );
  }
}

class StockSummary {
  final double totalStockValue;
  final int lowStockItems;
  final int outOfStock;
  final int totalItems;

  StockSummary({
    required this.totalStockValue,
    required this.lowStockItems,
    required this.outOfStock,
    required this.totalItems,
  });

  factory StockSummary.fromJson(Map<String, dynamic> json) {
    return StockSummary(
      totalStockValue: _parseDouble(json['total_stock_value']),
      lowStockItems: _parseInt(json['low_stock_items']),
      outOfStock: _parseInt(json['out_of_stock']),
      totalItems: _parseInt(json['total_items']),
    );
  }
}
