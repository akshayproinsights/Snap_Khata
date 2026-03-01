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
  });

  factory ReviewRecord.fromJson(Map<String, dynamic> json,
      {required bool isHeaderType}) {
    return ReviewRecord(
      rowId: (json['row_id'] ?? json['Row_Id'])?.toString() ?? '',
      receiptNumber:
          (json['receipt_number'] ?? json['Receipt Number'])?.toString() ?? '',
      date: (json['date'] ?? json['Date'])?.toString() ?? '',
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
    );
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
}
