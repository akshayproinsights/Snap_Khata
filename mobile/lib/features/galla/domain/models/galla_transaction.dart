class GallaTransaction {
  final int id;
  final String username;
  final String transactionType;
  final double amount;
  final String? notes;
  final String? receiptNumber;
  final String createdAt;

  GallaTransaction({
    required this.id,
    required this.username,
    required this.transactionType,
    required this.amount,
    this.notes,
    this.receiptNumber,
    required this.createdAt,
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
    };
  }
}
