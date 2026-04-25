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
  }) = _CustomerActivity;

  const factory ActivityItem.vendor({
    required String id,
    required String entityName,
    required DateTime transactionDate,
    required double amount,
    String? displayId,
    required bool isPaid,
    double? balanceDue,
  }) = _VendorActivity;

  factory ActivityItem.fromJson(Map<String, dynamic> json) => _$ActivityItemFromJson(json);

  /// Formats the amount as a whole number with currency symbol (e.g., ₹78,444).
  /// Indian numbering system is used for readability.
  String get formattedAmount {
    return CurrencyFormatter.format(amount);
  }
}
