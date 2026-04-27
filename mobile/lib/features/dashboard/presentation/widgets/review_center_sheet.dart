import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:go_router/go_router.dart';

class ReviewCenterSheet extends ConsumerWidget {
  const ReviewCenterSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplierCount = ref.watch(pendingSupplierReviewsProvider);
    final customerCount = ref.watch(pendingCustomerReviewsProvider);

    return Container(
      decoration: BoxDecoration(
        color: context.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(LucideIcons.clipboardCheck, color: context.primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REVIEW CENTER',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: context.textSecondaryColor,
                      ),
                    ),
                    Text(
                      'What would you like to verify?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: context.textColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _ReviewCard(
                  title: 'Supplier (Purchases)',
                  subtitle: 'Verify items bought from suppliers to update your stock.',
                  count: supplierCount,
                  icon: LucideIcons.shoppingCart,
                  color: context.errorColor,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context);
                    context.push('/inventory-review');
                  },
                ),
                const SizedBox(height: 16),
                _ReviewCard(
                  title: 'Customer (Receipts)',
                  subtitle: 'Verify items sold to customers to track your earnings.',
                  count: customerCount,
                  icon: LucideIcons.banknote,
                  color: context.successColor,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context);
                    context.push('/review');
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ReviewCard({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.borderColor, width: 1),
          boxShadow: context.premiumShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: context.textColor,
                        ),
                      ),
                      if (count > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count PENDING',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textSecondaryColor,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, color: context.borderColor, size: 20),
          ],
        ),
      ),
    );
  }
}
