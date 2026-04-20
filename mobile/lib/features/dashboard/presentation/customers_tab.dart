import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/verified/presentation/providers/verified_provider.dart';
import 'package:mobile/features/shared/domain/models/invoice_group.dart';

const _kGreen = Color(0xFF1B8A2A);
const _kGreenBg = Color(0xFFE8F5E9);

class CustomersTab extends ConsumerWidget {
  const CustomersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(verifiedProvider);

    if (state.isLoading && state.records.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.records.isEmpty) {
      return Center(
          child: Text('Error: ${state.error}',
              style: TextStyle(color: Theme.of(context).colorScheme.error)));
    }

    final Map<String, InvoiceGroup> groups = {};

    for (var record in state.records) {
      final String groupId = record.receiptNumber.isNotEmpty
          ? record.receiptNumber
          : (record.date.isNotEmpty ? record.date : record.uploadDate);
      final String safeId = groupId.isNotEmpty ? groupId : record.rowId;

      if (!groups.containsKey(safeId)) {
        groups[safeId] = InvoiceGroup(
          receiptNumber: record.receiptNumber,
          date: record.date.isNotEmpty ? record.date : record.uploadDate,
          receiptLink: record.receiptLink,
          customerName: record.customerName,
          mobileNumber: record.mobileNumber,
          extraFields: record.extraFields,
          uploadDate: record.uploadDate,
          paymentMode: record.paymentMode,
          receivedAmount: record.receivedAmount,
          balanceDue: record.balanceDue,
          customerDetails: record.customerDetails,
        );
      } else {
        final existingDt = DateTime.tryParse(groups[safeId]!.uploadDate) ?? DateTime(0);
        final newDt = DateTime.tryParse(record.uploadDate) ?? DateTime(0);
        if (newDt.isAfter(existingDt)) {
          groups[safeId]!.uploadDate = record.uploadDate;
        }
      }
      groups[safeId]!.items.add(record);
      groups[safeId]!.totalAmount += record.amount;
    }

    final sortedGroups = groups.values.toList()
      ..sort((a, b) {
        final dA = DateTime.tryParse(a.uploadDate) ?? DateTime(0);
        final dB = DateTime.tryParse(b.uploadDate) ?? DateTime(0);
        return dB.compareTo(dA);
      });

    final itemCount = sortedGroups.isEmpty ? 1 : sortedGroups.length;

    return RefreshIndicator(
      onRefresh: () async => ref.read(verifiedProvider.notifier).fetchRecords(),
      child: ListView.separated(
        padding:
            const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 90),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (sortedGroups.isEmpty) {
            return Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: Text(
                'No verified orders yet.\nSnap a new order to get started!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 16),
              ),
            );
          }

          final group = sortedGroups[index];
          return _DashboardInvoiceGroupTile(group: group);
        },
      ),
    );
  }
}

class _DashboardInvoiceGroupTile extends ConsumerWidget {
  final InvoiceGroup group;

  const _DashboardInvoiceGroupTile({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyFormat =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    final String vehicleNum = group.extraFields['vehicle_number']?.toString() ?? '';
    final String displayName = group.customerName.isNotEmpty
        ? group.customerName
        : (vehicleNum.isNotEmpty
            ? vehicleNum
            : 'Unknown Customer');
    final String vehicleInfo =
        (vehicleNum.isNotEmpty && group.customerName.isNotEmpty)
            ? ' ($vehicleNum)'
            : '';

    final dt = DateTime.tryParse(group.date) ?? DateTime.now();

    const Color statusColor = _kGreen;
    const Color statusBg = _kGreenBg;
    final String statusLabel =
        group.receiptNumber.isNotEmpty ? '#${group.receiptNumber}' : 'Verified';

    final String initial = displayName[0].toUpperCase();
    final bool isUnknown = group.customerName.isEmpty ||
        group.customerName.toLowerCase() == 'unknown';

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 0.5),
        boxShadow: Theme.of(context).brightness == Brightness.light
            ? AppTheme.premiumShadow
            : AppTheme.darkPremiumShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius:
                  group.receiptLink.isNotEmpty || group.receiptNumber.isNotEmpty
                      ? const BorderRadius.vertical(top: Radius.circular(16))
                      : BorderRadius.circular(16),
              onTap: () {
                HapticFeedback.lightImpact();
                context.pushNamed('order-detail', extra: group);
              },
              onLongPress: () {
                HapticFeedback.heavyImpact();
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Recent Order?'),
                    content: const Text(
                        'Are you sure you want to permanently delete this order and all its items? This action cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          final rowIds =
                              group.items.map((i) => i.rowId).toList();
                          if (rowIds.isNotEmpty) {
                            ref
                                .read(verifiedProvider.notifier)
                                .deleteBulk(rowIds);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Order deleted successfully.'),
                                backgroundColor: Theme.of(context).colorScheme.primary,
                              ),
                            );
                          }
                        },
                        style: TextButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.error),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isUnknown
                            ? Colors.blue.withValues(alpha: 0.1)
                            : Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isUnknown ? Colors.blue : Theme.of(context).colorScheme.primary,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$displayName$vehicleInfo',
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                LucideIcons.calendar,
                                size: 12,
                                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(dt),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          currencyFormat.format(group.totalAmount),
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: Theme.of(context).colorScheme.onSurface,
                                    letterSpacing: -0.3,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
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

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0 && now.day == dt.day) return 'Today';
    if (diff.inDays == 1 || (diff.inDays == 0 && now.day != dt.day)) {
      return 'Yesterday';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
