import "package:mobile/core/theme/context_extension.dart";
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/verified/presentation/providers/verified_provider.dart';
import 'package:mobile/features/shared/domain/models/invoice_group.dart';
import 'package:mobile/features/udhar/presentation/providers/udhar_provider.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/udhar/presentation/providers/udhar_dashboard_provider.dart';

// Standardized green colors moved to context extensions

class CustomersTab extends ConsumerStatefulWidget {
  const CustomersTab({super.key});

  @override
  ConsumerState<CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends ConsumerState<CustomersTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(verifiedProvider);

    if (state.isLoading && state.records.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.records.isEmpty) {
      return Center(
          child: Text('Error: ${state.error}',
              style: TextStyle(color: context.errorColor)));
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
        final existingDt =
            DateTime.tryParse(groups[safeId]!.uploadDate) ?? DateTime(0);
        final newDt = DateTime.tryParse(record.uploadDate) ?? DateTime(0);
        if (newDt.isAfter(existingDt)) {
          groups[safeId]!.uploadDate = record.uploadDate;
        }
      }
      groups[safeId]!.items.add(record);
      groups[safeId]!.totalAmount += record.amount;
    }

    var sortedGroups = groups.values.toList()
      ..sort((a, b) {
        final dA = DateTime.tryParse(a.uploadDate) ?? DateTime(0);
        final dB = DateTime.tryParse(b.uploadDate) ?? DateTime(0);
        return dB.compareTo(dA);
      });

    // Apply filtering
    if (_searchQuery.isNotEmpty) {
      sortedGroups = sortedGroups.where((group) {
        final name = group.customerName.toLowerCase();
        return name.contains(_searchQuery);
      }).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Recent Customer Orders',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: context.textColor,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildSearchBox(),
        const SizedBox(height: 12),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async =>
                ref.read(verifiedProvider.notifier).fetchRecords(),
            child: ListView.separated(
              padding: const EdgeInsets.only(
                  left: 12, right: 12, top: 12, bottom: 90),
              itemCount: sortedGroups.isEmpty ? 1 : sortedGroups.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (sortedGroups.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 24.0),
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'No verified receipts yet.\nSnap a new receipt to get started!'
                          : 'No orders found matching "$_searchQuery"',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: context.textSecondaryColor,
                          fontSize: 16),
                    ),
                  );
                }

                final group = sortedGroups[index];
                return _DashboardInvoiceGroupTile(group: group);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: context.premiumShadow,
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (v) =>
              setState(() => _searchQuery = v.trim().toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Search customers...',
            prefixIcon: const Icon(LucideIcons.search, size: 20),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            hintStyle: TextStyle(
                color: context.textSecondaryColor.withValues(alpha: 0.5)),
          ),
        ),
      ),
    );
  }
}

class _DashboardInvoiceGroupTile extends ConsumerWidget {
  final InvoiceGroup group;

  const _DashboardInvoiceGroupTile({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

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

    final Color statusColor = context.successColor;
    final Color statusBg = context.successColor.withValues(alpha: 0.1);
    final String statusLabel =
        group.receiptNumber.isNotEmpty ? '#${group.receiptNumber}' : 'Verified';

    final String initial = displayName[0].toUpperCase();
    final bool isUnknown = group.customerName.isEmpty ||
        group.customerName.toLowerCase() == 'unknown';

    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: context.borderColor.withValues(alpha: 0.8),
            width: 0.5),
        boxShadow: context.premiumShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius:
                  group.receiptLink.isNotEmpty || group.receiptNumber.isNotEmpty
                      ? const BorderRadius.vertical(top: Radius.circular(18))
                      : BorderRadius.circular(18),
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
                            // Invalidate udhar providers to refresh credit balances
                            ref.invalidate(udharProvider);
                            ref.invalidate(udharDashboardProvider);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Order deleted successfully.'),
                                backgroundColor: context.primaryColor,
                              ),
                            );
                          }
                        },
                        style: TextButton.styleFrom(
                            foregroundColor: context.errorColor),
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
                        color: context.primaryColor.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isUnknown ? context.primaryColor : context.primaryColor,
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
                            style: TextStyle(
                                color: context.textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                LucideIcons.calendar,
                                size: 12,
                                color: context.textSecondaryColor.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(dt),
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
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.format(group.totalAmount),
                          style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: context.textColor,
                                letterSpacing: -0.3,
                              ),
                        ),
                        if ((group.balanceDue ?? 0) > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Due: ${CurrencyFormatter.format(group.balanceDue ?? 0.0)}',
                            style: TextStyle(
                              color: context.errorColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
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
