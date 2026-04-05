import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
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

  String _fmt(double? v) {
    if (v == null) return '0.00';
    final s = v.toStringAsFixed(2);
    return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
  }

  @override
  Widget build(BuildContext context) {
    final hasMismatch = item.amountMismatch.abs() > 1.0;
    // or if item.needsReview is explicitly true
    final needsReview = hasMismatch || (item.needsReview ?? false);

    Color borderColor = AppTheme.border;
    Color bgColor = Colors.white;
    if (needsReview) {
      borderColor = Colors.red.shade200;
      bgColor = Colors.red.shade50;
    }

    // Determine tax details (omitted, unused)
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: needsReview ? 1.5 : 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const Spacer(),
              if (needsReview)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.alertTriangle, size: 10, color: Colors.red.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Review Needed',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(LucideIcons.edit2, size: 14, color: Colors.blue.shade600),
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
            ],
          ),
          const SizedBox(height: 8),
          
          // Description
          Text(
            item.description,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          // Qty & Rate & Gross
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetric('Qty', _fmt(item.qty)),
              const Text('×', style: TextStyle(color: AppTheme.textSecondary)),
              _buildMetric('Rate', '₹${_fmt(item.rate)}'),
              const Text('=', style: TextStyle(color: AppTheme.textSecondary)),
              _buildMetric('Gross', '₹${_fmt(item.grossAmount ?? (item.qty * item.rate))}', isBold: true),
            ],
          ),
          
          const Divider(height: 16),

          // Discount & Tax & Net
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetric('Discount', '-₹${_fmt(item.discAmount ?? 0)}', color: Colors.green.shade700),
              _buildMetric('Taxable', '₹${_fmt(item.taxableAmount ?? item.grossAmount)}'),
              _buildMetric('Tax', '+₹${_fmt((item.cgstAmount ?? 0) + (item.sgstAmount ?? 0) + (item.igstAmount ?? 0))}', color: Colors.orange.shade700),
              _buildMetric('Net', '₹${_fmt(item.netAmount ?? item.netBill)}', isBold: true, color: AppTheme.primary),
            ],
          ),

          if (needsReview && item.printedTotal != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.calculator, size: 14, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Calculated Net (₹${_fmt(item.netAmount)}) does not match Printed Total (₹${_fmt(item.printedTotal)}). Difference: ₹${_fmt(item.amountMismatch)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                ],
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, {bool isBold = false, Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: color ?? AppTheme.textPrimary,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
