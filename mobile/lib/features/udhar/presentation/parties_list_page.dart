import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/udhar/domain/models/unified_ledger.dart';
import 'package:mobile/features/udhar/presentation/providers/unified_ledger_provider.dart';
import 'package:mobile/features/udhar/presentation/providers/udhar_provider.dart';
import 'package:mobile/features/inventory/presentation/providers/vendor_ledger_provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class PartiesListPage extends ConsumerStatefulWidget {
  const PartiesListPage({super.key});

  @override
  ConsumerState<PartiesListPage> createState() => _PartiesListPageState();
}

class _PartiesListPageState extends ConsumerState<PartiesListPage> {
  @override
  Widget build(BuildContext context) {
    final ledgers = ref.watch(unifiedLedgerProvider);
    final udharState = ref.watch(udharProvider);
    final vendorState = ref.watch(vendorLedgerProvider);
    final isLoading = udharState.isLoading || vendorState.isLoading;

    if (isLoading && ledgers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

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

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    UnifiedLedger ledger,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 32,
                left: 24,
                right: 24,
                top: 24,
              ),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Danger icon circle
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: context.errorColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.trash2,
                      color: context.errorColor,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Delete Party?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: context.textColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Party name badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: context.textSecondaryColor.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color:
                                context.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              ledger.name.substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                color: context.primaryColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          ledger.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: context.textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'This will permanently delete all transactions\nand payment history for this party.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.textSecondaryColor,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Delete CTA
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isDeleting
                          ? null
                          : () async {
                              setSheetState(() => isDeleting = true);
                              HapticFeedback.heavyImpact();
                              bool success;
                              if (ledger.type == LedgerType.customer) {
                                success = await ref
                                    .read(udharProvider.notifier)
                                    .deleteLedger(ledger.id);
                              } else {
                                success = await ref
                                    .read(vendorLedgerProvider.notifier)
                                    .deleteLedger(ledger.id);
                              }
                              if (!sheetCtx.mounted) return;
                              Navigator.pop(sheetCtx);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      success
                                          ? '${ledger.name} deleted'
                                          : 'Failed to delete. Try again.',
                                    ),
                                    backgroundColor: success
                                        ? context.errorColor
                                        : Colors.orange,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.errorColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: isDeleting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(LucideIcons.trash2, size: 18),
                                SizedBox(width: 10),
                                Text(
                                  'Yes, Delete Party',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Cancel
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: TextButton(
                      onPressed:
                          isDeleting ? null : () => Navigator.pop(sheetCtx),
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.textSecondaryColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLedgerCard(BuildContext context, UnifiedLedger ledger) {
    final bool isCustomer = ledger.type == LedgerType.customer;
    final bool isDue = ledger.balanceDue > 0.01;
    final bool isAdvance = ledger.balanceDue < -0.01;
    
    final String statusLabel = isCustomer 
        ? (isDue ? 'YOU GET' : (isAdvance ? 'ADVANCE' : 'SETTLED'))
        : (isDue ? 'YOU GIVE' : (isAdvance ? 'ADVANCE' : 'SETTLED'));

    final Color statusColor = isDue 
        ? (isCustomer ? context.successColor : context.errorColor)
        : (isAdvance 
            ? (isCustomer ? context.errorColor : context.successColor)
            : context.textSecondaryColor);

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
          onLongPress: () {
            HapticFeedback.heavyImpact();
            _showDeleteConfirmation(context, ledger);
          },
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
                        statusLabel,
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
