import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/context_extension.dart';
import 'package:mobile/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:mobile/features/udhar/presentation/providers/unified_party_provider.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:flutter/services.dart';

class SmartInsightsBanner extends ConsumerWidget {
  const SmartInsightsBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplierPending = ref.watch(pendingSupplierReviewsProvider);
    final customerPending = ref.watch(pendingCustomerReviewsProvider);
    final parties = ref.watch(unifiedPartiesProvider);

    final totalPending = supplierPending + customerPending;
    
    // Find highest due party
    final highestDueParty = parties.isNotEmpty 
        ? parties.firstWhere((p) => p.balance.abs() > 0.01, orElse: () => parties.first)
        : null;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (totalPending > 0)
            _InsightCard(
              icon: LucideIcons.alertCircle,
              title: '$totalPending Pending Reviews',
              subtitle: 'Data needs verification',
              color: context.warningColor,
              onTap: () {
                HapticFeedback.mediumImpact();
                // We'll show the review center sheet or navigate
                // For now, let's keep it simple and just trigger the review flow
              },
            ),
          
          if (highestDueParty != null && highestDueParty.balance.abs() > 100) ...[
            const SizedBox(width: 12),
            _InsightCard(
              icon: LucideIcons.trendingUp,
              title: CurrencyFormatter.format(highestDueParty.balance.abs()),
              subtitle: 'Due from ${highestDueParty.name}',
              color: highestDueParty.balance < 0 ? context.errorColor : context.successColor,
              onTap: () {
                 HapticFeedback.lightImpact();
                 // Navigate to party detail
              },
            ),
          ],

          const SizedBox(width: 12),
          _InsightCard(
            icon: LucideIcons.sparkles,
            title: 'Top 1% SaaS',
            subtitle: 'Snap Khata is active',
            color: context.primaryColor,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _InsightCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(minWidth: 180),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: context.textColor,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: context.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
