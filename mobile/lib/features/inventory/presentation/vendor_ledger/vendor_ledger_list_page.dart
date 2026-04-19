import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../providers/vendor_ledger_provider.dart';
import '../../domain/models/vendor_ledger_models.dart';
import 'package:intl/intl.dart';
import 'package:mobile/features/udhar/presentation/providers/udhar_search_provider.dart';

class VendorLedgerListPage extends ConsumerWidget {
  const VendorLedgerListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(vendorLedgerProvider);
    final searchQuery = ref.watch(udharSearchQueryProvider).toLowerCase();
    final filterMode = ref.watch(udharFilterProvider);

    final filteredLedgers = state.ledgers.where((ledger) {
      // 1. Apply Search
      if (searchQuery.isNotEmpty && !ledger.vendorName.toLowerCase().contains(searchQuery)) {
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
                  ? _buildEmptyState(context)
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
            onPressed: () => ref.read(vendorLedgerProvider.notifier).fetchLedgers(),
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
          Icon(LucideIcons.truck, color: Colors.grey.shade400, size: 64),
          const SizedBox(height: 16),
          Text(
            'No pending Supplier dues',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Amazing! You have cleared all vendor dues.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerList(List<VendorLedger> ledgers) {
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
  final VendorLedger ledger;

  const _LedgerCard({required this.ledger});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyFormatter = NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');
    
    // Calculate time ago
    String timeAgo = '';
    if (ledger.lastPaymentDate != null) {
      final difference = DateTime.now().difference(ledger.lastPaymentDate!);
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
    }
    
    return InkWell(
      onTap: () {
        context.push('/inventory/vendor-ledger/${ledger.id}', extra: ledger);
      },
      onLongPress: () async {
        HapticFeedback.heavyImpact();
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Vendor Ledger'),
            content: Text('Are you sure you want to delete ${ledger.vendorName} and all tracking history? This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        
        if (confirm == true) {
          final success = await ref.read(vendorLedgerProvider.notifier).deleteLedger(ledger.id);
          if (success && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Vendor Ledger deleted successfully')),
            );
          } else if (!success && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to delete vendor ledger')),
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
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 0.5),
          boxShadow: Theme.of(context).brightness == Brightness.light
              ? AppTheme.premiumShadow
              : AppTheme.darkPremiumShadow,
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.red.shade50,
              radius: 24,
              child: Icon(
                Icons.local_shipping,
                size: 24,
                color: Colors.red.shade800,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ledger.vendorName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeAgo,
                    style: TextStyle(
                      fontSize: 12,
                      color: timeAgo == 'No payments yet'
                          ? Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currencyFormatter.format(ledger.balanceDue),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You will give',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
