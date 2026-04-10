import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/inventory/domain/models/invoice_item_v2_model.dart';

class HeaderAdjustmentsSection extends StatelessWidget {
  final List<HeaderAdjustment> adjustments;

  const HeaderAdjustmentsSection({
    super.key,
    required this.adjustments,
  });

  String _fmt(double? v) {
    if (v == null) return '0.00';
    final s = v.toStringAsFixed(2);
    return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
  }

  /// Returns the effective signed amount for a given adjustment.
  /// HEADER_DISCOUNT and SCHEME are always deductions regardless of stored sign.
  /// ROUND_OFF can be +/- as stored.
  /// OTHER can be +/- as stored.
  double _effectiveAmount(HeaderAdjustment adj) {
    final type = adj.adjustmentType.toUpperCase();
    if (type == 'HEADER_DISCOUNT' || type == 'SCHEME') {
      // These are always discounts — stored as positive by Gemini, but they reduce total
      return -adj.amount.abs();
    }
    return adj.amount; // ROUND_OFF, OTHER: use as-is
  }

  @override
  Widget build(BuildContext context) {
    if (adjustments.isEmpty) return const SizedBox.shrink();

    final netTotal = adjustments.fold<double>(0.0, (sum, adj) => sum + _effectiveAmount(adj));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Extras & Adjustments',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...adjustments.map((adj) {
            final effective = _effectiveAmount(adj);
            final isDeduction = effective < 0;
            final label = (adj.description != null && adj.description!.isNotEmpty)
                ? adj.description!
                : adj.adjustmentType;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    '${isDeduction ? '-' : '+'}₹${_fmt(effective.abs())}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDeduction ? Colors.green.shade700 : AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Adjustments',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '${netTotal < 0 ? '-' : '+'}₹${_fmt(netTotal.abs())}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: netTotal < 0 ? Colors.green.shade700 : AppTheme.primary,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
