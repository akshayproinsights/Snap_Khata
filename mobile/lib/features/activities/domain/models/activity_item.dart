import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobile/core/utils/currency_formatter.dart';

part 'activity_item.freezed.dart';
part 'activity_item.g.dart';

@freezed
abstract class ActivityItem with _$ActivityItem {
  const ActivityItem._();

  const factory ActivityItem.customer({
    required String id,
    required String entityName,
    required DateTime transactionDate,
    required double amount,
    String? displayId,
    required String transactionType,
    double? balanceDue,
    // Navigation context — populated from verified_invoices enrichment
    @Default('') String receiptLink,
    @Default('') String invoiceDate,
    @Default('') String mobileNumber,
    @Default('Cash') String paymentMode,
    @Default(0.0) double invoiceBalanceDue,
    @Default(0.0) double receivedAmount,
  }) = _CustomerActivity;

  const factory ActivityItem.vendor({
    required String id,
    required String entityName,
    required DateTime transactionDate,
    required double amount,
    String? displayId,
    required bool isPaid,
    double? balanceDue,
    @Default(0.0) double totalPriceHike,
    // Navigation context — populated from inventory_items enrichment
    @Default('') String receiptLink,
    @Default('') String invoiceDate,
    @Default([]) List<Map<String, dynamic>> inventoryItems,
    @Default(false) bool isVerified,
    @Default(0.0) double balanceOwed,
  }) = _VendorActivity;

  factory ActivityItem.fromJson(Map<String, dynamic> json) => _$ActivityItemFromJson(json);

  /// Formats the amount as a whole number with currency symbol (e.g., ₹78,444).
  /// Indian numbering system is used for readability.
  String get formattedAmount {
    return CurrencyFormatter.format(amount);
  }
}
