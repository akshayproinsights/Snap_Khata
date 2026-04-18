import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/features/verified/presentation/providers/verified_provider.dart';
import 'package:mobile/features/shared/domain/models/invoice_group.dart';
import 'package:mobile/features/review/presentation/providers/review_provider.dart';
import 'package:mobile/features/purchase_orders/presentation/providers/purchase_order_provider.dart';

const _kGreen = Color(0xFF1B8A2A);
const _kGreenBg = Color(0xFFE8F5E9);

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(verifiedProvider.notifier).fetchRecords();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(authProvider);
    final String shopName =
        userState.user?.name ?? userState.user?.username ?? 'My Shop';
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        titleSpacing: 16,
        surfaceTintColor: Colors.transparent,
        backgroundColor: AppTheme.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_getGreeting()}, $shopName',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: AppTheme.textPrimary,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.logOut),
            onPressed: () async {
              HapticFeedback.lightImpact();
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelStyle: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
          unselectedLabelStyle: Theme.of(context).textTheme.titleSmall,
          indicatorSize: TabBarIndicatorSize.label,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: 'Recent Orders'),
            Tab(text: 'Party Details'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _RecentOrdersTab(),
          _PartyDetailsTab(),
        ],
      ),
      floatingActionButton: SizedBox(
        height: 54,
        child: FloatingActionButton.extended(
          onPressed: () {
            HapticFeedback.mediumImpact();
            // In the new app, navigating to upload represents Snap New Order
            context.pushNamed('upload');
          },
          backgroundColor: const Color(0xFF16A34A), // green-700 — money coming in
          foregroundColor: Colors.white,
          icon: const Icon(Icons.camera_alt_rounded, size: 22),
          label: Text(
            'Snap New Order',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: Colors.white,
                ),
          ),
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Tab 1 – Recent Orders
// ─────────────────────────────────────────────────────────────

class _RecentOrdersTab extends ConsumerWidget {
  const _RecentOrdersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(verifiedProvider);

    if (state.isLoading && state.records.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.records.isEmpty) {
      return Center(
          child: Text('Error: ${state.error}',
              style: const TextStyle(color: AppTheme.error)));
    }

    // 1. Group records by receiptNumber (fallback to date)
    final Map<String, InvoiceGroup> groups = {};

    int todayReceipts = 0;
    double todayRevenue = 0.0;
    final now = DateTime.now();

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
        // Update uploadDate if the new record is more recent
        final existingDt = DateTime.tryParse(groups[safeId]!.uploadDate) ?? DateTime(0);
        final newDt = DateTime.tryParse(record.uploadDate) ?? DateTime(0);
        if (newDt.isAfter(existingDt)) {
          groups[safeId]!.uploadDate = record.uploadDate;
        }
      }
      groups[safeId]!.items.add(record);
      groups[safeId]!.totalAmount += record.amount;
    }

    // Sort descending by uploadDate (most recent upload first)
    final sortedGroups = groups.values.toList()
      ..sort((a, b) {
        final dA = DateTime.tryParse(a.uploadDate) ?? DateTime(0);
        final dB = DateTime.tryParse(b.uploadDate) ?? DateTime(0);
        return dB.compareTo(dA);
      });

    // Calculate Today's Sale
    final List<InvoiceGroup> todayGroups = [];
    for (var group in sortedGroups) {
      final dt = DateTime.tryParse(group.date) ?? DateTime(0);
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        todayReceipts++;
        todayRevenue += group.totalAmount;
        todayGroups.add(group);
      }
    }

    final itemCount = sortedGroups.isEmpty ? 2 : sortedGroups.length + 1;

    return RefreshIndicator(
      onRefresh: () async => ref.read(verifiedProvider.notifier).fetchRecords(),
      child: ListView.separated(
        padding:
            const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 90),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _QuickLinksSection(
              todayReceipts: todayReceipts,
              todayRevenue: todayRevenue,
              todayGroups: todayGroups,
            );
          }

          if (sortedGroups.isEmpty) {
            return const Padding(
              padding: EdgeInsets.only(top: 24.0),
              child: Text(
                'No verified orders yet.\nSnap a new order to get started!',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
              ),
            );
          }

          final group = sortedGroups[index - 1];
          return _DashboardInvoiceGroupTile(group: group);
        },
      ),
    );
  }
}

// ── Dashboard Group Tile ─────────────────────────────────────────────────────

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
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                              const SnackBar(
                                content: Text('Order deleted successfully.'),
                                backgroundColor: AppTheme.success,
                              ),
                            );
                          }
                        },
                        style: TextButton.styleFrom(
                            foregroundColor: AppTheme.error),
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
                            : AppTheme.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isUnknown ? Colors.blue : AppTheme.primary,
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
                                color: AppTheme.textSecondary.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(dt),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppTheme.textSecondary,
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
                                    color: AppTheme.textPrimary,
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
                            style: const TextStyle(
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

// ─────────────────────────────────────────────────────────────
// Tab 2 – Party Details
// ─────────────────────────────────────────────────────────────

class _PartyDetailsTab extends ConsumerStatefulWidget {
  const _PartyDetailsTab();

  @override
  ConsumerState<_PartyDetailsTab> createState() => _PartyDetailsTabState();
}

class _PartyDetailsTabState extends ConsumerState<_PartyDetailsTab> {
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    setState(() {
      _searchQuery = val;
    });

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      // Trigger backend search for full table check
      ref
          .read(verifiedProvider.notifier)
          .fetchRecords(search: val.isNotEmpty ? val : null);
    });
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
              style: const TextStyle(color: AppTheme.error)));
    }

    // Aggregate records grouped by vehicle number (when present), else by customer name
    final Map<String, _PartySummary> summaries = {};
    for (var record in state.records) {
      // Filter logic
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesName = record.customerName.toLowerCase().contains(query);
        final vehicle = record.extraFields['vehicle_number']?.toString() ?? '';
        final matchesVehicle =
            vehicle.toLowerCase().contains(query);
        final matchesMobile = record.mobileNumber.toLowerCase().contains(query);
        if (!matchesName && !matchesVehicle && !matchesMobile) continue;
      }

      final String vehicle = record.extraFields['vehicle_number']?.toString() ?? '';
      final String custName = record.customerName;

      // Group purely by vehicle number when available; otherwise by customer name
      final String key = vehicle.isNotEmpty
          ? vehicle
          : (custName.isNotEmpty ? custName : 'Unknown');

      if (!summaries.containsKey(key)) {
        summaries[key] = _PartySummary(
          extraFields: record.extraFields,
          customerName: custName,
          latestReceipt: record.receiptNumber,
          totalAmount: 0,
        );
      } else {
        // Keep the best (non-empty) customer name seen for this vehicle
        if (summaries[key]!.customerName.isEmpty && custName.isNotEmpty) {
          summaries[key]!.customerName = custName;
        }
      }

      summaries[key]!.totalAmount += record.amount;
      summaries[key]!.rowIds.add(record.rowId);

      // Use receiptNumber if available, otherwise fallback to date/uploadDate for uniqueness
      final String uniqueJobId = record.receiptNumber.isNotEmpty
          ? record.receiptNumber
          : (record.date.isNotEmpty ? record.date : record.uploadDate);

      if (uniqueJobId.isNotEmpty) {
        summaries[key]!.receipts.add(uniqueJobId);
      } else {
        // Absolute fallback, just count it if we have no other identifier
        summaries[key]!.receipts.add(record.rowId);
      }
    }

    final partyList = summaries.values.toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    final currencyFormat =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Column(
      children: [
        if (state.records.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name, vehicle, or mobile',
                hintStyle:
                    TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6)),
                prefixIcon: const Icon(LucideIcons.search,
                    color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.surface,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppTheme.primary, width: 2),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
        Expanded(
          child: partyList.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      _searchQuery.isNotEmpty
                          ? 'No parties found for "$_searchQuery".'
                          : 'No parties yet.\nSnap a new order to build your ledger.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 16),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async =>
                      ref.read(verifiedProvider.notifier).fetchRecords(),
                  child: ListView.separated(
                    padding: const EdgeInsets.only(
                        left: 12, right: 12, top: 12, bottom: 90),
                    itemCount: partyList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final party = partyList[index];
                      final String displayTitle = party.name;

                      final initial = displayTitle.isNotEmpty
                          ? displayTitle[0].toUpperCase()
                          : '?';

                      return Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              context.pushNamed(
                                'party-ledger',
                                extra: {
                                  'customerName': party.customerName,
                                  'extraFields': party.extraFields,
                                },
                              );
                            },
                            onLongPress: () {
                              HapticFeedback.heavyImpact();
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete Party Record?'),
                                  content: Text(
                                      'Are you sure you want to permanently delete all ${party.orderCount} order(s) for $displayTitle? This action cannot be undone.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        if (party.rowIds.isNotEmpty) {
                                          ref
                                              .read(verifiedProvider.notifier)
                                              .deleteBulk(party.rowIds);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'Deleted all orders for $displayTitle.'),
                                              backgroundColor: AppTheme.success,
                                            ),
                                          );
                                        }
                                      },
                                      style: TextButton.styleFrom(
                                          foregroundColor: AppTheme.error),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      initial,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.primary,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayTitle,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.copyWith(
                                                  fontWeight: FontWeight.w700),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${party.orderCount} Order(s)',
                                          style: const TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        currencyFormat
                                            .format(party.totalAmount),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                              color: AppTheme.textPrimary,
                                              letterSpacing: -0.3,
                                            ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: _kGreenBg,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          party.latestReceipt.isNotEmpty
                                              ? '#${party.latestReceipt}'
                                              : 'Ledger',
                                          style: const TextStyle(
                                            color: _kGreen,
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
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _PartySummary {
  final Map<String, dynamic> extraFields;
  String customerName; // Best customer name seen for this vehicle
  final String latestReceipt;
  double totalAmount;
  final Set<String> receipts = {}; // Track unique invoice IDs
  final List<String> rowIds = []; // Track all row IDs for deletion

  /// Display name: "CustomerName (VehicleNo)" or just vehicle/customer
  String get name {
    final vNum = extraFields['vehicle_number']?.toString() ?? '';
    return vNum.isNotEmpty
      ? (customerName.isNotEmpty && customerName != vNum
          ? '$customerName ($vNum)'
          : vNum)
      : customerName;
  }

  int get orderCount => receipts.isNotEmpty ? receipts.length : 0;

  _PartySummary({
    required this.extraFields,
    required this.customerName,
    required this.latestReceipt,
    required this.totalAmount,
  });
}

// ─────────────────────────────────────────────────────────────
// Quick Links Section
// ─────────────────────────────────────────────────────────────

class _QuickLinksSection extends ConsumerWidget {
  final int todayReceipts;
  final double todayRevenue;
  final List<InvoiceGroup> todayGroups;

  const _QuickLinksSection({
    required this.todayReceipts,
    required this.todayRevenue,
    required this.todayGroups,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get counts
    final reviewCount = ref.watch(reviewProvider).groups.length;
    final poDraftCount = ref.watch(purchaseOrderProvider).draftCount;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Links',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildActionItem(
                context: context,
                icon: LucideIcons.clipboardCheck,
                color: const Color(0xFFEF4444), // Red
                title: 'Review',
                badgeCount: reviewCount,
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.pushNamed('review');
                },
              ),
              _buildActionItem(
                context: context,
                icon: LucideIcons.refreshCcw,
                color: const Color(0xFF3B82F6), // Blue
                title: 'Quick Reorder',
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.pushNamed('quick-reorder');
                },
              ),
              _buildActionItem(
                context: context,
                icon: LucideIcons.shoppingCart,
                color: const Color(0xFF0EA5E9), // Light Blue
                title: 'PO',
                badgeCount: poDraftCount,
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.pushNamed('purchase-orders');
                },
              ),
              _buildActionItem(
                context: context,
                icon: LucideIcons.indianRupee,
                color: const Color(0xFF10B981), // Emerald
                title: 'Today\'s Sale',
                onTap: () {
                  HapticFeedback.lightImpact();
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => _TodaySaleSheet(
                      groups: todayGroups,
                      totalRevenue: todayRevenue,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    int badgeCount = 0,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        constraints:
                            const BoxConstraints(minWidth: 20, minHeight: 20),
                        child: Text(
                          badgeCount > 99 ? '99+' : badgeCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                        fontSize: 9,
                      ),
                  maxLines: 2,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Today's Sale Bottom Sheet
// ─────────────────────────────────────────────────────────────

class _TodaySaleSheet extends StatelessWidget {
  final List<InvoiceGroup> groups;
  final double totalRevenue;

  const _TodaySaleSheet({
    required this.groups,
    required this.totalRevenue,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final screenH = MediaQuery.of(context).size.height;
    const emerald = Color(0xFF10B981);
    const emeraldLight = Color(0xFFD1FAE5);

    return Container(
      constraints: BoxConstraints(maxHeight: screenH * 0.82),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: emeraldLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(LucideIcons.indianRupee,
                      color: emerald, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Today's Sale",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: Color(0xFF111827),
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        '${groups.length} unique receipt${groups.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currencyFormat.format(totalRevenue),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        color: emerald,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Total Revenue',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Divider
          Divider(height: 1, color: Colors.grey.shade100),

          // Receipts list
          Flexible(
            child: groups.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.packageOpen,
                            size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'No sales recorded today',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Snap a new order to get started!',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    shrinkWrap: true,
                    itemCount: groups.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      final vNum = group.extraFields['vehicle_number']?.toString() ?? '';
                      final String displayName = group.customerName.isNotEmpty
                          ? group.customerName
                          : (vNum.isNotEmpty
                              ? vNum
                              : 'Unknown Customer');
                      final String initial = displayName[0].toUpperCase();
                      final String receiptLabel = group.receiptNumber.isNotEmpty
                          ? '#${group.receiptNumber}'
                          : 'No Receipt #';
                      final int itemCount = group.items.length;

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: Colors.grey.shade100, width: 1),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              // Avatar
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: emerald.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  initial,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: emerald,
                                    fontSize: 17,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: Color(0xFF111827),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: emeraldLight,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            receiptLabel,
                                            style: const TextStyle(
                                              color: emerald,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 10,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '$itemCount item${itemCount == 1 ? '' : 's'}',
                                          style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Amount
                              Text(
                                currencyFormat.format(group.totalAmount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  color: Color(0xFF111827),
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
