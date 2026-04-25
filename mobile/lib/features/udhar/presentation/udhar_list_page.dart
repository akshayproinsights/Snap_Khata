import "package:mobile/core/theme/context_extension.dart";
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'providers/udhar_provider.dart';
import '../domain/models/udhar_models.dart';
import 'providers/udhar_search_provider.dart';
import 'package:mobile/core/utils/whatsapp_utils.dart';
import 'package:mobile/features/settings/presentation/providers/shop_provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mobile/core/utils/currency_formatter.dart';

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
          return ledger.balanceDue <= 0;
        case UdharFilterMode.customers:
        case UdharFilterMode.suppliers:
        case UdharFilterMode.all:
          return true;
      }
    }).toList();

    return state.isLoading && state.ledgers.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : state.error != null && state.ledgers.isEmpty
            ? _buildErrorState(context, ref, state.error!)
            : state.ledgers.isEmpty
                ? _buildEmptyState(context)
                : _buildLedgerList(filteredLedgers);
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, String error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.alertCircle, color: context.warningColor, size: 48),
          const SizedBox(height: 16),
          Text(error, style: TextStyle(color: context.textSecondaryColor)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.read(udharProvider.notifier).fetchLedgers(),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.wallet, color: context.textSecondaryColor.withValues(alpha: 0.4), size: 64),
          const SizedBox(height: 16),
          Text(
            'No pending Credit',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Amazing! All your customers have paid their dues.',
            style: TextStyle(color: context.textSecondaryColor),
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

    final pendingFmt = CurrencyFormatter.format(ledger.balanceDue);

    String message = 'Hi $customerNameMsg,\n\n'
        'This is a gentle reminder from *${shopName.trim()}* regarding your pending balance.\n\n'
        '⚠️ *Total Amount Due: $pendingFmt*\n\n';

    if (shopProfile.upiId.isNotEmpty) {
      // Create UPI pay link
      // Format: upi://pay?pa=upiid@bank&pn=ShopName&am=100.00&cu=INR
      final upiLink = 'upi://pay?pa=${shopProfile.upiId}&pn=${Uri.encodeComponent(shopName)}&am=${ledger.balanceDue.toStringAsFixed(2)}&cu=INR';
      
      message += '💳 *Pay via UPI:* ${shopProfile.upiId}\n'
                '🔗 *Payment Link:* $upiLink\n\n';
    }

    message += 'Thank you for your business!\n— *${shopName.trim()}*';

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
                    Text('Delete', style: TextStyle(color: context.errorColor)),
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
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOverdue
                ? context.errorColor.withValues(alpha: 0.15)
                : context.borderColor,
            width: 0.5,
          ),
          boxShadow: context.premiumShadow,
        ),
        child: Row(
          children: [
            // Avatar circle — subtle primary for normal, error for overdue
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isOverdue
                    ? context.errorColor.withValues(alpha: 0.08)
                    : context.primaryColor.withValues(alpha: 0.08),
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
                        ? context.errorColor
                        : context.primaryColor,
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
                      color: context.textColor,
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
                               ? context.errorColor
                               : context.textSecondaryColor,
                          fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      if (isOverdue) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: context.errorColor,
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
                  CurrencyFormatter.format(ledger.balanceDue),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isOverdue
                        ? context.errorColor
                        : context.successColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isOverdue ? 'OVERDUE' : 'TO COLLECT',
                  style: TextStyle(
                    fontSize: 10,
                    color: isOverdue ? context.errorColor : context.primaryColor,
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
                        color: context.textSecondaryColor.withValues(alpha: 0.6),
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
