class VendorLedger {
  final int id;
  final String vendorName;
  final double balanceDue;
  final DateTime? lastPaymentDate;
  final String? latestBillNumber;
  final double? latestBillAmount;
  final DateTime? latestBillDate;
  final DateTime? latestUploadDate;

  VendorLedger({
    required this.id,
    required this.vendorName,
    required this.balanceDue,
    this.lastPaymentDate,
    this.latestBillNumber,
    this.latestBillAmount,
    this.latestBillDate,
    this.latestUploadDate,
  });

  factory VendorLedger.fromJson(Map<String, dynamic> json) {
    return VendorLedger(
      id: json['id'],
      vendorName: json['vendor_name'] ?? 'Unknown Vendor',
      balanceDue: double.tryParse(json['balance_due']?.toString() ?? '0') ?? 0.0,
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
    );
  }
}

class VendorLedgerTransaction {
  final int id;
  final int ledgerId;
  final String transactionType; // 'INVOICE' or 'PAYMENT'
  final double amount;
  final String? invoiceNumber;
  final String? notes;
  final DateTime createdAt;
  final bool isPaid;
  final int? linkedTransactionId;
  final String? receiptLink;

  VendorLedgerTransaction({
    required this.id,
    required this.ledgerId,
    required this.transactionType,
    required this.amount,
    this.invoiceNumber,
    this.notes,
    required this.createdAt,
    this.isPaid = false,
    this.linkedTransactionId,
    this.receiptLink,
  });

  factory VendorLedgerTransaction.fromJson(Map<String, dynamic> json) {
    return VendorLedgerTransaction(
      id: json['id'],
      ledgerId: json['ledger_id'],
      transactionType: json['transaction_type'] ?? 'UNKNOWN',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      invoiceNumber: json['invoice_number'],
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
      isPaid: json['is_paid'] ?? false,
      linkedTransactionId: json['linked_transaction_id'],
      receiptLink: json['receipt_link'],
    );
  }
}
