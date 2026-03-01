import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/features/dashboard/domain/models/dashboard_models.dart';
import 'package:mobile/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:mobile/features/purchase_orders/presentation/providers/purchase_order_provider.dart';
import 'package:mobile/features/notifications/presentation/providers/notification_provider.dart';
import 'package:mobile/shared/widgets/metric_card.dart';
import 'package:mobile/shared/widgets/shimmer_placeholders.dart';
import 'package:intl/intl.dart';
import 'package:mobile/features/dashboard/presentation/widgets/sales_trend_chart.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(dashboardProvider);
    final userState = ref.watch(authProvider);

    final String userName =
        userState.user?.name ?? userState.user?.username ?? 'User';

    final currencyFormat =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dashboard',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            Text('Welcome back, $userName',
                style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          // Bell badge
          Consumer(
            builder: (context, ref, _) {
              final unread = ref.watch(unreadCountProvider);
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.bell),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.pushNamed('notifications');
                    },
                  ),
                  if (unread > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        constraints:
                            const BoxConstraints(minWidth: 18, minHeight: 18),
                        decoration: const BoxDecoration(
                          color: AppTheme.error,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          unread > 99 ? '99+' : '$unread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.logOut),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(dashboardProvider.notifier).refreshDashboard();
        },
        child: _buildBody(dashboardState, currencyFormat),
      ),
    );
  }

  Widget _buildBody(DashboardState state, NumberFormat currencyFormat) {
    if (state.isLoading && state.kpis == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quick Actions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: List.generate(4, (index) => const MetricCardShimmer()),
            ),
            const SizedBox(height: 32),
            const ChartShimmer(),
            const SizedBox(height: 32),
            const ChartShimmer(),
          ],
        ),
      );
    }

    if (state.error != null && state.kpis == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.alertCircle,
                color: AppTheme.error, size: 48),
            const SizedBox(height: 16),
            Text('Failed to load dashboard: ${state.error}',
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  ref.read(dashboardProvider.notifier).refreshDashboard(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final pendingSalesCount =
        state.kpis?.pendingActions.currentValue.toInt() ?? 0;

    // Calculate unmapped items safely
    int unmappedCount = 0;
    if (state.rawStockLevels != null &&
        state.rawStockLevels!['items'] != null) {
      final items = state.rawStockLevels!['items'] as List;
      unmappedCount = items
          .where((item) =>
              item['customer_items'] == null ||
              item['customer_items'] == false ||
              item['customer_items'].toString().trim().isEmpty)
          .length;
    }

    final outOfStockCount = state.stockSummary?.outOfStockCount ?? 0;
    final totalSales = state.kpis?.totalRevenue.currentValue ?? 0;
    final salesChange = state.kpis?.totalRevenue.changePercent;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Period Selector + Filter Row ─────────────────────────────────
          Row(
            children: [
              Expanded(child: _PeriodSelector(activePeriod: state.period)),
              const SizedBox(width: 8),
              _FilterToggleButton(
                isExpanded: state.filtersExpanded,
                activeFilterCount: state.activeFilterCount,
              ),
            ],
          ),

          // ── Active Filter Chips ──────────────────────────────────────────
          if (state.hasActiveFilters) _ActiveFilterChips(state: state),

          // ── Advanced Filters Panel ───────────────────────────────────────
          if (state.filtersExpanded) ...[
            const SizedBox(height: 8),
            const _AdvancedFiltersPanel(),
          ],

          const SizedBox(height: 16),

          // ── Quick Action KPIs ────────────────────────────────────────────
          const Text('Quick Actions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildActionCardsGrid(
            pendingSalesCount: pendingSalesCount,
            unmappedItemsCount: unmappedCount,
            outOfStockCount: outOfStockCount,
            totalSales: totalSales,
            salesChange: salesChange,
            currencyFormat: currencyFormat,
          ),

          const SizedBox(height: 24),

          // ── Inventory Command Center ─────────────────────────────────────
          const _DashboardCommandCenter(),

          const SizedBox(height: 24),

          // ── Sales Trend Chart ─────────────────────────────────────────────
          SalesTrendChart(
            data: state.dailySales ?? [],
            isLoading: state.isLoading && state.dailySales == null,
          ),
        ],
      ),
    );
  }

  Widget _buildActionCardsGrid({
    required int pendingSalesCount,
    required int unmappedItemsCount,
    required int outOfStockCount,
    required double totalSales,
    required double? salesChange,
    required NumberFormat currencyFormat,
  }) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        MetricCard(
          title: 'REVIEW & SYNC',
          value: pendingSalesCount.toString(),
          icon: LucideIcons.scanLine,
          theme: MetricTheme.blue,
          actionLabel: 'Process Now',
          onAction: () {
            HapticFeedback.lightImpact();
            context.pushNamed('review');
          },
        ),
        MetricCard(
          title: 'UNMAPPED ITEMS',
          value: unmappedItemsCount.toString(),
          icon: LucideIcons.packageX,
          theme: MetricTheme.amber,
          actionLabel: 'Map Items',
          onAction: () {
            HapticFeedback.lightImpact();
            context.pushNamed('inventory-item-mapping');
          },
        ),
        MetricCard(
          title: 'OUT OF STOCK',
          value: outOfStockCount.toString(),
          icon: LucideIcons.alertTriangle,
          theme: MetricTheme.red,
          actionLabel: 'Restock List',
          isLinkAction: true,
          onAction: () {
            HapticFeedback.lightImpact();
            context.pushNamed('current-stock');
          },
        ),
        MetricCard(
          title: 'TOTAL SALES',
          value: currencyFormat.format(totalSales),
          icon: LucideIcons.indianRupee,
          theme: MetricTheme.green,
          trendValue: salesChange,
        ),
      ]
          .animate(interval: 50.ms)
          .fade(duration: 300.ms)
          .scale(curve: Curves.easeOutBack, duration: 400.ms),
    );
  }
}

// ─── Period Selector ──────────────────────────────────────────────────────────

class _PeriodSelector extends ConsumerWidget {
  final DashboardPeriod activePeriod;
  const _PeriodSelector({required this.activePeriod});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: DashboardPeriod.values.map((period) {
          final isActive = period == activePeriod;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (!isActive) {
                  HapticFeedback.selectionClick();
                  ref.read(dashboardProvider.notifier).changePeriod(period);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  period.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.white : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Filter Toggle Button ─────────────────────────────────────────────────────

class _FilterToggleButton extends ConsumerWidget {
  final bool isExpanded;
  final int activeFilterCount;
  const _FilterToggleButton(
      {required this.isExpanded, required this.activeFilterCount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: isExpanded ? AppTheme.primary : AppTheme.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(dashboardProvider.notifier).toggleFiltersExpanded();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isExpanded ? AppTheme.primary : AppTheme.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.sliders,
                size: 16,
                color: isExpanded ? Colors.white : AppTheme.textSecondary,
              ),
              if (activeFilterCount > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isExpanded
                        ? Colors.white.withOpacity(0.25)
                        : AppTheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$activeFilterCount',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Active Filter Chips ──────────────────────────────────────────────────────

class _ActiveFilterChips extends ConsumerWidget {
  final DashboardState state;
  const _ActiveFilterChips({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(dashboardProvider.notifier);

    Widget chip(String label, VoidCallback onRemove) => Container(
          margin: const EdgeInsets.only(right: 6, top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primary.withOpacity(0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary)),
              const SizedBox(width: 5),
              GestureDetector(
                onTap: onRemove,
                child: const Icon(LucideIcons.x,
                    size: 12, color: AppTheme.primary),
              ),
            ],
          ),
        );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (state.customerFilter.isNotEmpty)
            chip('Customer: ${state.customerFilter}', () {
              notifier.setCustomerFilter('');
              notifier.applyFilters();
            }),
          if (state.vehicleFilter.isNotEmpty)
            chip('Vehicle: ${state.vehicleFilter}', () {
              notifier.setVehicleFilter('');
              notifier.applyFilters();
            }),
          if (state.partNumberFilter.isNotEmpty)
            chip('Item: ${state.partNumberFilter}', () {
              notifier.setPartNumberFilter('');
              notifier.applyFilters();
            }),
          GestureDetector(
            onTap: notifier.clearFilters,
            child: Container(
              margin: const EdgeInsets.only(right: 6, top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.error.withOpacity(0.25)),
              ),
              child: const Text('Clear All',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.error)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Advanced Filters Panel ───────────────────────────────────────────────────

class _AdvancedFiltersPanel extends ConsumerStatefulWidget {
  const _AdvancedFiltersPanel();

  @override
  ConsumerState<_AdvancedFiltersPanel> createState() =>
      _AdvancedFiltersPanelState();
}

class _AdvancedFiltersPanelState extends ConsumerState<_AdvancedFiltersPanel> {
  late final TextEditingController _customerCtrl;
  late final TextEditingController _vehicleCtrl;
  late final TextEditingController _partCtrl;

  @override
  void initState() {
    super.initState();
    final s = ref.read(dashboardProvider);
    _customerCtrl = TextEditingController(text: s.customerFilter);
    _vehicleCtrl = TextEditingController(text: s.vehicleFilter);
    _partCtrl = TextEditingController(text: s.partNumberFilter);
  }

  @override
  void dispose() {
    _customerCtrl.dispose();
    _vehicleCtrl.dispose();
    _partCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(dashboardProvider.notifier);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filter Dashboard Data',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _FilterField(
            controller: _customerCtrl,
            hint: 'e.g. Ravi Motors',
            icon: LucideIcons.user,
            label: 'Customer',
          ),
          const SizedBox(height: 8),
          _FilterField(
            controller: _vehicleCtrl,
            hint: 'e.g. MH12AB1234',
            icon: LucideIcons.car,
            label: 'Vehicle',
          ),
          const SizedBox(height: 8),
          _FilterField(
            controller: _partCtrl,
            hint: 'Item or part name',
            icon: LucideIcons.package,
            label: 'Part / Item',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _customerCtrl.clear();
                    _vehicleCtrl.clear();
                    _partCtrl.clear();
                    notifier.clearFilters();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: const BorderSide(color: AppTheme.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    notifier.setCustomerFilter(_customerCtrl.text.trim());
                    notifier.setVehicleFilter(_vehicleCtrl.text.trim());
                    notifier.setPartNumberFilter(_partCtrl.text.trim());
                    notifier.applyFilters();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Apply Filters'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String label;
  final IconData icon;
  const _FilterField({
    required this.controller,
    required this.hint,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        prefixIcon: Icon(icon, size: 16, color: AppTheme.textSecondary),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: AppTheme.primary),
        ),
      ),
    );
  }
}

// ─── Dashboard Inventory Command Center ───────────────────────────────────────

class _DashboardCommandCenter extends ConsumerStatefulWidget {
  const _DashboardCommandCenter();

  @override
  ConsumerState<_DashboardCommandCenter> createState() =>
      _DashboardCommandCenterState();
}

class _DashboardCommandCenterState
    extends ConsumerState<_DashboardCommandCenter> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _isSearching = false;
  List<Map<String, dynamic>> _results = [];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    setState(() {
      _query = q;
      _isSearching = q.isNotEmpty;
    });
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }
    try {
      final raw = await ref.read(dashboardRepositoryProvider).getStockLevels();
      final items = (raw['items'] as List? ?? []);
      final lower = q.toLowerCase();
      setState(() {
        _results = items
            .where((item) {
              final name = item.itemName?.toString().toLowerCase() ?? '';
              final part = item.partNumber?.toString().toLowerCase() ?? '';
              return name.contains(lower) || part.contains(lower);
            })
            .take(20)
            .map<Map<String, dynamic>>((item) {
              return {
                'part_number': item.partNumber ?? '',
                'item_name': item.itemName ?? '',
                'current_stock': (item.currentStock as num?)?.toDouble() ?? 0.0,
                'reorder_point': (item.reorderPoint as num?)?.toDouble() ?? 0.0,
                'priority': item.priority ?? '',
                'unit_value': (item.unitValue as num?)?.toDouble(),
              };
            })
            .toList();
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashState = ref.watch(dashboardProvider);
    // Fallback: show low-stock alert items when no search
    final alertItems = dashState.stockAlerts
        .map((a) => {
              'part_number': a.partNumber,
              'item_name': a.itemName,
              'current_stock': a.currentStock,
              'reorder_point': a.reorderPoint,
              'priority': '',
              'unit_value': null,
            })
        .toList();
    final displayItems = _query.isEmpty ? alertItems : _results;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(LucideIcons.shoppingCart,
                      size: 16, color: AppTheme.primary),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quick Reorder',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                      Text('Search & add items directly to PO',
                          style: TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.pushNamed('purchase-orders');
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('View PO',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary)),
                  ),
                ),
              ],
            ),
          ),
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontSize: 13),
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Search by item name or part number...',
                hintStyle: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary),
                prefixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 1.5)))
                    : const Icon(LucideIcons.search,
                        size: 16, color: AppTheme.textSecondary),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(LucideIcons.x,
                            size: 14, color: AppTheme.textSecondary),
                        onPressed: () {
                          _searchCtrl.clear();
                          _search('');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                filled: true,
                fillColor: AppTheme.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.primary),
                ),
              ),
            ),
          ),
          // Items
          if (displayItems.isEmpty && !_isSearching)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Center(
                child: Text('All items in stock! 🎉',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemCount: displayItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, i) =>
                  _CommandCenterItemRow(item: displayItems[i]),
            ),
        ],
      ),
    );
  }
}

class _CommandCenterItemRow extends ConsumerStatefulWidget {
  final Map<String, dynamic> item;
  const _CommandCenterItemRow({required this.item});

  @override
  ConsumerState<_CommandCenterItemRow> createState() =>
      _CommandCenterItemRowState();
}

class _CommandCenterItemRowState extends ConsumerState<_CommandCenterItemRow> {
  bool _adding = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final partNumber = item['part_number'] as String? ?? '';
    final itemName = item['item_name'] as String? ?? '';
    final stock = (item['current_stock'] as num?)?.toDouble() ?? 0;
    final reorder = (item['reorder_point'] as num?)?.toDouble() ?? 0;
    final priority = item['priority'] as String? ?? '';

    final isOut = stock <= 0;
    final isLow = !isOut && stock < reorder;
    final statusColor = isOut
        ? AppTheme.error
        : isLow
            ? AppTheme.warning
            : AppTheme.success;
    final statusLabel = isOut
        ? 'Out'
        : isLow
            ? 'Low'
            : 'OK';

    final poState = ref.watch(purchaseOrderProvider);
    final alreadyInDraft =
        poState.draft.items.any((i) => i.partNumber == partNumber);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          if (priority.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(priority,
                  style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary)),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(itemName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(partNumber,
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$statusLabel ${stock.toStringAsFixed(0)}',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: statusColor),
            ),
          ),
          if (alreadyInDraft)
            const Icon(LucideIcons.checkCircle,
                size: 18, color: AppTheme.success)
          else
            GestureDetector(
              onTap: _adding
                  ? null
                  : () async {
                      HapticFeedback.lightImpact();
                      setState(() => _adding = true);
                      await ref
                          .read(purchaseOrderProvider.notifier)
                          .quickAddFromDashboard(item);
                      if (mounted) setState(() => _adding = false);
                    },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _adding
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: AppTheme.primary))
                    : const Icon(LucideIcons.plus,
                        size: 14, color: AppTheme.primary),
              ),
            ),
        ],
      ),
    );
  }
}
