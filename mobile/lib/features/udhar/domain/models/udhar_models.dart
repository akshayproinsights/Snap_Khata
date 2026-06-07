class CustomerLedger {
  final int id;
  final String customerName;
  final String? customerPhone;
  final double balanceDue;
  final DateTime? lastPaymentDate;
  final String? latestBillNumber;
  final double? latestBillAmount;
  final DateTime? latestBillDate;
  final DateTime? latestUploadDate;
  final DateTime? updatedAt;

  CustomerLedger({
    required this.id,
    required this.customerName,
    this.customerPhone,
    required this.balanceDue,
    this.lastPaymentDate,
    this.latestBillNumber,
    this.latestBillAmount,
    this.latestBillDate,
    this.latestUploadDate,
    this.updatedAt,
  });

  CustomerLedger copyWith({
    int? id,
    String? customerName,
    String? customerPhone,
    double? balanceDue,
    DateTime? lastPaymentDate,
    String? latestBillNumber,
    double? latestBillAmount,
    DateTime? latestBillDate,
    DateTime? latestUploadDate,
    DateTime? updatedAt,
  }) {
    return CustomerLedger(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      balanceDue: balanceDue ?? this.balanceDue,
      lastPaymentDate: lastPaymentDate ?? this.lastPaymentDate,
      latestBillNumber: latestBillNumber ?? this.latestBillNumber,
      latestBillAmount: latestBillAmount ?? this.latestBillAmount,
      latestBillDate: latestBillDate ?? this.latestBillDate,
      latestUploadDate: latestUploadDate ?? this.latestUploadDate,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory CustomerLedger.fromJson(Map<String, dynamic> json) {
    return CustomerLedger(
      id: json['id'],
      customerName: json['customer_name'] ?? 'Unknown',
      customerPhone: json['customer_phone'],
      balanceDue:
          double.tryParse(json['balance_due']?.toString() ?? '0') ?? 0.0,
      lastPaymentDate: json['last_payment_date'] != null
          ? DateTime.parse(json['last_payment_date'])
          : null,
      latestBillNumber: json['latest_bill_number'],
      latestBillAmount: json['latest_bill_amount'] != null
          ? double.tryParse(json['latest_bill_amount'].toString())
          : null,
      latestBillDate: json['latest_bill_date'] != null
          ? DateTime.parse(json['latest_bill_date'])
          : null,
      latestUploadDate: json['latest_upload_date'] != null
          ? DateTime.parse(json['latest_upload_date'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }
}

class LedgerTransaction {
  final int id;
  final int ledgerId;
  final String transactionType; // 'INVOICE' or 'PAYMENT'
  final double amount;
  final String? receiptNumber;
  final String? notes;
  final DateTime createdAt;
  final bool isPaid;
  final int? linkedTransactionId;
  final String? receiptLink;
  final double? balanceDue;
  final String? paymentMode;
  final double? receivedAmount;
  final List<Map<String, dynamic>> items; // item breakdown for manual entries
  final bool isManualEntry;
  // True when this PAYMENT row is an advance linked to a MANUAL_CREDIT bill.
  // Flutter hides these from the card list — the amount is shown inline on the bill card.
  final bool isAdvanceLinked;
  final DateTime? orderDate;     // Laundry: date clothes were received
  final DateTime? deliveryDate;  // Laundry: promised delivery date

  LedgerTransaction({
    required this.id,
    required this.ledgerId,
    required this.transactionType,
    required this.amount,
    this.receiptNumber,
    this.notes,
    required this.createdAt,
    this.isPaid = false,
    this.linkedTransactionId,
    this.receiptLink,
    this.balanceDue,
    this.paymentMode,
    this.receivedAmount,
    this.items = const [],
    this.isManualEntry = false,
    this.isAdvanceLinked = false,
    this.orderDate,
    this.deliveryDate,
  });

  // Getters for backwards compatibility
  String get type => transactionType;
  String get description => notes ?? receiptNumber ?? '';
  DateTime get date => createdAt;

  factory LedgerTransaction.fromJson(Map<String, dynamic> json) {
    // Parse item breakdown stored in extra_fields by the manual-entry endpoint.
    final extra = json['extra_fields'];
    List<Map<String, dynamic>> parsedItems = [];
    bool parsedIsManual = false;
    if (extra is Map) {
      final rawItems = extra['items'];
      if (rawItems is List) {
        parsedItems = rawItems
            .whereType<Map>()
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      parsedIsManual = extra['is_manual_entry'] == true;
    }

    return LedgerTransaction(
      id: json['id'],
      ledgerId: json['ledger_id'],
      transactionType: json['transaction_type'] ?? 'UNKNOWN',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      receiptNumber: json['receipt_number']?.toString(),
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
      isPaid: json['is_paid'] ?? false,
      linkedTransactionId: json['linked_transaction_id'],
      receiptLink: json['receipt_link'],
      balanceDue: json['balance_due'] != null
          ? double.tryParse(json['balance_due'].toString())
          : null,
      paymentMode: json['payment_mode'],
      receivedAmount: json['received_amount'] != null
          ? double.tryParse(json['received_amount'].toString())
          : null,
      items: parsedItems,
      isManualEntry: parsedIsManual,
      isAdvanceLinked: json['is_advance_linked'] == true,
      orderDate: extra is Map && extra['order_date'] != null
          ? DateTime.tryParse(extra['order_date'].toString())
          : null,
      deliveryDate: extra is Map && extra['delivery_date'] != null
          ? DateTime.tryParse(extra['delivery_date'].toString())
          : null,
    );
  }
}

class OrderLineItem {
  final String description;
  final int quantity;
  final double rate;
  final double amount;

  OrderLineItem({
    required this.description,
    required this.quantity,
    required this.rate,
    required this.amount,
  });

  factory OrderLineItem.fromJson(Map<String, dynamic> json) {
    return OrderLineItem(
      description: json['description'] ?? 'Item',
      quantity: int.tryParse(json['quantity']?.toString() ?? '0') ?? 0,
      rate: double.tryParse(json['rate']?.toString() ?? '0') ?? 0.0,
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class CatalogueItem {
  final int id;
  final String itemName;
  final double lastPrice;
  final String unit;
  final int useCount;
  final DateTime? lastUsedAt;
  final DateTime? createdAt;

  CatalogueItem({
    required this.id,
    required this.itemName,
    required this.lastPrice,
    required this.unit,
    required this.useCount,
    this.lastUsedAt,
    this.createdAt,
  });

  factory CatalogueItem.fromJson(Map<String, dynamic> json) {
    return CatalogueItem(
      id: json['id'],
      itemName: json['item_name'] ?? '',
      lastPrice: double.tryParse(json['last_price']?.toString() ?? '0') ?? 0.0,
      unit: json['unit'] ?? 'NOS',
      useCount: json['use_count'] ?? 1,
      lastUsedAt: json['last_used_at'] != null ? DateTime.parse(json['last_used_at']) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }
}

