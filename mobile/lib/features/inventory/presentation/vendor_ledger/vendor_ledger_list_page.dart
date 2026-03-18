import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
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

    final filteredLedgers = state.ledgers.where((ledger) {
      if (searchQuery.isEmpty) return true;
      return ledger.vendorName.toLowerCase().contains(searchQuery);
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
            onPressed: () => ref.read(vendorLedgerProvider.notifier).fetchLedgers(),
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
          Icon(LucideIcons.truck, color: Colors.grey.shade400, size: 64),
          const SizedBox(height: 16),
          const Text(
            'No pending Supplier dues',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Amazing! You have cleared all vendor dues.',
            style: TextStyle(color: AppTheme.textSecondary),
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
    final currencyFormatter = NumberFormat.currency(symbol: '₹', decimalDigits: 2, locale: 'en_IN');
    
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
               color: Colors.black.withValues(alpha: 0.02),
               blurRadius: 10,
               offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.red.shade50,
              radius: 24,
              child: Text(
                ledger.vendorName.isNotEmpty ? ledger.vendorName[0].toUpperCase() : 'V',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade800,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ledger.vendorName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeAgo,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currencyFormatter.format(ledger.balanceDue),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'You will give',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
              onSelected: (value) async {
                if (value == 'delete') {
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
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
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
