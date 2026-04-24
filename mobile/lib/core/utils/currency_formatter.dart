import 'package:intl/intl.dart';

/// Centralized utility for currency and number formatting 
/// adhering to the "Zero Decimal Currency Rule".
class CurrencyFormatter {
  /// Formats amount in Indian Rupees with 0 decimal places.
  /// Example: 1200.50 -> ₹1,201
  static String format(double amount) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(amount);
  }

  /// Formats amount as a plain number (no symbol) with 0 decimal places.
  /// Example: 1200.50 -> 1,201
  static String formatPlain(double amount) {
    return NumberFormat.decimalPattern('en_IN').format(amount.round());
  }

  /// Formats percentage (like GST) preserving decimals if needed.
  /// Example: 12.5 -> 12.5%
  static String formatPercentage(double value) {
    final format = NumberFormat.decimalPattern('en_IN');
    return '${format.format(value)}%';
  }

  /// Formats amount in a compact way (e.g., 1.2k) with zero decimals for Indian currency.
  static String formatCompact(double amount) {
    return NumberFormat.compactCurrency(
      symbol: '₹',
      decimalDigits: 0,
      locale: 'en_IN',
    ).format(amount);
  }
}
