class ReviewRecord {
  final String rowId;
  final String receiptNumber;
  final String date;
  final String description;
  final double amount;
  final double? quantity;
  final double? rate;
  final double? amountMismatch;
  final String verificationStatus;
  final String receiptLink;
  final List<double>? dateBbox;
  final List<double>? receiptNumberBbox;
  final List<double>? combinedBbox;
  final List<double>? lineItemBbox;
  final bool isHeader; // Derived
  final String? customerName;
  final String? mobileNumber;
  final String? auditFindings;
  final String? type;
  
  // Payment tracking fields
  final String? paymentMode;
  final double? receivedAmount;
  final double? balanceDue;
  final String? customerDetails;
  
  // Tax / Calculation state
  final String? gstMode;
  final String? taxableRowIds;
  
  // Dynamic fields mapping
  final Map<String, dynamic> extraFields;

  // New helper getter for validation hoisting
  // New helper for stable sorting when BBox is missing
  int get sortIndex {
    final parts = rowId.split('_');
    if (parts.length > 1) {
      return int.tryParse(parts.last) ?? 0;
    }
    return 0;
  }

  bool get hasError {
    if (verificationStatus.toLowerCase() == 'duplicate receipt number') {
      return true;
    }
    if (amountMismatch != null && amountMismatch!.abs() >= 1.0) {
      return true;
    }
    if (isHeader && date.trim().isEmpty) {
      return true;
    }
    if (isHeader && (customerName == null || customerName!.trim().isEmpty)) {
      return true;
    }
    return false;
  }

  bool get hasReceiptDoubt {
    return auditFindings != null &&
        auditFindings!.contains('Low Receipt Number Confidence');
  }

  bool get hasDateDoubt {
    return auditFindings != null &&
        auditFindings!.contains('Low Date Confidence');
  }

  ReviewRecord({
    required this.rowId,
    required this.receiptNumber,
    required this.date,
    required this.description,
    required this.amount,
    this.quantity,
    this.rate,
    this.amountMismatch,
    required this.verificationStatus,
    required this.receiptLink,
    this.dateBbox,
    this.receiptNumberBbox,
    this.combinedBbox,
    this.lineItemBbox,
    required this.isHeader,
    this.customerName,
    this.mobileNumber,
    this.auditFindings,
    this.type,
    this.paymentMode,
    this.receivedAmount,
    this.balanceDue,
    this.customerDetails,
    this.gstMode,
    this.taxableRowIds,
    this.extraFields = const {},
  });

  factory ReviewRecord.fromJson(Map<String, dynamic> json,
      {required bool isHeaderType}) {
    final extra = json['extra_fields'] is Map ? Map<String, dynamic>.from(json['extra_fields']) : <String, dynamic>{};
      
    return ReviewRecord(
      rowId: (json['row_id'] ?? json['Row_Id'])?.toString() ?? '',
      receiptNumber:
          (json['receipt_number'] ?? json['Receipt Number'])?.toString() ?? '',
      date: _toIndianDate((json['date'] ?? json['Date'])?.toString() ?? ''),
      description:
          (json['description'] ?? json['Description'])?.toString() ?? '',
      amount: double.tryParse(
              (json['amount'] ?? json['Amount'])?.toString() ?? '0') ??
          0.0,
      quantity: double.tryParse(
          (json['quantity'] ?? json['Quantity'])?.toString() ?? ''),
      rate: double.tryParse((json['rate'] ?? json['Rate'])?.toString() ?? ''),
      amountMismatch: double.tryParse(
          (json['amount_mismatch'] ?? json['Amount Mismatch'])?.toString() ??
              ''),
      verificationStatus:
          (json['verification_status'] ?? json['Verification Status'])
                  ?.toString() ??
              'Pending',
      receiptLink:
          (json['receipt_link'] ?? json['Receipt Link'])?.toString() ?? '',
      dateBbox: _parseBbox(json['date_bbox']),
      receiptNumberBbox: _parseBbox(json['receipt_number_bbox']),
      combinedBbox: _parseBbox(json['date_and_receipt_combined_bbox']),
      lineItemBbox: _parseBbox(json['line_item_row_bbox']),
      isHeader: isHeaderType,
      customerName: json['customer_name']?.toString() ??
          json['Customer Name']?.toString(),
      mobileNumber: json['mobile_number']?.toString() ??
          json['Mobile Number']?.toString() ??
          extra['mobile_number']?.toString(),
      auditFindings: json['audit_findings']?.toString() ??
          json['Audit Findings']?.toString(),
      type: json['type']?.toString() ?? json['Type']?.toString(),
      paymentMode: json['payment_mode']?.toString() ?? json['Payment Mode']?.toString(),
      receivedAmount: double.tryParse((json['received_amount'] ?? json['Received Amount'])?.toString() ?? ''),
      balanceDue: double.tryParse((json['balance_due'] ?? json['Balance Due'])?.toString() ?? ''),
      customerDetails: json['customer_details']?.toString() ?? json['Customer Details']?.toString(),
      gstMode: json['gst_mode']?.toString() ?? json['GST Mode']?.toString(),
      taxableRowIds: json['taxable_row_ids']?.toString() ?? json['Taxable Row Ids']?.toString(),
      extraFields: extra,
    );
  }

  /// Converts a Supabase ISO date string (yyyy-MM-dd or yyyy-MM-ddTHH:mm:ss...)
  /// to Indian display format (dd-MM-yyyy).
  /// If the string is already in dd-MM-yyyy format, it is returned unchanged.
  static String _toIndianDate(String raw) {
    if (raw.isEmpty) return raw;
    // Already in dd-MM-yyyy format (e.g. "25-02-2026")
    final ddMMyyyy = RegExp(r'^\d{2}-\d{2}-\d{4}$');
    if (ddMMyyyy.hasMatch(raw)) return raw;
    // ISO format: yyyy-MM-dd or yyyy-MM-ddTHH:mm:ssZ
    try {
      final dt = DateTime.parse(raw);
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      return '$day-$month-${dt.year}';
    } catch (_) {}
    return raw; // unknown format – display as-is
  }

  static List<double>? _parseBbox(dynamic bboxJson) {
    if (bboxJson == null) return null;
    if (bboxJson is List) {
      return List<double>.from(bboxJson.map((e) => (e as num).toDouble()));
    }
    if (bboxJson is Map<String, dynamic>) {
      final x = (bboxJson['x'] as num?)?.toDouble() ?? 0.0;
      final y = (bboxJson['y'] as num?)?.toDouble() ?? 0.0;
      final w = (bboxJson['width'] as num?)?.toDouble() ?? 0.0;
      final h = (bboxJson['height'] as num?)?.toDouble() ?? 0.0;
      return [x, y, w, h];
    }
    return null;
  }

  ReviewRecord copyWith({
    String? rowId,
    String? receiptNumber,
    String? date,
    String? description,
    double? amount,
    double? quantity,
    double? rate,
    double? amountMismatch,
    String? verificationStatus,
    String? receiptLink,
    List<double>? dateBbox,
    List<double>? receiptNumberBbox,
    List<double>? combinedBbox,
    List<double>? lineItemBbox,
    bool? isHeader,
    String? customerName,
    String? mobileNumber,
    String? auditFindings,
    String? type,
    String? paymentMode,
    double? receivedAmount,
    double? balanceDue,
    String? customerDetails,
    String? gstMode,
    String? taxableRowIds,
    Map<String, dynamic>? extraFields,
  }) {
    return ReviewRecord(
      rowId: rowId ?? this.rowId,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      date: date ?? this.date,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
      amountMismatch: amountMismatch ?? this.amountMismatch,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      receiptLink: receiptLink ?? this.receiptLink,
      dateBbox: dateBbox ?? this.dateBbox,
      receiptNumberBbox: receiptNumberBbox ?? this.receiptNumberBbox,
      combinedBbox: combinedBbox ?? this.combinedBbox,
      lineItemBbox: lineItemBbox ?? this.lineItemBbox,
      isHeader: isHeader ?? this.isHeader,
      customerName: customerName ?? this.customerName,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      auditFindings: auditFindings ?? this.auditFindings,
      type: type ?? this.type,
      paymentMode: paymentMode ?? this.paymentMode,
      receivedAmount: receivedAmount ?? this.receivedAmount,
      balanceDue: balanceDue ?? this.balanceDue,
      customerDetails: customerDetails ?? this.customerDetails,
      gstMode: gstMode ?? this.gstMode,
      taxableRowIds: taxableRowIds ?? this.taxableRowIds,
      extraFields: extraFields ?? this.extraFields,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'row_id': rowId,
      'receipt_number': receiptNumber,
      'date': date,
      'description': description,
      'amount': amount,
      'quantity': quantity,
      'rate': rate,
      'amount_mismatch': amountMismatch,
      'verification_status': verificationStatus,
      'receipt_link': receiptLink,
      'date_bbox': dateBbox,
      'receipt_number_bbox': receiptNumberBbox,
      'date_and_receipt_combined_bbox': combinedBbox,
      'line_item_row_bbox': lineItemBbox,
      'customer_name': customerName,
      'mobile_number': mobileNumber,
      'audit_findings': auditFindings,
      'type': type,
      if (paymentMode != null) 'payment_mode': paymentMode,
      if (receivedAmount != null) 'received_amount': receivedAmount,
      if (balanceDue != null) 'balance_due': balanceDue,
      if (customerDetails != null) 'customer_details': customerDetails,
      if (gstMode != null) 'gst_mode': gstMode,
      if (taxableRowIds != null) 'taxable_row_ids': taxableRowIds,
      'extra_fields': extraFields,
    };
  }
}

class InvoiceReviewGroup {
  final String receiptNumber;
  final ReviewRecord? header;
  final List<ReviewRecord> lineItems;

  InvoiceReviewGroup({
    required this.receiptNumber,
    this.header,
    this.lineItems = const [],
  });

  bool get isComplete {
    final allComplete = [
      if (header != null) header!.verificationStatus.toLowerCase() == 'done',
      ...lineItems
          .map((item) => item.verificationStatus.toLowerCase() == 'done'),
    ];
    return allComplete.isNotEmpty && allComplete.every((isDone) => isDone);
  }

  bool get hasError {
    if (header != null && header!.hasError) return true;
    return lineItems.any((item) => item.hasError);
  }

  // Helper for UI badging (Pending, Error, Synced/Done)
  String get status {
    if (hasError) return 'Error';
    if (isComplete) return 'Done';
    return 'Pending';
  }
}
