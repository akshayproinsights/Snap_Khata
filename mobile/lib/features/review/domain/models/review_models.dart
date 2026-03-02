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

  // New helper getter for validation hoisting
  bool get hasError {
    if (verificationStatus.toLowerCase() == 'duplicate receipt number') {
      return true;
    }
    if (amountMismatch != null && amountMismatch!.abs() > 0.01) {
      return true;
    }
    if (receiptNumber.trim().isEmpty) {
      return true;
    }
    if (isHeader && date.trim().isEmpty) {
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
  });

  factory ReviewRecord.fromJson(Map<String, dynamic> json,
      {required bool isHeaderType}) {
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
          json['Mobile Number']?.toString(),
      auditFindings: json['audit_findings']?.toString() ??
          json['Audit Findings']?.toString(),
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
