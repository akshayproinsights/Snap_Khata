import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/verified/presentation/providers/verified_provider.dart';
import 'package:mobile/features/verified/domain/models/verified_models.dart';
import 'package:mobile/features/shared/domain/models/invoice_group.dart';

class PartyLedgerPage extends ConsumerStatefulWidget {
  final String customerName;
  final String vehicleNumber; // Might be empty

  const PartyLedgerPage({
    super.key,
    required this.customerName,
    required this.vehicleNumber,
  });

  @override
  ConsumerState<PartyLedgerPage> createState() => _PartyLedgerPageState();
}

class _PartyLedgerPageState extends ConsumerState<PartyLedgerPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(verifiedProvider);

    // Filter records: if a vehicleNumber was provided, use it as the primary key
    // (all records for that vehicle, regardless of customer name)
    // Otherwise fall back to matching by customer name.
    final List<VerifiedInvoice> partyRecords = state.records.where((record) {
      if (widget.vehicleNumber.isNotEmpty) {
        return record.vehicleNumber == widget.vehicleNumber;
      }
      final effectiveName = record.customerName.isNotEmpty
          ? record.customerName
          : (record.vehicleNumber.isNotEmpty
              ? record.vehicleNumber
              : 'Unknown');
      return effectiveName == widget.customerName;
    }).toList();

    // 1. Group by receiptNumber (fallback to date)
    final Map<String, InvoiceGroup> groups = {};

    for (var record in partyRecords) {
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
          vehicleNumber: record.vehicleNumber,
          mobileNumber: record.mobileNumber,
        );
      }
      groups[safeId]!.items.add(record);
      groups[safeId]!.totalAmount += record.amount;
    }

    // 2. Sort groups descending by date
    final groupedList = groups.values.toList();
    groupedList.sort((a, b) {
      final dA = DateTime.tryParse(a.date) ?? DateTime(0);
      final dB = DateTime.tryParse(b.date) ?? DateTime(0);
      return dB.compareTo(dA);
    });

    // 3. Group by Vehicle Number
    final Map<String, List<InvoiceGroup>> vehicleMap = {};
    for (var group in groupedList) {
      final vehicle = group.vehicleNumber.isNotEmpty
          ? group.vehicleNumber
          : 'Unknown Vehicle';
      if (!vehicleMap.containsKey(vehicle)) {
        vehicleMap[vehicle] = [];
      }
      vehicleMap[vehicle]!.add(group);
    }
    final vehicleEntries = vehicleMap.entries.toList();

    double totalBilled = 0;
    for (var r in partyRecords) {
      totalBilled += r.amount;
    }

    // Determine display title: vehicle number is primary, customer name secondary
    final String headerTitle = widget.vehicleNumber.isNotEmpty
        ? widget.vehicleNumber
        : (widget.customerName.isNotEmpty ? widget.customerName : 'Unknown');
    final String headerSubtitle =
        widget.vehicleNumber.isNotEmpty && widget.customerName.isNotEmpty
            ? widget.customerName
            : '';

    final String initial = headerTitle.isNotEmpty && headerTitle != 'Unknown'
        ? headerTitle[0].toUpperCase()
        : '?';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            elevation: 0,
            backgroundColor: AppTheme.primary,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 60, 24, 16),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.4),
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Primary title: vehicle number (or customer name if no vehicle)
                            Row(
                              children: [
                                if (widget.vehicleNumber.isNotEmpty)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 6),
                                    child: Icon(LucideIcons.truck,
                                        color: Colors.white, size: 16),
                                  ),
                                Expanded(
                                  child: Text(
                                    headerTitle,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            // Secondary: customer name (only when navigating by vehicle with a known name)
                            if (headerSubtitle.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                headerSubtitle,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Balance Summary ───────────────────────────
          SliverToBoxAdapter(
            child: _BalanceSummaryCard(
              totalBilled: totalBilled,
              totalPaid:
                  totalBilled, // We assume verified = paid for now in this app
              pending: 0,
            ),
          ),

          // ── Action Buttons ────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: LucideIcons.send,
                      label: 'Send Receipt',
                      color: const Color(0xFF25D366),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Receipt feature coming soon')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      icon: LucideIcons.plusCircle,
                      label: 'Add Order',
                      color: AppTheme.primary,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.pushNamed('upload');
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Timeline Header ───────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              child: Text(
                'Transaction History',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),

          // ── Timeline ──────────────────────────────────
          if (state.isLoading && groupedList.isEmpty)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (vehicleEntries.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  'No transactions found.',
                  style: TextStyle(
                    color: AppTheme.textSecondary.withOpacity(0.6),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _VehicleGroupTile(
                    vehicle: vehicleEntries[i].key,
                    groups: vehicleEntries[i].value,
                  ),
                  childCount: vehicleEntries.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Balance Summary Card ─────────────────────────────────────────────────

class _BalanceSummaryCard extends StatelessWidget {
  final double totalBilled;
  final double totalPaid;
  final double pending;

  const _BalanceSummaryCard({
    required this.totalBilled,
    required this.totalPaid,
    required this.pending,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _SummaryCell(
            label: 'Total Billed',
            value: currencyFormat.format(totalBilled),
            color: AppTheme.textPrimary,
          ),
          _Divider(),
          _SummaryCell(
            label: 'Total Paid',
            value: currencyFormat.format(totalPaid),
            color: const Color(0xFF1B8A2A),
          ),
          _Divider(),
          _SummaryCell(
            label: pending < 0 ? 'Overpaid' : 'Pending',
            value: currencyFormat.format(pending.abs()),
            color: pending > 0 ? AppTheme.error : const Color(0xFF1B8A2A),
            bold: true,
          ),
        ],
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;

  const _SummaryCell({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: AppTheme.border,
    );
  }
}

// ── Action Button ────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Vehicle Group Tile ───────────────────────────────────────────────────

class _VehicleGroupTile extends StatelessWidget {
  final String vehicle;
  final List<InvoiceGroup> groups;

  const _VehicleGroupTile({
    required this.vehicle,
    required this.groups,
  });

  @override
  Widget build(BuildContext context) {
    int orderCount = groups.length;
    double totalAmount = groups.fold(0, (sum, g) => sum + g.totalAmount);
    final currencyFormat =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.truck,
                color: AppTheme.primary, size: 20),
          ),
          title: Text(
            vehicle,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          subtitle: Text(
            '$orderCount Order(s)',
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                fontSize: 12),
          ),
          trailing: Text(
            currencyFormat.format(totalAmount),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          children: groups.map((g) => _InvoiceGroupTile(group: g)).toList(),
        ),
      ),
    );
  }
}

// ── Ledger Entry Tile (Grouped) ──────────────────────────────────────────

class _InvoiceGroupTile extends ConsumerWidget {
  final InvoiceGroup group;

  const _InvoiceGroupTile({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyFormat =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    // If receiptLink exists, we can show an eye icon to view the real image
    final dt = DateTime.tryParse(group.date) ?? DateTime.now();
    final bool hasLink =
        group.receiptLink.isNotEmpty && group.receiptLink != 'null';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: GestureDetector(
          onLongPress: () {
            HapticFeedback.heavyImpact();
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete Order Record?'),
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
                      final rowIds = group.items.map((i) => i.rowId).toList();
                      if (rowIds.isNotEmpty) {
                        ref.read(verifiedProvider.notifier).deleteBulk(rowIds);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Order deleted successfully.'),
                            backgroundColor: AppTheme.success,
                          ),
                        );
                      }
                    },
                    style:
                        TextButton.styleFrom(foregroundColor: AppTheme.error),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
          },
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.receipt,
                  color: AppTheme.primary, size: 20),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    'Invoice ${group.receiptNumber.isNotEmpty ? "#${group.receiptNumber}" : "Captured"}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasLink)
                  InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      showDialog(
                        context: context,
                        builder: (ctx) => Dialog(
                          backgroundColor: Colors.transparent,
                          insetPadding: const EdgeInsets.all(16),
                          child: Stack(
                            alignment: Alignment.topRight,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  group.receiptLink,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Container(
                                    padding: const EdgeInsets.all(32),
                                    color: AppTheme.surface,
                                    child: const Text(
                                        'Failed to load receipt image.'),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(LucideIcons.xCircle,
                                    color: Colors.white, size: 32),
                                onPressed: () => Navigator.pop(ctx),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(LucideIcons.eye,
                          size: 18, color: AppTheme.primary),
                    ),
                  ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                children: [
                  Text(
                    _formatDate(dt),
                    style: TextStyle(
                        color: AppTheme.textSecondary.withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '• ${group.items.length} item(s)',
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            trailing: Text(
              currencyFormat.format(group.totalAmount),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: -0.5,
              ),
            ),
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border.withOpacity(0.5)),
                ),
                child: Column(
                  children: [
                    ...group.items.map((item) {
                      final isLast = item == group.items.last;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: isLast
                              ? null
                              : Border(
                                  bottom: BorderSide(
                                      color: AppTheme.border.withOpacity(0.3))),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.description.isNotEmpty
                                        ? item.description
                                        : 'Unknown Item',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.quantity} x ${currencyFormat.format(item.rate)}',
                                    style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              currencyFormat.format(item.amount),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ), // End ExpansionTile
        ), // End GestureDetector
      ), // End Theme
    ); // End Container
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
