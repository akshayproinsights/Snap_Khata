import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'providers/udhar_provider.dart';
import '../domain/models/udhar_models.dart';
import 'package:intl/intl.dart';
import 'providers/udhar_search_provider.dart';
import 'package:mobile/core/utils/whatsapp_utils.dart';
import 'package:mobile/features/settings/presentation/providers/shop_provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class UdharListPage extends ConsumerWidget {
  const UdharListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(udharProvider);
    final searchQuery = ref.watch(udharSearchQueryProvider).toLowerCase();
    final filterMode = ref.watch(udharFilterProvider);

    final filteredLedgers = state.ledgers.where((ledger) {
      // 1. Apply Search
      if (searchQuery.isNotEmpty && !ledger.customerName.toLowerCase().contains(searchQuery)) {
        return false;
      }
      
      // 2. Apply Filter Mode
      switch (filterMode) {
        case UdharFilterMode.pending:
          return ledger.balanceDue > 0;
        case UdharFilterMode.settled:
          return ledger.balanceDue == 0;
        case UdharFilterMode.all:
          return true;
      }
    }).toList();

    return state.isLoading && state.ledgers.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : state.error != null && state.ledgers.isEmpty
            ? _buildErrorState(context, ref, state.error!)
            : state.ledgers.isEmpty
                ? _buildEmptyState()
                : _buildLedgerList(filteredLedgers);
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, String error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.alertCircle, color: Colors.orange, size: 48),
          const SizedBox(height: 16),
          Text(error, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.read(udharProvider.notifier).fetchLedgers(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.wallet, color: Colors.grey.shade400, size: 64),
          const SizedBox(height: 16),
          const Text(
            'No pending Credit',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Amazing! All your customers have paid their dues.',
            style: TextStyle(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerList(List<CustomerLedger> ledgers) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: ledgers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final ledger = ledgers[index];
        return _LedgerCard(ledger: ledger);
      },
    );
  }
}

class _LedgerCard extends ConsumerWidget {
  final CustomerLedger ledger;

  const _LedgerCard({required this.ledger});

  Future<void> _sendGenericReminder(BuildContext context, WidgetRef ref) async {
    HapticFeedback.lightImpact();

    final customerNameMsg = ledger.customerName.isNotEmpty &&
            ledger.customerName.toLowerCase() != 'unknown'
        ? ledger.customerName
        : 'Customer';

    final shopProfile = ref.read(shopProvider);
    final shopName =
        shopProfile.name.isNotEmpty ? shopProfile.name : 'Our Shop';

    final pendingFmt = WhatsAppUtils.formatIndianCurrency(ledger.balanceDue);

    final message = 'Hi $customerNameMsg,\n\n'
        'This is a gentle reminder from *${shopName.trim()}* regarding your pending balance.\n\n'
        '⚠️ *Total Amount Due: $pendingFmt*\n\n'
        'Thank you for your business!\n— *${shopName.trim()}*';

    await WhatsAppUtils.shareReceipt(
      context,
      phone: ledger.customerPhone ?? '',
      message: message,
      dialogTitle: 'Send WhatsApp Reminder',
      dialogContent: 'Enter customer\'s mobile number, or skip to select contact directly in WhatsApp.',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyFormatter =
        NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');

    // Calculate days since last activity and urgency flag
    // Only mark as overdue when there IS a recorded payment date AND it's 30+ days old.
    // New entries with no payment history should stay visually neutral.
    String timeAgo = '';
    int daysSinceActivity = 0;
    bool hasActivityDate = ledger.lastPaymentDate != null;
    if (hasActivityDate) {
      final difference = DateTime.now().difference(ledger.lastPaymentDate!);
      daysSinceActivity = difference.inDays;
      if (difference.inDays > 0) {
        timeAgo = '${difference.inDays} days ago';
      } else if (difference.inHours > 0) {
        timeAgo = '${difference.inHours} hours ago';
      } else if (difference.inMinutes > 0) {
        timeAgo = '${difference.inMinutes} mins ago';
      } else {
        timeAgo = 'Just now';
      }
    } else {
      timeAgo = 'No payments yet';
      // Do NOT treat as overdue — this is simply a new, untracked entry
      daysSinceActivity = 0;
    }
    // Only flag overdue when we have a real date AND it's been 30+ days
    final bool isOverdue = hasActivityDate && daysSinceActivity >= 30;

    return InkWell(
      onTap: () {
        context.push('/udhar/${ledger.id}', extra: ledger);
      },
      onLongPress: () async {
        HapticFeedback.heavyImpact();
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Ledger'),
            content: Text(
                'Are you sure you want to delete ${ledger.customerName} and all tracking history? This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child:
                    const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );

        if (confirm == true) {
          final success =
              await ref.read(udharProvider.notifier).deleteLedger(ledger.id);
          if (success && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ledger deleted successfully')),
            );
          } else if (!success && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to delete ledger')),
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOverdue
                ? Theme.of(context).colorScheme.error.withValues(alpha: 0.15)
                : Theme.of(context).colorScheme.outlineVariant,
            width: 0.5,
          ),
          boxShadow: Theme.of(context).brightness == Brightness.light
              ? AppTheme.premiumShadow
              : AppTheme.darkPremiumShadow,
        ),
        child: Row(
          children: [
            // Avatar circle — subtle primary for normal, error for overdue
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isOverdue
                    ? Theme.of(context).colorScheme.error.withValues(alpha: 0.08)
                    : Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  ledger.customerName.isNotEmpty
                      ? ledger.customerName[0].toUpperCase()
                      : 'C',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isOverdue
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ledger.customerName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        timeAgo,
                        style: TextStyle(
                          fontSize: 12,
                          color: isOverdue
                               ? Theme.of(context).colorScheme.error
                               : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      if (isOverdue) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Follow up',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Amount column
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currencyFormatter.format(ledger.balanceDue),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isOverdue
                        ? Colors.red.shade700
                        : const Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isOverdue ? 'OVERDUE' : 'TO COLLECT',
                  style: TextStyle(
                    fontSize: 10,
                    color: isOverdue ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            // WhatsApp reminder button
            InkWell(
              onTap: () => _sendGenericReminder(context, ref),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(
                      FontAwesomeIcons.whatsapp,
                      color: Colors.green.shade600,
                      size: 20,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Remind',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
