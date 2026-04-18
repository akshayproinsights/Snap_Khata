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
          Text(error, style: const TextStyle(color: AppTheme.textSecondary)),
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
    String timeAgo = '';
    int daysSinceActivity = 0;
    if (ledger.lastPaymentDate != null) {
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
      // No payment date means it's been outstanding since inception — treat as urgent
      daysSinceActivity = 999;
    }
    final bool isOverdue = daysSinceActivity >= 30;

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
          color: isOverdue ? Colors.red.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOverdue ? Colors.red.shade300 : AppTheme.border,
            width: isOverdue ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isOverdue
                  ? Colors.red.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              // Orange/amber = neutral pending; red tint if overdue
              backgroundColor: isOverdue ? Colors.red.shade100 : Colors.orange.shade50,
              radius: 24,
              child: Text(
                ledger.customerName.isNotEmpty
                    ? ledger.customerName[0].toUpperCase()
                    : 'C',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isOverdue ? Colors.red.shade800 : Colors.orange.shade800,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ledger.customerName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        timeAgo,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isOverdue ? FontWeight.w700 : FontWeight.normal,
                          color: isOverdue ? Colors.red.shade700 : AppTheme.textSecondary,
                        ),
                      ),
                      if (isOverdue) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Chase now!',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currencyFormatter.format(ledger.balanceDue),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    // Red when overdue to signal urgency; green when recent
                    color: isOverdue ? Colors.red.shade700 : Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isOverdue ? 'OVERDUE' : 'You will get',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isOverdue ? FontWeight.w700 : FontWeight.normal,
                    color: isOverdue ? Colors.red.shade600 : AppTheme.textSecondary,
                    letterSpacing: isOverdue ? 0.5 : 0,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: () => _sendGenericReminder(context, ref),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const FaIcon(FontAwesomeIcons.whatsapp,
                        color: Colors.green, size: 22),
                    const SizedBox(height: 2),
                    Text(
                      'Reminder',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade700,
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
