import 'package:mobile/features/inventory/domain/models/invoice_item_v2_model.dart';

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
  final String?
      createdAt; // Track when item was created for batch identification

  // v2.1 new fields
  final double? grossAmount;
  final String? discType;
  final double? discPercent;  // disc_percent from DB (stored % value)
  final double? discAmount;
  final double? cgstPercent;  // cgst_percent from DB
  final double? sgstPercent;  // sgst_percent from DB
  final double? igstPercent;
  final double? igstAmount;
  final double? cgstAmount;
  final double? sgstAmount;
  final double? netAmount;
  final double? printedTotal;
  final bool? needsReview;
  final String? taxType;
  final String? vendorGstin;
  final String? placeOfSupply;
  final String? hsnCode;
  final double? taxableAmount;
  final int? confidenceScore;
  final List<HeaderAdjustment>? headerAdjustments;
  final double? previousRate;
  final double? priceHikeAmount;
  final String? paymentMode;

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
    this.createdAt,
    this.grossAmount,
    this.discType,
    this.discPercent,
    this.discAmount,
    this.cgstPercent,
    this.sgstPercent,
    this.igstPercent,
    this.igstAmount,
    this.cgstAmount,
    this.sgstAmount,
    this.netAmount,
    this.printedTotal,
    this.needsReview,
    this.taxType,
    this.vendorGstin,
    this.placeOfSupply,
    this.hsnCode,
    this.taxableAmount,
    this.confidenceScore,
    this.headerAdjustments,
    this.previousRate,
    this.priceHikeAmount,
    this.paymentMode,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    List<HeaderAdjustment>? parsedAdjustments;
    if (json['header_adjustments'] != null) {
      if (json['header_adjustments'] is List) {
        parsedAdjustments = (json['header_adjustments'] as List)
            .map((e) => HeaderAdjustment.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }

    // Sometimes confidence score comes as row_accuracy in legacy API responses
    int? parsedConfidenceScore = json['confidence_score'] != null
        ? int.tryParse(json['confidence_score'].toString())
        : (json['row_accuracy'] != null
            ? double.tryParse(json['row_accuracy'].toString())?.toInt()
            : null);

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
      amountMismatch: double.tryParse(json['amount_mismatch']?.toString() ??
              json['mismatch_amount']?.toString() ??
              '0') ??
          0.0,
      receiptLink: json['receipt_link']?.toString() ?? '',
      uploadDate: json['upload_date']?.toString(),
      verificationStatus: json['verification_status']?.toString(),
      rowAccuracy: json['row_accuracy'] != null
          ? double.tryParse(json['row_accuracy'].toString())
          : null,
      createdAt: json['created_at']?.toString(),

      // v2 parse
      grossAmount: json['gross_amount'] != null
          ? double.tryParse(json['gross_amount'].toString())
          : null,
      discType: json['disc_type']?.toString(),
      discPercent: json['disc_percent'] != null
          ? double.tryParse(json['disc_percent'].toString())
          : null,
      discAmount: json['disc_amount'] != null
          ? double.tryParse(json['disc_amount'].toString())
          : null,
      cgstPercent: json['cgst_percent'] != null
          ? double.tryParse(json['cgst_percent'].toString())
          : null,
      sgstPercent: json['sgst_percent'] != null
          ? double.tryParse(json['sgst_percent'].toString())
          : null,
      igstPercent: json['igst_percent'] != null
          ? double.tryParse(json['igst_percent'].toString())
          : null,
      igstAmount: json['igst_amount'] != null
          ? double.tryParse(json['igst_amount'].toString())
          : null,
      cgstAmount: json['cgst_amount'] != null
          ? double.tryParse(json['cgst_amount'].toString())
          : null,
      sgstAmount: json['sgst_amount'] != null
          ? double.tryParse(json['sgst_amount'].toString())
          : null,
      netAmount: json['net_amount'] != null
          ? double.tryParse(json['net_amount'].toString())
          : null,
      printedTotal: json['printed_total'] != null
          ? double.tryParse(json['printed_total'].toString())
          : null,
      needsReview: json['needs_review'] is bool
          ? json['needs_review']
          : (json['needs_review']?.toString() == 'true'),
      taxType: json['tax_type']?.toString(),
      vendorGstin: json['vendor_gstin']?.toString(),
      placeOfSupply: json['place_of_supply']?.toString(),
      hsnCode: json['hsn_code']?.toString() ?? json['hsn']?.toString(),
      taxableAmount: json['taxable_amount'] != null
          ? double.tryParse(json['taxable_amount'].toString())
          : null,
      confidenceScore: parsedConfidenceScore,
      headerAdjustments: parsedAdjustments,
      previousRate: json['previous_rate'] != null
          ? double.tryParse(json['previous_rate'].toString())
          : null,
      priceHikeAmount: json['price_hike_amount'] != null
          ? double.tryParse(json['price_hike_amount'].toString())
          : null,
      paymentMode: json['inventory_invoices'] != null &&
              json['inventory_invoices']['payment_mode'] != null
          ? json['inventory_invoices']['payment_mode'].toString()
          : json['payment_mode']?.toString(),
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
      'created_at': createdAt,
      'gross_amount': grossAmount,
      'disc_type': discType,
      'disc_percent': discPercent,
      'disc_amount': discAmount,
      'cgst_percent': cgstPercent,
      'sgst_percent': sgstPercent,
      'igst_percent': igstPercent,
      'igst_amount': igstAmount,
      'cgst_amount': cgstAmount,
      'sgst_amount': sgstAmount,
      'net_amount': netAmount,
      'printed_total': printedTotal,
      'needs_review': needsReview,
      'tax_type': taxType,
      'vendor_gstin': vendorGstin,
      'place_of_supply': placeOfSupply,
      'hsn_code': hsnCode,
      'taxable_amount': taxableAmount,
      'confidence_score': confidenceScore,
      'header_adjustments': headerAdjustments?.map((e) => e.toJson()).toList(),
      'previous_rate': previousRate,
      'price_hike_amount': priceHikeAmount,
      'payment_mode': paymentMode,
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
    String? createdAt,
    double? grossAmount,
    String? discType,
    double? discPercent,
    double? discAmount,
    double? cgstPercent,
    double? sgstPercent,
    double? igstPercent,
    double? igstAmount,
    double? cgstAmount,
    double? sgstAmount,
    double? netAmount,
    double? printedTotal,
    bool? needsReview,
    String? taxType,
    String? vendorGstin,
    String? placeOfSupply,
    String? hsnCode,
    double? taxableAmount,
    int? confidenceScore,
    List<HeaderAdjustment>? headerAdjustments,
    double? previousRate,
    double? priceHikeAmount,
    String? paymentMode,
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
      createdAt: createdAt ?? this.createdAt,
      grossAmount: grossAmount ?? this.grossAmount,
      discType: discType ?? this.discType,
      discPercent: discPercent ?? this.discPercent,
      discAmount: discAmount ?? this.discAmount,
      cgstPercent: cgstPercent ?? this.cgstPercent,
      sgstPercent: sgstPercent ?? this.sgstPercent,
      igstPercent: igstPercent ?? this.igstPercent,
      igstAmount: igstAmount ?? this.igstAmount,
      cgstAmount: cgstAmount ?? this.cgstAmount,
      sgstAmount: sgstAmount ?? this.sgstAmount,
      netAmount: netAmount ?? this.netAmount,
      printedTotal: printedTotal ?? this.printedTotal,
      needsReview: needsReview ?? this.needsReview,
      taxType: taxType ?? this.taxType,
      vendorGstin: vendorGstin ?? this.vendorGstin,
      placeOfSupply: placeOfSupply ?? this.placeOfSupply,
      hsnCode: hsnCode ?? this.hsnCode,
      taxableAmount: taxableAmount ?? this.taxableAmount,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      headerAdjustments: headerAdjustments ?? this.headerAdjustments,
      previousRate: previousRate ?? this.previousRate,
      priceHikeAmount: priceHikeAmount ?? this.priceHikeAmount,
      paymentMode: paymentMode ?? this.paymentMode,
    );
  }
}
