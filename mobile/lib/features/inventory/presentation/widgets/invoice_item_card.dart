import "package:mobile/core/theme/context_extension.dart";
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/inventory/domain/models/inventory_models.dart';

class InvoiceItemCard extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const InvoiceItemCard({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });


  @override
  Widget build(BuildContext context) {
    final hasMismatch = item.amountMismatch.abs() > 1.0;
    final needsReview = hasMismatch || (item.needsReview ?? false);
    final hasPriceHike = item.priceHikeAmount != null && item.priceHikeAmount! > 0;

    // Always use neutral card colors — mismatches are informational, not errors.
    // A tiny amber ⚠ triangle is shown instead of red UI to avoid scaring
    // non-technical SMB users.
    const Color borderColor = AppTheme.border;
    final Color bgColor = context.surfaceColor;

    // Determine tax details (omitted, unused)
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasPriceHike ? context.warningColor : borderColor,
          width: 1,
        ),
        boxShadow: context.premiumShadow,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.partNumber.isNotEmpty ? 'Part: ${item.partNumber}' : 'Item #${item.id}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: context.primaryColor,
                  ),
                ),
              ),
              const Spacer(),
              // Subtle amber triangle for mismatches — non-blocking, non-scary.
              // Replaces the aggressive red "Review Needed" badge.
              if (needsReview)
                Tooltip(
                  message: 'Check amount — calculated vs printed may differ',
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: context.warningColor,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(LucideIcons.trash2, size: 14, color: Colors.red.shade600),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(LucideIcons.edit2, size: 18, color: Colors.blue.shade600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Description
          Text(
            item.description,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.textColor,
            ),
          ),
          if (hasPriceHike) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.trendingUp, size: 14, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Last paid ${item.previousRate != null ? CurrencyFormatter.format(item.previousRate!) : '—'}. Increased by ${item.priceHikeAmount != null ? CurrencyFormatter.format(item.priceHikeAmount!) : '—'}.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.errorColor,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),

          // Qty & Rate & Gross
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetric(context, 'Qty', item.quantity.round().toString()),
              Text('×', style: TextStyle(color: context.textSecondaryColor)),
              _buildMetric(context, 'Rate', CurrencyFormatter.format(item.rate)),
              Text('=', style: TextStyle(color: context.textSecondaryColor)),
              _buildMetric(context, 'Gross', CurrencyFormatter.format(item.grossAmount ?? (item.quantity * item.rate)), isBold: true),
            ],
          ),
          
          const Divider(height: 16),

          // Discount & Tax & Net
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetric(context, 'Discount', '-${CurrencyFormatter.format(item.discAmount ?? 0)}', color: context.successColor),
              _buildMetric(context, 'Taxable', CurrencyFormatter.format(item.taxableAmount ?? item.grossAmount ?? 0.0)),
              _buildMetric(context, 'Tax', '+${CurrencyFormatter.format((item.cgstAmount ?? 0) + (item.sgstAmount ?? 0) + (item.igstAmount ?? 0))}', color: context.warningColor),
              _buildMetric(context, 'Net', CurrencyFormatter.format(item.netAmount ?? item.netBill), isBold: true, color: context.primaryColor),
            ],
          ),

        ],
      ),
    );
  }

  Widget _buildMetric(BuildContext context, String label, String value, {bool isBold = false, Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: context.textSecondaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: color ?? context.textColor,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
