import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/purchase_orders/presentation/providers/quick_reorder_provider.dart';
import 'package:mobile/features/purchase_orders/presentation/providers/purchase_order_provider.dart';
import 'package:go_router/go_router.dart';

class QuickReorderPage extends ConsumerStatefulWidget {
  const QuickReorderPage({super.key});

  @override
  ConsumerState<QuickReorderPage> createState() => _QuickReorderPageState();
}

class _QuickReorderPageState extends ConsumerState<QuickReorderPage> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Refresh the list when opening the page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(quickReorderProvider.notifier).loadItems(reset: true);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    ref.read(quickReorderProvider.notifier).setSearchQuery(value);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quickReorderProvider);
    final notifier = ref.read(quickReorderProvider.notifier);
    final poState = ref.watch(purchaseOrderProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Quick Reorder',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.shoppingBag),
            onPressed: () {
              HapticFeedback.lightImpact();
              context.pushNamed('purchase-orders');
            },
            tooltip: 'View Purchase Orders',
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(LucideIcons.shoppingCart),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.pushNamed('create-po');
                },
                tooltip: 'Draft PO',
              ),
              if (poState.draft.items.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${poState.draft.items.length}',
                      style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Sticky Search Bar
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by item name or part number...',
                hintStyle: const TextStyle(color: AppTheme.textSecondary),
                prefixIcon: const Icon(LucideIcons.search,
                    color: AppTheme.textSecondary),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.background,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppTheme.primary, width: 2),
                ),
              ),
            ),
          ),

          // Main List
          Expanded(
            child: state.isLoading && state.items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.error != null && state.items.isEmpty
                    ? Center(
                        child: Text(
                          'Error loading items: ${state.error}',
                          style: const TextStyle(color: AppTheme.error),
                        ),
                      )
                    : state.items.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(LucideIcons.packageOpen,
                                    size: 48, color: AppTheme.textSecondary),
                                SizedBox(height: 16),
                                Text(
                                  'No items found',
                                  style: TextStyle(
                                      fontSize: 16,
                                      color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => notifier.loadItems(reset: true),
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: state.items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = state.items[index];
                                return QuickReorderItemCard(item: item);
                              },
                            ),
                          ),
          ),

          // Pagination Footer
          if (state.totalItems > 0 && !state.isLoading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Showing ${(state.currentPage * QuickReorderState.itemsPerPage) + 1} - ${(state.currentPage * QuickReorderState.itemsPerPage) + state.items.length} of ${state.totalItems}',
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(LucideIcons.chevronLeft),
                          onPressed: state.currentPage > 0
                              ? () {
                                  HapticFeedback.selectionClick();
                                  notifier.loadPreviousPage();
                                }
                              : null,
                          color: AppTheme.primary,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Page ${state.currentPage + 1}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.chevronRight),
                          onPressed: (state.currentPage + 1) *
                                      QuickReorderState.itemsPerPage <
                                  state.totalItems
                              ? () {
                                  HapticFeedback.selectionClick();
                                  notifier.loadNextPage();
                                }
                              : null,
                          color: AppTheme.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class QuickReorderItemCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> item;

  const QuickReorderItemCard({super.key, required this.item});

  @override
  ConsumerState<QuickReorderItemCard> createState() =>
      _QuickReorderItemCardState();
}

class _QuickReorderItemCardState extends ConsumerState<QuickReorderItemCard> {
  bool _isAdding = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final partNumber = item['part_number'] as String? ?? '';
    final itemName = item['internal_item_name'] as String? ??
        item['item_name'] as String? ??
        'Unknown Item';

    // Calculate actual on hand similar to what was done in DashboardCommandCenter
    final currentStock = (item['current_stock'] as num?)?.toDouble() ?? 0;
    final manualAdj = (item['manual_adjustment'] as num?)?.toDouble() ?? 0;
    final stock = currentStock + manualAdj;

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
        ? 'Out of Stock'
        : isLow
            ? 'Low Stock'
            : 'In Stock';
    final statusIcon = isOut
        ? LucideIcons.xCircle
        : isLow
            ? LucideIcons.alertTriangle
            : LucideIcons.checkCircle2;

    final poState = ref.watch(purchaseOrderProvider);
    final alreadyInDraft =
        poState.draft.items.any((i) => i.partNumber == partNumber);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (priority.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                priority,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              itemName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        partNumber,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildMetricColumn('On Hand', stock.toStringAsFixed(0)),
                    const SizedBox(width: 24),
                    _buildMetricColumn(
                        'Min Reorder', reorder.toStringAsFixed(0)),
                  ],
                ),
                SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: alreadyInDraft || _isAdding
                        ? null
                        : () async {
                            HapticFeedback.mediumImpact();
                            setState(() => _isAdding = true);

                            // Map to expected format for quickAddFromDashboard
                            final poItemFormat = {
                              'part_number': partNumber,
                              'item_name': itemName,
                              'current_stock': stock,
                              'reorder_point': reorder,
                              'priority': priority,
                              'unit_value': item['unit_value'],
                            };

                            await ref
                                .read(purchaseOrderProvider.notifier)
                                .quickAddFromDashboard(poItemFormat);

                            if (mounted) setState(() => _isAdding = false);
                          },
                    icon: _isAdding
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Icon(
                            alreadyInDraft
                                ? LucideIcons.check
                                : LucideIcons.plus,
                            size: 16),
                    label: Text(alreadyInDraft ? 'Added' : 'Add to PO'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          alreadyInDraft ? AppTheme.success : AppTheme.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: alreadyInDraft
                          ? AppTheme.success.withValues(alpha: 0.5)
                          : null,
                      disabledForegroundColor:
                          alreadyInDraft ? Colors.white : null,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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

  Widget _buildMetricColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
