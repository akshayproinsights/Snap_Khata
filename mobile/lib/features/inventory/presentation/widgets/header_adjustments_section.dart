import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/inventory/domain/models/invoice_item_v2_model.dart';
import 'package:lucide_icons/lucide_icons.dart';

class HeaderAdjustmentsSection extends StatelessWidget {
  final List<HeaderAdjustment> adjustments;
  final Function(int index, HeaderAdjustment updated)? onEdit;

  /// True  → Scenario A: per-item discounts exist; HEADER_DISCOUNT is a
  ///          summary already baked into item netAmounts → show greyed "in items".
  /// False → Scenario B: no per-item discount; HEADER_DISCOUNT is applied at
  ///          the grand-total level (before GST) → show as an active deduction.
  final bool hasPerItemDiscount;

  const HeaderAdjustmentsSection({
    super.key,
    required this.adjustments,
    required this.hasPerItemDiscount,
    this.onEdit,
  });

  String _fmt(double? v) {
    if (v == null) return '0.00';
    final s = v.toStringAsFixed(2);
    return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
  }

  /// Whether a HEADER_DISCOUNT/SCHEME adjustment is already baked into items.
  /// In Scenario A (per-item discount): treat as informational / greyed out.
  /// In Scenario B (header-only discount): treat as an active deduction.
  bool _isAlreadyInItems(HeaderAdjustment adj) {
    final type = adj.adjustmentType.toUpperCase();
    return hasPerItemDiscount &&
        (type == 'HEADER_DISCOUNT' || type == 'SCHEME');
  }

  /// Effective signed amount used only when the adjustment is NOT already in items.
  double _effectiveAmount(HeaderAdjustment adj) {
    final type = adj.adjustmentType.toUpperCase();
    // HEADER_DISCOUNT and SCHEME are always deductions.
    if (type == 'HEADER_DISCOUNT' || type == 'SCHEME') {
      return -adj.amount.abs();
    }
    return adj.amount; // ROUND_OFF, OTHER: use stored sign
  }

  @override
  Widget build(BuildContext context) {
    if (adjustments.isEmpty) return const SizedBox.shrink();

    // Total Adjustments row shows only what actually affects the grand total:
    //  • Scenario A: HEADER_DISCOUNT/SCHEME already in items → only ROUND_OFF/OTHER
    //  • Scenario B: HEADER_DISCOUNT/SCHEME are real deductions → include them
    final displayedTotal = adjustments.fold<double>(0.0, (sum, adj) {
      if (_isAlreadyInItems(adj)) return sum; // greyed out — don't count
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
          ...List.generate(adjustments.length, (index) {
            final adj = adjustments[index];
            final alreadyInItems = _isAlreadyInItems(adj);
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
                  InkWell(
                    onTap: (alreadyInItems || onEdit == null) 
                        ? null 
                        : () => onEdit!(index, adj),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            alreadyInItems
                                // Greyed display — show the stored value but muted
                                ? '-₹${_fmt(adj.amount.abs())}'
                                : '${isDeduction ? '-' : '+'}₹${_fmt(effective.abs())}',
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
                          if (!alreadyInItems && onEdit != null) ...[
                            const SizedBox(width: 4),
                            Icon(LucideIcons.edit3, size: 10, color: AppTheme.primary.withValues(alpha: 0.5)),
                          ],
                        ],
                      ),
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
                displayedTotal == 0.0
                    ? '₹0'
                    : '${displayedTotal < 0 ? '-' : '+'}₹${_fmt(displayedTotal.abs())}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: displayedTotal < 0
                      ? Colors.green.shade700
                      : (displayedTotal > 0
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
