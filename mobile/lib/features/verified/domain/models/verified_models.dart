class VerifiedInvoice {
  final String rowId;
  final String receiptNumber;
  final String date;
  final String customerName;
  final String vehicleNumber;
  final String mobileNumber;
  final String description;
  final String type;
  final double quantity;
  final double rate;
  final double amount;
  final String receiptLink;
  final String uploadDate;

  VerifiedInvoice({
    required this.rowId,
    required this.receiptNumber,
    required this.date,
    required this.customerName,
    required this.vehicleNumber,
    required this.mobileNumber,
    required this.description,
    required this.type,
    required this.quantity,
    required this.rate,
    required this.amount,
    required this.receiptLink,
    required this.uploadDate,
  });

  factory VerifiedInvoice.fromJson(Map<String, dynamic> json) {
    // API returns snake_case keys from Supabase; fall back to Title Case for legacy compatibility
    return VerifiedInvoice(
      rowId: json['row_id']?.toString() ?? json['Row_Id']?.toString() ?? '',
      receiptNumber: json['receipt_number']?.toString() ??
          json['Receipt Number']?.toString() ??
          '',
      date: json['date']?.toString() ?? json['Date']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ??
          json['Customer Name']?.toString() ??
          '',
      vehicleNumber: json['car_number']?.toString() ??
          json['vehicle_number']?.toString() ??
          json['Vehicle Number']?.toString() ??
          json['Car Number']?.toString() ??
          '',
      mobileNumber: json['mobile_number']?.toString() ??
          json['Mobile Number']?.toString() ??
          json['mobile']?.toString() ??
          '',
      description: json['description']?.toString() ??
          json['Description']?.toString() ??
          '',
      type: json['type']?.toString() ?? json['Type']?.toString() ?? '',
      quantity: double.tryParse(
              (json['quantity'] ?? json['Quantity'])?.toString() ?? '0') ??
          0.0,
      rate:
          double.tryParse((json['rate'] ?? json['Rate'])?.toString() ?? '0') ??
              0.0,
      amount: double.tryParse(
              (json['amount'] ?? json['Amount'])?.toString() ?? '0') ??
          0.0,
      receiptLink: json['receipt_link']?.toString() ??
          json['Receipt Link']?.toString() ??
          '',
      uploadDate: json['upload_date']?.toString() ??
          json['Upload Date']?.toString() ??
          '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'row_id': rowId,
      'receipt_number': receiptNumber,
      'date': date,
      'customer_name': customerName,
      'car_number':
          vehicleNumber, // Backend handles either car_number or vehicle_number, but update requires actual DB col
      'mobile_number': mobileNumber,
      'description': description,
      'type': type,
      'quantity': quantity,
      'rate': rate,
      'amount': amount,
      'receipt_link': receiptLink,
      'upload_date': uploadDate,
    };
  }

  VerifiedInvoice copyWith({
    String? rowId,
    String? receiptNumber,
    String? date,
    String? customerName,
    String? vehicleNumber,
    String? mobileNumber,
    String? description,
    String? type,
    double? quantity,
    double? rate,
    double? amount,
    String? receiptLink,
    String? uploadDate,
  }) {
    return VerifiedInvoice(
      rowId: rowId ?? this.rowId,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      date: date ?? this.date,
      customerName: customerName ?? this.customerName,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      description: description ?? this.description,
      type: type ?? this.type,
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
      amount: amount ?? this.amount,
      receiptLink: receiptLink ?? this.receiptLink,
      uploadDate: uploadDate ?? this.uploadDate,
    );
  }
}
