class GallaTransaction {
  final int id;
  final String username;
  final String transactionType;
  final double amount;
  final String? notes;
  final String? receiptNumber;
  final String createdAt;
  
  // Enriched fields
  final String? receiptLink;
  final String? customerName;
  final String? invoiceDate;
  final String? uploadDate;
  final String? mobileNumber;
  final String? paymentMode;
  final String? type;
  final double? receivedAmount;
  final double? balanceDue;
  final List<dynamic>? items;

  GallaTransaction({
    required this.id,
    required this.username,
    required this.transactionType,
    required this.amount,
    this.notes,
    this.receiptNumber,
    required this.createdAt,
    this.receiptLink,
    this.customerName,
    this.invoiceDate,
    this.uploadDate,
    this.mobileNumber,
    this.paymentMode,
    this.type,
    this.receivedAmount,
    this.balanceDue,
    this.items,
  });

  factory GallaTransaction.fromJson(Map<String, dynamic> json) {
    return GallaTransaction(
      id: json['id'] as int,
      username: json['username'] as String,
      transactionType: json['transaction_type'] as String,
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      notes: json['notes'] as String?,
      receiptNumber: json['receipt_number'] as String?,
      createdAt: json['created_at'] as String,
      receiptLink: json['receipt_link'] as String?,
      customerName: json['customer_name'] as String?,
      invoiceDate: json['invoice_date'] as String?,
      uploadDate: json['upload_date'] as String?,
      mobileNumber: json['mobile_number'] as String?,
      paymentMode: json['payment_mode'] as String?,
      type: json['type'] as String?,
      receivedAmount: json['received_amount'] != null ? double.tryParse(json['received_amount'].toString()) : null,
      balanceDue: json['balance_due'] != null ? double.tryParse(json['balance_due'].toString()) : null,
      items: json['items'] as List<dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'transaction_type': transactionType,
      'amount': amount,
      'notes': notes,
      'receipt_number': receiptNumber,
      'created_at': createdAt,
      'receipt_link': receiptLink,
      'customer_name': customerName,
      'invoice_date': invoiceDate,
      'upload_date': uploadDate,
      'mobile_number': mobileNumber,
      'payment_mode': paymentMode,
      'type': type,
      'received_amount': receivedAmount,
      'balance_due': balanceDue,
      'items': items,
    };
  }
}
