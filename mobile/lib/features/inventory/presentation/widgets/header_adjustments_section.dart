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
      return -adj.amount.abs();
    }
    return adj.amount; // ROUND_OFF, OTHER: use as-is
  }

  /// HEADER_DISCOUNT and SCHEME are already baked into each item's netAmount
  /// by the math engine. They should NOT be re-subtracted at the header level.
  bool _isAlreadyInItems(HeaderAdjustment adj) {
    final type = adj.adjustmentType.toUpperCase();
    return type == 'HEADER_DISCOUNT' || type == 'SCHEME';
  }

  @override
  Widget build(BuildContext context) {
    if (adjustments.isEmpty) return const SizedBox.shrink();

    // Only ROUND_OFF / OTHER contribute to the displayed grand-total adjustment.
    // HEADER_DISCOUNT / SCHEME are already embedded in each item's netAmount.
    final additiveTotal = adjustments.fold<double>(0.0, (sum, adj) {
      if (_isAlreadyInItems(adj)) return sum;
      return sum + _effectiveAmount(adj);
    });

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
            final alreadyInItems = _isAlreadyInItems(adj);
            final label = (adj.description != null && adj.description!.isNotEmpty)
                ? adj.description!
                : adj.adjustmentType;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              color: alreadyInItems
                                  ? Colors.grey.shade400
                                  : AppTheme.textSecondary,
                              fontStyle: alreadyInItems
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                        ),
                        if (alreadyInItems) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              'in items',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    '${isDeduction ? '-' : '+'}₹${_fmt(effective.abs())}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: alreadyInItems
                          ? Colors.grey.shade400
                          : (isDeduction
                              ? Colors.green.shade700
                              : AppTheme.textPrimary),
                      fontStyle: alreadyInItems
                          ? FontStyle.italic
                          : FontStyle.normal,
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
                additiveTotal == 0.0
                    ? '₹0'
                    : '${additiveTotal < 0 ? '-' : '+'}₹${_fmt(additiveTotal.abs())}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: additiveTotal < 0
                      ? Colors.green.shade700
                      : (additiveTotal > 0
                          ? AppTheme.primary
                          : AppTheme.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
