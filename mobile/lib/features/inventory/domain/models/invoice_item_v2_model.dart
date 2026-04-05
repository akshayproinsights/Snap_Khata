class HeaderAdjustment {
  final String adjustmentType; // HEADER_DISCOUNT | ROUND_OFF | SCHEME | OTHER
  final double amount; // positive = add, negative = deduct
  final String? description;

  HeaderAdjustment({
    required this.adjustmentType,
    required this.amount,
    this.description,
  });

  factory HeaderAdjustment.fromJson(Map<String, dynamic> json) {
    return HeaderAdjustment(
      adjustmentType: json['adjustment_type']?.toString() ?? 'OTHER',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      description: json['description']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'adjustment_type': adjustmentType,
      'amount': amount,
      'description': description,
    };
  }

  HeaderAdjustment copyWith({
    String? adjustmentType,
    double? amount,
    String? description,
  }) {
    return HeaderAdjustment(
      adjustmentType: adjustmentType ?? this.adjustmentType,
      amount: amount ?? this.amount,
      description: description ?? this.description,
    );
  }
}
