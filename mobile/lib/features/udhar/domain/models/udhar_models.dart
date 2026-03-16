class CustomerLedger {
  final int id;
  final String customerName;
  final String? customerPhone;
  final double balanceDue;
  final DateTime? lastPaymentDate;

  CustomerLedger({
    required this.id,
    required this.customerName,
    this.customerPhone,
    required this.balanceDue,
    this.lastPaymentDate,
  });

  factory CustomerLedger.fromJson(Map<String, dynamic> json) {
    return CustomerLedger(
      id: json['id'],
      customerName: json['customer_name'] ?? 'Unknown',
      customerPhone: json['customer_phone'],
      balanceDue: double.tryParse(json['balance_due']?.toString() ?? '0') ?? 0.0,
      lastPaymentDate: json['last_payment_date'] != null 
          ? DateTime.parse(json['last_payment_date']) 
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

  LedgerTransaction({
    required this.id,
    required this.ledgerId,
    required this.transactionType,
    required this.amount,
    this.receiptNumber,
    this.notes,
    required this.createdAt,
  });

  factory LedgerTransaction.fromJson(Map<String, dynamic> json) {
    return LedgerTransaction(
      id: json['id'],
      ledgerId: json['ledger_id'],
      transactionType: json['transaction_type'] ?? 'UNKNOWN',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      receiptNumber: json['receipt_number'],
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
