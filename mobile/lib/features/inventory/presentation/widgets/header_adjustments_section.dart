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

  @override
  Widget build(BuildContext context) {
    if (adjustments.isEmpty) return const SizedBox.shrink();

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
            final isNeg = adj.amount < 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    (adj.description != null && adj.description!.isNotEmpty) ? adj.description! : adj.adjustmentType,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    '${isNeg ? '-' : '+'}₹${_fmt(adj.amount.abs())}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isNeg ? Colors.green.shade700 : AppTheme.textPrimary,
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
                '₹${_fmt(adjustments.fold<double>(0.0, (sum, item) => sum + item.amount))}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
