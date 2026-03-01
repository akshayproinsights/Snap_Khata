class GroupedItem {
  final int? id;
  final String customerItem;
  final int groupedCount;
  final List<int> groupedInvoiceIds;
  final List<String> groupedDescriptions;
  final String status;
  final String? mappedDescription;
  final int? mappedInventoryItemId;
  final String? confirmedAt;

  GroupedItem({
    this.id,
    required this.customerItem,
    required this.groupedCount,
    required this.groupedInvoiceIds,
    required this.groupedDescriptions,
    required this.status,
    this.mappedDescription,
    this.mappedInventoryItemId,
    this.confirmedAt,
  });

  factory GroupedItem.fromJson(Map<String, dynamic> json) {
    return GroupedItem(
      id: json['id'],
      customerItem: json['customer_item'] ?? '',
      groupedCount: json['grouped_count'] ?? 0,
      groupedInvoiceIds: List<int>.from(json['grouped_invoice_ids'] ?? []),
      groupedDescriptions:
          List<String>.from(json['grouped_descriptions'] ?? []),
      status: json['status'] ?? 'Pending',
      mappedDescription: json['mapped_description'],
      mappedInventoryItemId: json['mapped_inventory_item_id'],
      confirmedAt: json['confirmed_at'],
    );
  }

  GroupedItem copyWith({
    int? id,
    String? customerItem,
    int? groupedCount,
    List<int>? groupedInvoiceIds,
    List<String>? groupedDescriptions,
    String? status,
    String? mappedDescription,
    int? mappedInventoryItemId,
    String? confirmedAt,
  }) {
    return GroupedItem(
      id: id ?? this.id,
      customerItem: customerItem ?? this.customerItem,
      groupedCount: groupedCount ?? this.groupedCount,
      groupedInvoiceIds: groupedInvoiceIds ?? this.groupedInvoiceIds,
      groupedDescriptions: groupedDescriptions ?? this.groupedDescriptions,
      status: status ?? this.status,
      mappedDescription: mappedDescription ?? this.mappedDescription,
      mappedInventoryItemId:
          mappedInventoryItemId ?? this.mappedInventoryItemId,
      confirmedAt: confirmedAt ?? this.confirmedAt,
    );
  }
}

class InventorySuggestionItem {
  final int id;
  final String description;
  final String partNumber;

  InventorySuggestionItem({
    required this.id,
    required this.description,
    required this.partNumber,
  });

  factory InventorySuggestionItem.fromJson(Map<String, dynamic> json) {
    return InventorySuggestionItem(
      id: json['id'] ?? 0,
      description: json['description'] ?? '',
      partNumber: json['part_number'] ?? '',
    );
  }
}
