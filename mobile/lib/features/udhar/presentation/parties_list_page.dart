import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/udhar/domain/models/unified_ledger.dart';
import 'package:mobile/features/udhar/presentation/providers/unified_ledger_provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class PartiesListPage extends ConsumerWidget {
  const PartiesListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgers = ref.watch(unifiedLedgerProvider);

    if (ledgers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                shape: BoxShape.circle,
                boxShadow: context.premiumShadow,
              ),
              child: Icon(LucideIcons.users, size: 48, color: context.borderColor),
            ),
            const SizedBox(height: 24),
            Text(
              'No parties found',
              style: TextStyle(
                color: context.textSecondaryColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first customer or supplier',
              style: TextStyle(
                color: context.textSecondaryColor.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: ledgers.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final ledger = ledgers[index];
        return _buildLedgerCard(context, ledger);
      },
    );
  }

  Widget _buildLedgerCard(BuildContext context, UnifiedLedger ledger) {
    final bool isCustomer = ledger.type == LedgerType.customer;
    final bool isDue = ledger.balanceDue > 0;
    
    final Color statusColor = isCustomer 
        ? (isDue ? context.successColor : context.textSecondaryColor)
        : (isDue ? context.errorColor : context.textSecondaryColor);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: context.premiumShadow,
        border: Border.all(color: context.borderColor.withValues(alpha: 0.5), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.lightImpact();
            if (isCustomer) {
              context.pushNamed(
                'party-detail',
                pathParameters: {'id': ledger.id.toString()},
                extra: ledger.originalLedger,
              );
            } else {
              context.pushNamed(
                'vendor-ledger-detail',
                pathParameters: {'id': ledger.id.toString()},
                extra: ledger.originalLedger,
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar with character
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        context.primaryColor.withValues(alpha: 0.1),
                        context.primaryColor.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      ledger.name.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: context.primaryColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              ledger.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                letterSpacing: -0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!isCustomer) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: context.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'SUPPLIER',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: context.primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(LucideIcons.clock, size: 12, color: context.textSecondaryColor),
                          const SizedBox(width: 4),
                          Text(
                            ledger.lastActivityDate != null
                                ? timeago.format(ledger.lastActivityDate!)
                                : 'No activity yet',
                            style: TextStyle(
                              color: context.textSecondaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Balance
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.format(ledger.balanceDue),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        color: statusColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isCustomer ? (isDue ? 'YOU GET' : 'SETTLED') : (isDue ? 'YOU GIVE' : 'SETTLED'),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(width: 4),
                Icon(
                  LucideIcons.chevronRight, 
                  size: 16, 
                  color: context.borderColor
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
