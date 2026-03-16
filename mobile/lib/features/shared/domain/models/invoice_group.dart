import 'package:mobile/features/verified/domain/models/verified_models.dart';

class InvoiceGroup {
  String receiptNumber;
  String date;
  String receiptLink;
  String customerName;
  String vehicleNumber;
  String mobileNumber;
  String uploadDate;
  double totalAmount = 0;
  List<VerifiedInvoice> items = [];

  InvoiceGroup({
    required this.receiptNumber,
    required this.date,
    required this.receiptLink,
    required this.customerName,
    required this.vehicleNumber,
    required this.mobileNumber,
    required this.uploadDate,
  });
}
