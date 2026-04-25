import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile/features/activities/domain/models/activity_item.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';

/// Renders a vendor (payable) transaction row.
/// Amounts are formatted with zero decimal digits per SnapKhata UI guidelines.
class VendorActivityCard extends StatelessWidget {
  const VendorActivityCard({super.key, required this.item});

  /// The vendor variant of [ActivityItem].
  final ActivityItem item;

  static final _dateFormatter = DateFormat('MMM d, h:mm a');

  @override
  Widget build(BuildContext context) {
    return item.maybeWhen(
      vendor: (id, entityName, transactionDate, amount, displayId, isPaid, balanceDue) {
        return Container(
          decoration: BoxDecoration(
            color: context.surfaceColor,
            border: Border(
              bottom: BorderSide(color: context.borderColor.withValues(alpha: 0.5), width: 1),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                // ── Avatar ──────────────────────────────────────────────
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.inventory_2_outlined, // using material icon or Lucide
                    color: context.primaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                // ── Entity name + date ───────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entityName,
                        style: TextStyle(
                          color: context.textColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'Supplier • ${_dateFormatter.format(transactionDate)}',
                            style: TextStyle(
                              color: context.textSecondaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (displayId != null) ...[
                            const SizedBox(width: 4),
                            Text(
                              '• #$displayId',
                              style: TextStyle(
                                color: context.textSecondaryColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // ── Amount & Badge ───────────────────────────────────────────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.format(amount),
                      style: TextStyle(
                        color: context.textColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _StatusChip(isPaid: isPaid, balanceDue: balanceDue),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// Pill chip showing paid/unpaid status or balance due for vendor transactions.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isPaid, this.balanceDue});
  final bool isPaid;
  final double? balanceDue;

  @override
  Widget build(BuildContext context) {
    // If there's a positive balance due, we show "Due: ₹X" instead of "UNPAID"
    final hasDue = balanceDue != null && balanceDue! > 0;
    final color = hasDue ? context.warningColor : (isPaid ? context.successColor : context.errorColor);
    final label = hasDue ? 'Due: ${CurrencyFormatter.format(balanceDue!)}' : (isPaid ? 'PAID' : 'SETTLED');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
