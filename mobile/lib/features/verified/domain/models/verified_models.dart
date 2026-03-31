class VerifiedInvoice {
  final String rowId;
  final String receiptNumber;
  final String date;
  final String customerName;
  final String mobileNumber;
  final String description;
  final String type;
  final double quantity;
  final double rate;
  final double amount;
  final String receiptLink;
  final String uploadDate;
  final String? gstMode;
  final String? taxableRowIds;
  final String? paymentMode;
  final double? receivedAmount;
  final double? balanceDue;
  final String? customerDetails;
  final Map<String, dynamic> extraFields;

  VerifiedInvoice({
    required this.rowId,
    required this.receiptNumber,
    required this.date,
    required this.customerName,
    required this.mobileNumber,
    required this.description,
    required this.type,
    required this.quantity,
    required this.rate,
    required this.amount,
    required this.receiptLink,
    required this.uploadDate,
    this.gstMode,
    this.taxableRowIds,
    this.paymentMode,
    this.receivedAmount,
    this.balanceDue,
    this.customerDetails,
    this.extraFields = const {},
  });

  factory VerifiedInvoice.fromJson(Map<String, dynamic> json) {
    // API returns snake_case keys from Supabase; fall back to Title Case for legacy compatibility
    final extra = json['extra_fields'] is Map ? Map<String, dynamic>.from(json['extra_fields']) : <String, dynamic>{};
    
    // MIGRATION: Scoop up legacy top-level vehicle fields into extra_fields
    final vehicleFields = ['car_number', 'vehicle_number', 'odometer', 'odometer_reading'];
    for (final field in vehicleFields) {
      if (json.containsKey(field) && json[field] != null && !extra.containsKey(field)) {
        extra[field] = json[field];
      }
    }
    
    return VerifiedInvoice(
      rowId: json['row_id']?.toString() ?? json['Row_Id']?.toString() ?? '',
      receiptNumber: json['receipt_number']?.toString() ??
          json['Receipt Number']?.toString() ??
          '',
      date: json['date']?.toString() ?? json['Date']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ??
          json['Customer Name']?.toString() ??
          '',
      mobileNumber: json['mobile_number']?.toString() ??
          json['Mobile Number']?.toString() ??
          json['mobile']?.toString() ??
          extra['mobile_number']?.toString() ??
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
      gstMode: json['gst_mode']?.toString(),
      taxableRowIds: json['taxable_row_ids']?.toString(),
      paymentMode: json['payment_mode']?.toString() ?? json['Payment Mode']?.toString(),
      receivedAmount: double.tryParse((json['received_amount'] ?? json['Received Amount'])?.toString() ?? ''),
      balanceDue: double.tryParse((json['balance_due'] ?? json['Balance Due'])?.toString() ?? ''),
      customerDetails: json['customer_details']?.toString() ?? json['Customer Details']?.toString(),
      extraFields: extra,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'row_id': rowId,
      'receipt_number': receiptNumber,
      'date': date,
      'customer_name': customerName,
      'mobile_number': mobileNumber,
      'description': description,
      'type': type,
      'quantity': quantity,
      'rate': rate,
      'amount': amount,
      'receipt_link': receiptLink,
      'upload_date': uploadDate,
      if (gstMode != null) 'gst_mode': gstMode,
      if (taxableRowIds != null) 'taxable_row_ids': taxableRowIds,
      if (paymentMode != null) 'payment_mode': paymentMode,
      if (receivedAmount != null) 'received_amount': receivedAmount,
      if (balanceDue != null) 'balance_due': balanceDue,
      if (customerDetails != null) 'customer_details': customerDetails,
      'extra_fields': extraFields,
    };
  }

  VerifiedInvoice copyWith({
    String? rowId,
    String? receiptNumber,
    String? date,
    String? customerName,
    String? mobileNumber,
    String? description,
    String? type,
    double? quantity,
    double? rate,
    double? amount,
    String? receiptLink,
    String? uploadDate,
    String? gstMode,
    String? taxableRowIds,
    String? paymentMode,
    double? receivedAmount,
    double? balanceDue,
    String? customerDetails,
    Map<String, dynamic>? extraFields,
  }) {
    return VerifiedInvoice(
      rowId: rowId ?? this.rowId,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      date: date ?? this.date,
      customerName: customerName ?? this.customerName,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      description: description ?? this.description,
      type: type ?? this.type,
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
      amount: amount ?? this.amount,
      receiptLink: receiptLink ?? this.receiptLink,
      uploadDate: uploadDate ?? this.uploadDate,
      gstMode: gstMode ?? this.gstMode,
      taxableRowIds: taxableRowIds ?? this.taxableRowIds,
      paymentMode: paymentMode ?? this.paymentMode,
      receivedAmount: receivedAmount ?? this.receivedAmount,
      balanceDue: balanceDue ?? this.balanceDue,
      customerDetails: customerDetails ?? this.customerDetails,
      extraFields: extraFields ?? this.extraFields,
    );
  }
}
