import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/inventory/data/current_stock_repository.dart';
import 'package:mobile/features/inventory/domain/models/current_stock_models.dart';
import 'package:mobile/features/inventory/presentation/providers/current_stock_provider.dart';
import 'package:intl/intl.dart';
import 'package:mobile/shared/widgets/shimmer_placeholders.dart';
import 'package:mobile/shared/widgets/app_toast.dart';
import 'package:mobile/features/purchase_orders/domain/models/purchase_order_models.dart';
import 'package:mobile/features/purchase_orders/presentation/providers/purchase_order_provider.dart';
import 'package:share_plus/share_plus.dart';

class CurrentStockPage extends ConsumerStatefulWidget {
  const CurrentStockPage({super.key});

  @override
  ConsumerState<CurrentStockPage> createState() => _CurrentStockPageState();
}

class _CurrentStockPageState extends ConsumerState<CurrentStockPage> {
  final TextEditingController _searchController = TextEditingController();

  bool _isExporting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _exportStock(CurrentStockState state) async {
    setState(() => _isExporting = true);
    try {
      final repo = CurrentStockRepository();
      final filePath = await repo.exportStockLevels(
        search: state.searchQuery.isEmpty ? null : state.searchQuery,
        statusFilter: state.statusFilter == 'all' ? null : state.statusFilter,
        priorityFilter:
            state.priorityFilter == 'all' ? null : state.priorityFilter,
      );
      // share_plus v10 API
      await Share.shareXFiles(
        [
          XFile(filePath,
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        ],
        subject: 'DigiEntry Stock Export',
        text: 'Stock register exported from DigiEntry',
      );
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Export failed: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(currentStockProvider);
    final poState = ref.watch(purchaseOrderProvider);
    final NumberFormat currencyFormat =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Current Stock',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // Cart Button
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(LucideIcons.shoppingCart),
                tooltip: 'Purchase Orders',
                onPressed: () => context.push('/purchase-orders'),
              ),
              if (poState.hasDraftItems)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppTheme.error,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Center(
                      child: Text(
                        '${poState.draftCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Export button
          _isExporting
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  icon: const Icon(LucideIcons.download),
                  tooltip: 'Export to Excel',
                  onPressed: () => _exportStock(state),
                ),
          // Recalculate button
          if (state.isCalculating)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(LucideIcons.refreshCw),
              onPressed: () => ref
                  .read(currentStockProvider.notifier)
                  .triggerRecalculation(),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(currentStockProvider.notifier).fetchData(),
        child: NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification scrollInfo) {
            if (!state.isLoading &&
                state.hasMore &&
                scrollInfo.metrics.pixels >=
                    scrollInfo.metrics.maxScrollExtent - 200) {
              ref.read(currentStockProvider.notifier).fetchMoreData();
            }
            return false;
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Search box (top) ──
                      TextField(
                        controller: _searchController,
                        onChanged: (v) => ref
                            .read(currentStockProvider.notifier)
                            .setSearchQuery(v),
                        decoration: InputDecoration(
                          hintText: 'Search part number or name...',
                          prefixIcon: const Icon(LucideIcons.search, size: 20),
                          suffixIcon: state.searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(LucideIcons.x, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref
                                        .read(currentStockProvider.notifier)
                                        .setSearchQuery('');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: AppTheme.surface,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ── Status Filter chips ──
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _StatusChip(
                              label: 'All',
                              value: 'all',
                              current: state.statusFilter,
                              color: Colors.blueGrey,
                              onTap: () => ref
                                  .read(currentStockProvider.notifier)
                                  .setFilters(status: 'all'),
                            ),
                            const SizedBox(width: 8),
                            _StatusChip(
                              label: 'In Stock',
                              value: 'in_stock',
                              current: state.statusFilter,
                              color: Colors.green,
                              icon: LucideIcons.checkCircle2,
                              onTap: () => ref
                                  .read(currentStockProvider.notifier)
                                  .setFilters(status: 'in_stock'),
                            ),
                            const SizedBox(width: 8),
                            _StatusChip(
                              label: 'Low Stock',
                              value: 'low_stock',
                              current: state.statusFilter,
                              color: Colors.orange,
                              icon: LucideIcons.alertTriangle,
                              onTap: () => ref
                                  .read(currentStockProvider.notifier)
                                  .setFilters(status: 'low_stock'),
                            ),
                            const SizedBox(width: 8),
                            _StatusChip(
                              label: 'Out of Stock',
                              value: 'out_of_stock',
                              current: state.statusFilter,
                              color: Colors.red,
                              icon: LucideIcons.alertCircle,
                              onTap: () => ref
                                  .read(currentStockProvider.notifier)
                                  .setFilters(status: 'out_of_stock'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // ── Priority Filter chips ──
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _PriorityChip(
                              label: 'All Priority',
                              value: 'all',
                              current: state.priorityFilter,
                              onTap: () => ref
                                  .read(currentStockProvider.notifier)
                                  .setFilters(priority: 'all'),
                            ),
                            const SizedBox(width: 8),
                            _PriorityChip(
                              label: 'P0',
                              value: 'P0',
                              current: state.priorityFilter,
                              onTap: () => ref
                                  .read(currentStockProvider.notifier)
                                  .setFilters(priority: 'P0'),
                            ),
                            const SizedBox(width: 8),
                            _PriorityChip(
                              label: 'P1',
                              value: 'P1',
                              current: state.priorityFilter,
                              onTap: () => ref
                                  .read(currentStockProvider.notifier)
                                  .setFilters(priority: 'P1'),
                            ),
                            const SizedBox(width: 8),
                            _PriorityChip(
                              label: 'P2',
                              value: 'P2',
                              current: state.priorityFilter,
                              onTap: () => ref
                                  .read(currentStockProvider.notifier)
                                  .setFilters(priority: 'P2'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ── Stats row ──
                      Row(
                        children: [
                          Expanded(
                              child: _buildStatCard(
                                  'Value',
                                  currencyFormat
                                      .format(state.summary.totalStockValue),
                                  Colors.blue)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _buildStatCard(
                                  'Items',
                                  state.summary.totalItems.toString(),
                                  Colors.purple)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                              child: _buildStatCard(
                                  'Low Stock',
                                  state.summary.lowStockItems.toString(),
                                  Colors.orange)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _buildStatCard(
                                  'Out of Stock',
                                  state.summary.outOfStock.toString(),
                                  Colors.red)),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // Item List
              if (state.isLoading && state.items.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppTheme.border.withOpacity(0.5)),
                            ),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ShimmerPlaceholder(width: 150, height: 16),
                                SizedBox(height: 8),
                                ShimmerPlaceholder(width: 80, height: 12),
                                SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ShimmerPlaceholder(
                                            width: 40, height: 10),
                                        SizedBox(height: 4),
                                        ShimmerPlaceholder(
                                            width: 60, height: 20),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ShimmerPlaceholder(
                                            width: 40, height: 10),
                                        SizedBox(height: 4),
                                        ShimmerPlaceholder(
                                            width: 60, height: 20),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ShimmerPlaceholder(
                                            width: 40, height: 10),
                                        SizedBox(height: 4),
                                        ShimmerPlaceholder(
                                            width: 60, height: 20),
                                      ],
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: 5,
                    ),
                  ),
                )
              else if (state.error != null && state.items.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.alertCircle,
                            color: AppTheme.error, size: 48),
                        const SizedBox(height: 16),
                        Text('Error: ${state.error}',
                            style: const TextStyle(color: AppTheme.error)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => ref
                              .read(currentStockProvider.notifier)
                              .fetchData(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (state.items.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                      child: Text('No stock items found',
                          style: TextStyle(color: AppTheme.textSecondary))),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = state.items[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildStockCard(context, ref, item),
                        );
                      },
                      childCount: state.items.length,
                    ),
                  ),
                ),

              if (state.hasMore && state.items.isNotEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color.shade700)),
        ],
      ),
    );
  }

  Widget _buildStockCard(BuildContext context, WidgetRef ref, StockLevel item) {
    final onHandValue = item.currentStock + (item.manualAdjustment ?? 0);
    final isOutOfStock = onHandValue <= 0;
    final isLowStock = !isOutOfStock && onHandValue <= item.reorderPoint;
    final isOnHandLow = isOutOfStock || isLowStock;

    Color statusColor =
        isOutOfStock ? Colors.red : (isLowStock ? Colors.orange : Colors.green);
    Color statusBg = isOutOfStock
        ? Colors.red.shade50
        : (isLowStock ? Colors.orange.shade50 : Colors.green.shade50);
    Color statusBorder = isOutOfStock
        ? Colors.red.shade200
        : (isLowStock ? Colors.orange.shade200 : Colors.green.shade200);
    IconData statusIcon = isOutOfStock
        ? LucideIcons.alertCircle
        : (isLowStock ? LucideIcons.alertTriangle : LucideIcons.checkCircle2);
    String statusLabel =
        isOutOfStock ? 'Out of Stock' : (isLowStock ? 'Low Stock' : 'In Stock');

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isOnHandLow ? statusBorder : AppTheme.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(item.internalItemName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                          if (item.priority != null &&
                              item.priority!.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: _priorityColor(item.priority!)
                                    .withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: _priorityColor(item.priority!)
                                        .withOpacity(0.5)),
                              ),
                              child: Text(
                                item.priority!,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _priorityColor(item.priority!)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Part #: ${item.partNumber}',
                          style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              fontFamily: 'monospace')),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: statusColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (item.customerItems != null &&
                item.customerItems!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(LucideIcons.link,
                      size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(item.customerItems!,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ),
                ],
              ),
            ],
            const Divider(height: 24),

            // Stock values row
            Row(
              children: [
                Expanded(
                  child: _buildEditableValue(
                      context,
                      'On Hand',
                      onHandValue.toString(),
                      isOnHandLow ? statusColor : AppTheme.textPrimary,
                      () => _showUpdateStockSheet(context, ref, item, true)),
                ),
                Container(width: 1, height: 40, color: AppTheme.border),
                Expanded(
                  child: _buildEditableValue(
                      context,
                      'Reorder Pt',
                      item.reorderPoint.toString(),
                      AppTheme.textPrimary,
                      () => _showUpdateStockSheet(context, ref, item, false)),
                ),
                Container(width: 1, height: 40, color: AppTheme.border),
                Expanded(
                  child: _buildEditableValue(
                      context,
                      'Pur. Price',
                      item.unitValue != null
                          ? '₹${item.unitValue!.toStringAsFixed(0)}'
                          : '-',
                      AppTheme.textPrimary,
                      () => _showUpdatePurchasePriceSheet(context, ref, item)),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Action buttons row
            Row(
              children: [
                // Add to PO button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showAddToPODialog(context, ref, item),
                    icon: const Icon(LucideIcons.shoppingCart, size: 14),
                    label:
                        const Text('Add to PO', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side:
                          BorderSide(color: AppTheme.primary.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _priorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'P0':
        return Colors.red.shade700;
      case 'P1':
        return Colors.orange.shade700;
      case 'P2':
        return Colors.blue.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  Widget _buildEditableValue(BuildContext context, String label, String value,
      Color valueColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
                const SizedBox(width: 4),
                const Icon(LucideIcons.edit2,
                    size: 10, color: AppTheme.primary),
              ],
            ),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: valueColor)),
          ],
        ),
      ),
    );
  }

  void _showUpdateStockSheet(BuildContext context, WidgetRef ref,
      StockLevel item, bool isPhysicalCount) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _UpdateStockSheet(item: item, isPhysicalCount: isPhysicalCount),
      ),
    );
  }

  void _showUpdatePurchasePriceSheet(
      BuildContext context, WidgetRef ref, StockLevel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _UpdatePurchasePriceSheet(item: item),
      ),
    );
  }

  void _showAddToPODialog(
      BuildContext context, WidgetRef ref, StockLevel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _AddToPOSheet(item: item),
      ),
    );
  }
}

class _AddToPOSheet extends ConsumerStatefulWidget {
  final StockLevel item;

  const _AddToPOSheet({required this.item});

  @override
  ConsumerState<_AddToPOSheet> createState() => _AddToPOSheetState();
}

class _AddToPOSheetState extends ConsumerState<_AddToPOSheet> {
  late TextEditingController qtyController;
  bool isAdding = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    qtyController = TextEditingController(
        text: (item.reorderPoint -
                (item.currentStock + (item.manualAdjustment ?? 0)))
            .clamp(1, 9999)
            .toInt()
            .toString());
  }

  @override
  void dispose() {
    qtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.shoppingCart, color: AppTheme.primary, size: 22),
              SizedBox(width: 10),
              Text('Add to Purchase Order',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text(item.internalItemName,
              style: const TextStyle(color: AppTheme.textSecondary)),
          Text('Part #: ${item.partNumber}',
              style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontFamily: 'monospace')),
          const SizedBox(height: 20),
          const Text('Quantity to Order',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: qtyController,
            keyboardType: TextInputType.number,
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppTheme.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isAdding
                  ? null
                  : () async {
                      final qty = int.tryParse(qtyController.text) ?? 0;
                      if (qty > 0) {
                        setState(() => isAdding = true);
                        // Capture context-dependent refs before the async gap
                        final ctx = context;
                        try {
                          final draftItem = DraftPoItem(
                            partNumber: item.partNumber,
                            itemName: item.internalItemName,
                            currentStock: (item.currentStock +
                                    (item.manualAdjustment ?? 0))
                                .toDouble(),
                            reorderPoint: item.reorderPoint.toDouble(),
                            reorderQty: qty,
                            unitValue: item.unitValue, // Passed directly
                            priority: item.priority ?? 'P2',
                            supplierName: null, // StockLevel has no supplier
                          );
                          final ok = await ref
                              .read(purchaseOrderProvider.notifier)
                              .addItem(draftItem);
                          if (!mounted) return;
                          if (ok) {
                            // ignore: use_build_context_synchronously
                            AppToast.showSuccess(ctx,
                                '${item.internalItemName} (×$qty) added to PO Draft');
                            // ignore: use_build_context_synchronously
                            Navigator.pop(ctx);
                          } else {
                            setState(() => isAdding = false);
                            // ignore: use_build_context_synchronously
                            AppToast.showError(
                                // ignore: use_build_context_synchronously
                                ctx,
                                'Failed to add item to PO Draft');
                          }
                        } catch (e) {
                          if (!mounted) return;
                          setState(() => isAdding = false);
                          // ignore: use_build_context_synchronously
                          AppToast.showError(ctx, e.toString());
                        }
                      }
                    },
              icon: isAdding
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(LucideIcons.plus, size: 18),
              label: Text(isAdding ? 'Adding...' : 'Add to PO',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _UpdateStockSheet extends ConsumerStatefulWidget {
  final StockLevel item;
  final bool isPhysicalCount;

  const _UpdateStockSheet({required this.item, required this.isPhysicalCount});

  @override
  ConsumerState<_UpdateStockSheet> createState() => _UpdateStockSheetState();
}

class _UpdateStockSheetState extends ConsumerState<_UpdateStockSheet> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final initialValue = widget.isPhysicalCount
        ? widget.item.currentStock + (widget.item.manualAdjustment ?? 0)
        : widget.item.reorderPoint;
    _controller = TextEditingController(text: initialValue.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = int.tryParse(_controller.text);
    if (value != null) {
      if (widget.isPhysicalCount) {
        ref
            .read(currentStockProvider.notifier)
            .updatePhysicalCount(widget.item.id, value);
        AppToast.showSuccess(context, 'Physical count updated');
      } else {
        ref
            .read(currentStockProvider.notifier)
            .updateStockLevel(widget.item.id, 'reorder_point', value);
        AppToast.showSuccess(context, 'Reorder point updated');
      }
    }
    if (!context.mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isPhysicalCount
                ? 'Update Physical Count'
                : 'Set Reorder Point',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            widget.item.internalItemName,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppTheme.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Save Changes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _UpdatePurchasePriceSheet extends ConsumerStatefulWidget {
  final StockLevel item;

  const _UpdatePurchasePriceSheet({required this.item});

  @override
  ConsumerState<_UpdatePurchasePriceSheet> createState() =>
      _UpdatePurchasePriceSheetState();
}

class _UpdatePurchasePriceSheetState
    extends ConsumerState<_UpdatePurchasePriceSheet> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
        text: widget.item.unitValue != null
            ? widget.item.unitValue!.toStringAsFixed(2)
            : '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = double.tryParse(_controller.text);
    if (value != null && value >= 0) {
      ref
          .read(currentStockProvider.notifier)
          .updateStockLevel(widget.item.id, 'unit_value', value);
      AppToast.showSuccess(context, 'Purchase Price updated');
    }
    if (!context.mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Set Purchase Price',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            widget.item.internalItemName,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppTheme.surface,
              prefixText: '₹ ',
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Save Price',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Filter chip widgets ──────────────────────────────

class _StatusChip extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final Color color;
  final IconData? icon;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.value,
    required this.current,
    required this.color,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = current == value;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : AppTheme.border,
              width: selected ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 13, color: selected ? color : AppTheme.textSecondary),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? color : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final VoidCallback onTap;

  const _PriorityChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onTap,
  });

  Color _color() {
    switch (value.toUpperCase()) {
      case 'P0':
        return Colors.red.shade700;
      case 'P1':
        return Colors.orange.shade700;
      case 'P2':
        return Colors.blue.shade700;
      default:
        return Colors.blueGrey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = current == value;
    final color = _color();
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : AppTheme.border,
              width: selected ? 1.5 : 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? color : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
