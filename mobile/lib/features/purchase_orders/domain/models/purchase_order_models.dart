/// Domain models for the Purchase Orders feature.
library;

// ─── Draft PO Item ────────────────────────────────────────────────────────────

class DraftPoItem {
  final String partNumber;
  final String itemName;
  final double currentStock;
  final double reorderPoint;
  final int reorderQty;
  final double? unitValue;
  final double? estimatedCost;
  final String priority; // P0, P1, P2, P3
  final String? supplierName;
  final String? notes;
  final String? addedAt;

  DraftPoItem({
    required this.partNumber,
    required this.itemName,
    required this.currentStock,
    required this.reorderPoint,
    required this.reorderQty,
    this.unitValue,
    this.estimatedCost,
    this.priority = 'P2',
    this.supplierName,
    this.notes,
    this.addedAt,
  });

  factory DraftPoItem.fromJson(Map<String, dynamic> json) {
    return DraftPoItem(
      partNumber: json['part_number'] as String? ?? '',
      itemName: json['item_name'] as String? ?? 'Unknown',
      currentStock: (json['current_stock'] ?? 0).toDouble(),
      reorderPoint: (json['reorder_point'] ?? 0).toDouble(),
      reorderQty: json['reorder_qty'] as int? ?? 1,
      unitValue: json['unit_value'] != null
          ? (json['unit_value'] as num).toDouble()
          : null,
      estimatedCost: json['estimated_cost'] != null
          ? (json['estimated_cost'] as num).toDouble()
          : null,
      priority: json['priority'] as String? ?? 'P2',
      supplierName: json['supplier_name'] as String?,
      notes: json['notes'] as String?,
      addedAt: json['added_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'part_number': partNumber,
        'item_name': itemName,
        'current_stock': currentStock,
        'reorder_point': reorderPoint,
        'reorder_qty': reorderQty,
        'unit_value': unitValue,
        'priority': priority,
        'supplier_name': supplierName,
        'notes': notes,
      };

  /// Return a copy with an updated reorder quantity.
  DraftPoItem copyWithQty(int qty) => DraftPoItem(
        partNumber: partNumber,
        itemName: itemName,
        currentStock: currentStock,
        reorderPoint: reorderPoint,
        reorderQty: qty,
        unitValue: unitValue,
        estimatedCost: unitValue != null ? unitValue! * qty : null,
        priority: priority,
        supplierName: supplierName,
        notes: notes,
        addedAt: addedAt,
      );
}

// ─── Draft Summary ────────────────────────────────────────────────────────────

class DraftPoSummary {
  final List<DraftPoItem> items;
  final int totalItems;
  final double totalEstimatedCost;

  DraftPoSummary({
    required this.items,
    required this.totalItems,
    required this.totalEstimatedCost,
  });

  factory DraftPoSummary.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? [];
    final items = rawItems
        .map((i) => DraftPoItem.fromJson(Map<String, dynamic>.from(i as Map)))
        .toList();
    final summary = (json['summary'] as Map?) ?? {};
    return DraftPoSummary(
      items: items,
      totalItems: summary['total_items'] as int? ?? items.length,
      totalEstimatedCost: (summary['total_estimated_cost'] ?? 0).toDouble(),
    );
  }

  static DraftPoSummary empty() =>
      DraftPoSummary(items: [], totalItems: 0, totalEstimatedCost: 0);
}

// ─── Purchase Order (History) ─────────────────────────────────────────────────

class PurchaseOrder {
  final String id;
  final String poNumber;
  final String poDate;
  final String? supplierName;
  final int totalItems;
  final double totalEstimatedCost;
  final String status; // draft, placed, received, cancelled
  final String? notes;
  final String createdAt;

  PurchaseOrder({
    required this.id,
    required this.poNumber,
    required this.poDate,
    this.supplierName,
    required this.totalItems,
    required this.totalEstimatedCost,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    return PurchaseOrder(
      id: json['id'] as String? ?? '',
      poNumber: json['po_number'] as String? ?? '',
      poDate: json['po_date'] as String? ?? '',
      supplierName: json['supplier_name'] as String?,
      totalItems: json['total_items'] as int? ?? 0,
      totalEstimatedCost: (json['total_estimated_cost'] ?? 0).toDouble(),
      status: json['status'] as String? ?? 'placed',
      notes: json['notes'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  /// Human-readable status label
  String get statusLabel {
    switch (status) {
      case 'placed':
        return 'Placed';
      case 'received':
        return 'Received';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status[0].toUpperCase() + status.substring(1);
    }
  }
}

// ─── Proceed Request ──────────────────────────────────────────────────────────

class ProceedToPORequest {
  final String? supplierName;
  final String? notes;
  final String? deliveryDate;

  ProceedToPORequest({this.supplierName, this.notes, this.deliveryDate});

  Map<String, dynamic> toJson() => {
        if (supplierName != null) 'supplier_name': supplierName,
        if (notes != null) 'notes': notes,
        if (deliveryDate != null) 'delivery_date': deliveryDate,
      };
}

// ─── Purchase Order Details ───────────────────────────────────────────────────

class PurchaseOrderLineItem {
  final String id;
  final String partNumber;
  final String itemName;
  final double currentStock;
  final double reorderPoint;
  final int orderedQty;
  final int receivedQty;
  final double? unitValue;
  final String? supplierPartNumber;
  final String deliveryStatus;

  PurchaseOrderLineItem({
    required this.id,
    required this.partNumber,
    required this.itemName,
    required this.currentStock,
    required this.reorderPoint,
    required this.orderedQty,
    required this.receivedQty,
    this.unitValue,
    this.supplierPartNumber,
    required this.deliveryStatus,
  });

  factory PurchaseOrderLineItem.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderLineItem(
      id: json['id'] as String? ?? '',
      partNumber: json['part_number'] as String? ?? '',
      itemName: json['item_name'] as String? ?? 'Unknown',
      currentStock: (json['current_stock'] ?? 0).toDouble(),
      reorderPoint: (json['reorder_point'] ?? 0).toDouble(),
      orderedQty: json['ordered_qty'] as int? ?? json['quantity'] as int? ?? 0,
      receivedQty: json['received_qty'] as int? ?? 0,
      unitValue: json['unit_value'] != null
          ? (json['unit_value'] as num).toDouble()
          : null,
      supplierPartNumber: json['supplier_part_number'] as String?,
      deliveryStatus: json['delivery_status'] as String? ?? 'pending',
    );
  }
}

class PurchaseOrderDetail {
  final PurchaseOrder po;
  final List<PurchaseOrderLineItem> items;

  PurchaseOrderDetail({
    required this.po,
    required this.items,
  });

  factory PurchaseOrderDetail.fromJson(Map<String, dynamic> json) {
    final poRecord =
        PurchaseOrder.fromJson(Map<String, dynamic>.from(json['po'] as Map));
    final rawItems = (json['items'] as List?) ?? [];
    final parsedItems = rawItems
        .map((i) =>
            PurchaseOrderLineItem.fromJson(Map<String, dynamic>.from(i as Map)))
        .toList();
    return PurchaseOrderDetail(po: poRecord, items: parsedItems);
  }
}
