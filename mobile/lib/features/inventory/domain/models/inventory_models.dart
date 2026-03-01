class InventoryItem {
  final int id;
  final String invoiceDate;
  final String invoiceNumber;
  final String? vendorName;
  final String partNumber;
  final String description;
  final double qty;
  final double rate;
  final double netBill;
  final double amountMismatch;
  final String receiptLink;
  final String? uploadDate;
  final String? verificationStatus;
  final double? rowAccuracy;

  InventoryItem({
    required this.id,
    required this.invoiceDate,
    required this.invoiceNumber,
    this.vendorName,
    required this.partNumber,
    required this.description,
    required this.qty,
    required this.rate,
    required this.netBill,
    required this.amountMismatch,
    required this.receiptLink,
    this.uploadDate,
    this.verificationStatus,
    this.rowAccuracy,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'] as int,
      invoiceDate: json['invoice_date']?.toString() ?? '',
      invoiceNumber: json['invoice_number']?.toString() ?? '',
      vendorName: json['vendor_name']?.toString(),
      partNumber: json['part_number']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      qty: double.tryParse(json['qty']?.toString() ?? '0') ?? 0.0,
      rate: double.tryParse(json['rate']?.toString() ?? '0') ?? 0.0,
      netBill: double.tryParse(json['net_bill']?.toString() ?? '0') ?? 0.0,
      amountMismatch:
          double.tryParse(json['amount_mismatch']?.toString() ?? '0') ?? 0.0,
      receiptLink: json['receipt_link']?.toString() ?? '',
      uploadDate: json['upload_date']?.toString(),
      verificationStatus: json['verification_status']?.toString(),
      rowAccuracy: json['row_accuracy'] != null
          ? double.tryParse(json['row_accuracy'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoice_date': invoiceDate,
      'invoice_number': invoiceNumber,
      'vendor_name': vendorName,
      'part_number': partNumber,
      'description': description,
      'qty': qty,
      'rate': rate,
      'net_bill': netBill,
      'amount_mismatch': amountMismatch,
      'receipt_link': receiptLink,
      'upload_date': uploadDate,
      'verification_status': verificationStatus,
      'row_accuracy': rowAccuracy,
    };
  }

  InventoryItem copyWith({
    int? id,
    String? invoiceDate,
    String? invoiceNumber,
    String? vendorName,
    String? partNumber,
    String? description,
    double? qty,
    double? rate,
    double? netBill,
    double? amountMismatch,
    String? receiptLink,
    String? uploadDate,
    String? verificationStatus,
    double? rowAccuracy,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      vendorName: vendorName ?? this.vendorName,
      partNumber: partNumber ?? this.partNumber,
      description: description ?? this.description,
      qty: qty ?? this.qty,
      rate: rate ?? this.rate,
      netBill: netBill ?? this.netBill,
      amountMismatch: amountMismatch ?? this.amountMismatch,
      receiptLink: receiptLink ?? this.receiptLink,
      uploadDate: uploadDate ?? this.uploadDate,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      rowAccuracy: rowAccuracy ?? this.rowAccuracy,
    );
  }
}
