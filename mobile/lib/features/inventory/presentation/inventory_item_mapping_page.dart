import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/inventory/domain/models/current_stock_models.dart';
import 'package:mobile/features/inventory/presentation/providers/inventory_item_mapping_provider.dart';
import 'package:mobile/shared/widgets/shimmer_placeholders.dart';

class InventoryItemMappingPage extends ConsumerStatefulWidget {
  const InventoryItemMappingPage({super.key});

  @override
  ConsumerState<InventoryItemMappingPage> createState() =>
      _InventoryItemMappingPageState();
}

class _InventoryItemMappingPageState
    extends ConsumerState<InventoryItemMappingPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryItemMappingProvider);

    // Show error snackbar
    ref.listen(inventoryItemMappingProvider.select((s) => s.error), (_, err) {
      if (err != null && err.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        ref.read(inventoryItemMappingProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ITEM LINKING',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              (state.activeTab == MappingTab.pending
                      ? '${state.pendingCount} items need mapping'
                      : '${state.mappedCount} items mapped')
                  .toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          if (state.isRecalculating)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 20),
            onPressed: () {
              HapticFeedback.lightImpact();
              ref.read(inventoryItemMappingProvider.notifier).fetchItems();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter Tabs ──────────────────────────────────────────────
          _buildFilterTabs(state),

          // ── Search bar ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => ref
                  .read(inventoryItemMappingProvider.notifier)
                  .setSearchQuery(v),
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(LucideIcons.x, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(inventoryItemMappingProvider.notifier)
                              .setSearchQuery('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.surface,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppTheme.primary, width: 1.5)),
              ),
            ),
          ),

          // ── v1 DISABLED: Recalculation banner (uncomment to restore) ────────
          // if (state.isRecalculating && state.recalcMessage != null)
          //   Container(
          //     width: double.infinity,
          //     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          //     color: Colors.blue.shade50,
          //     child: Row(
          //       children: [
          //         SizedBox(
          //           width: 14,
          //           height: 14,
          //           child: CircularProgressIndicator(
          //             strokeWidth: 2,
          //             color: Colors.blue.shade700,
          //           ),
          //         ),
          //         const SizedBox(width: 8),
          //         Text(
          //           state.recalcMessage!,
          //           style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
          //         ),
          //       ],
          //     ),
          //   ),

          // ── Content ──────────────────────────────────────────────────
          Expanded(
            child: state.activeTab == MappingTab.pending
                ? _buildPendingList(state)
                : _buildMappedList(state),
          ),
        ],
      ),
      // ── v1 DISABLED: Recalculate FAB (uncomment to restore) ─────────────
      // floatingActionButton: FloatingActionButton.extended(
      //   onPressed: state.isRecalculating
      //       ? null
      //       : () {
      //           HapticFeedback.lightImpact();
      //           ref
      //               .read(inventoryItemMappingProvider.notifier)
      //               .triggerRecalculation();
      //         },
      //   icon: Icon(
      //     LucideIcons.refreshCw,
      //     size: 18,
      //     color: state.isRecalculating ? Colors.grey : Colors.white,
      //   ),
      //   label: Text(
      //     state.isRecalculating ? 'Recalculating...' : 'Recalculate Stock',
      //     style: TextStyle(
      //       color: state.isRecalculating ? Colors.grey : Colors.white,
      //     ),
      //   ),
      //   backgroundColor:
      //       state.isRecalculating ? Colors.grey.shade200 : AppTheme.primary,
      // ),
    );
  }

  // ── Filter Tabs ───────────────────────────────────────────────────────
  Widget _buildFilterTabs(InventoryItemMappingState state) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _FilterTab(
            label: 'Pending',
            icon: LucideIcons.clock,
            count: state.pendingCount,
            isActive: state.activeTab == MappingTab.pending,
            activeColor: const Color(0xFFF59E0B),
            onTap: () => ref
                .read(inventoryItemMappingProvider.notifier)
                .setTab(MappingTab.pending),
          ),
          const SizedBox(width: 10),
          _FilterTab(
            label: 'Mapped',
            icon: LucideIcons.checkCircle,
            count: state.mappedCount,
            isActive: state.activeTab == MappingTab.mapped,
            activeColor: Colors.green,
            onTap: () => ref
                .read(inventoryItemMappingProvider.notifier)
                .setTab(MappingTab.mapped),
          ),
        ],
      ),
    );
  }

  // ── Pending List ──────────────────────────────────────────────────────
  Widget _buildPendingList(InventoryItemMappingState state) {
    if (state.isLoading && state.allItems.isEmpty) {
      return _buildShimmerList();
    }
    if (state.error != null && state.allItems.isEmpty) {
      return _buildErrorState(state.error!);
    }
    final items = state.pendingItems;
    if (items.isEmpty) {
      return _buildEmptyState(
        icon: LucideIcons.checkCircle2,
        color: Colors.green,
        title: 'All items mapped!',
        subtitle: 'Great work — every item has been mapped to a customer name.',
      );
    }
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(inventoryItemMappingProvider.notifier).fetchItems(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return _PendingItemCard(
            item: item,
            index: index,
            onMap: () => _showMappingSheet(context, item),
          )
              .animate()
              .fade(duration: 250.ms, delay: (index * 40).ms)
              .slideY(begin: 0.08, duration: 250.ms, curve: Curves.easeOut);
        },
      ),
    );
  }

  // ── Mapped List ───────────────────────────────────────────────────────
  Widget _buildMappedList(InventoryItemMappingState state) {
    if (state.isLoading && state.allItems.isEmpty) {
      return _buildShimmerList();
    }
    final items = state.mappedItems;
    if (items.isEmpty) {
      return _buildEmptyState(
        icon: LucideIcons.gitMerge,
        color: AppTheme.primary,
        title: 'No mapped items yet',
        subtitle: 'Items you map will appear here for review.',
      );
    }
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(inventoryItemMappingProvider.notifier).fetchItems(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          return _MappedItemRow(
            item: item,
            onClear: () => _confirmClear(context, item),
          );
        },
      ),
    );
  }

  // ── Bottom Sheet for Mapping ──────────────────────────────────────────
  void _showMappingSheet(BuildContext context, StockLevel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MappingBottomSheet(item: item),
    );
  }

  // ── Clear mapping confirmation ────────────────────────────────────────
  void _confirmClear(BuildContext context, StockLevel item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Mapping?'),
        content: Text(
            'Remove customer item mapping for "${item.internalItemName}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(inventoryItemMappingProvider.notifier)
                  .clearMapping(item);
            },
            child: const Text('Clear', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  // ── Shimmer, Empty, Error ─────────────────────────────────────────────
  Widget _buildShimmerList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerPlaceholder(width: 200, height: 18),
            SizedBox(height: 6),
            ShimmerPlaceholder(width: 120, height: 13),
            SizedBox(height: 16),
            ShimmerPlaceholder(width: double.infinity, height: 44),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
      {required IconData icon,
      required Color color,
      required String title,
      required String subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 36, color: color),
            ),
            const SizedBox(height: 16),
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle),
              child: const Icon(LucideIcons.alertTriangle,
                  size: 36, color: AppTheme.error),
            ),
            const SizedBox(height: 16),
            const Text('Failed to load items',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Server error. Please try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () =>
                  ref.read(inventoryItemMappingProvider.notifier).fetchItems(),
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter Tab Widget
// ─────────────────────────────────────────────────────────────────────────────

class _FilterTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final int count;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _FilterTab({
    required this.label,
    required this.icon,
    required this.count,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: isActive
                ? activeColor.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: isActive ? activeColor : AppTheme.border, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 15,
                  color: isActive ? activeColor : AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isActive ? activeColor : AppTheme.textSecondary)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                    color: isActive ? activeColor : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10)),
                child: Text(count.toString(),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isActive ? Colors.white : Colors.grey.shade700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pending Item Card
// ─────────────────────────────────────────────────────────────────────────────

class _PendingItemCard extends ConsumerWidget {
  final StockLevel item;
  final int index;
  final VoidCallback onMap;

  const _PendingItemCard({
    required this.item,
    required this.index,
    required this.onMap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inventoryItemMappingProvider);
    final selectedName = state.selectedCustomerItems[item.id] ?? '';
    final hasSelection = selectedName.isNotEmpty;
    final onHand = (item.currentStock) + (item.manualAdjustment ?? 0);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: hasSelection ? Colors.blue.shade200 : AppTheme.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item name + part number
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.internalItemName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.partNumber,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // On Hand badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        onHand > 0 ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: onHand > 0
                            ? Colors.green.shade200
                            : Colors.red.shade200),
                  ),
                  child: Column(
                    children: [
                      Text('$onHand',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: onHand > 0
                                  ? Colors.green.shade700
                                  : Colors.red.shade700)),
                      Text('on hand',
                          style: TextStyle(
                              fontSize: 9,
                              color: onHand > 0
                                  ? Colors.green.shade500
                                  : Colors.red.shade500)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Priority badge
                if (item.priority != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(item.priority!,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Customer item selector (tap to open sheet) ─────────────
          GestureDetector(
            onTap: onMap,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: hasSelection ? Colors.blue.shade50 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: hasSelection
                        ? Colors.blue.shade200
                        : Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    hasSelection
                        ? LucideIcons.checkSquare
                        : LucideIcons.gitMerge,
                    size: 16,
                    color: hasSelection
                        ? Colors.blue.shade600
                        : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CUSTOMER ITEM',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade500,
                              letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasSelection
                              ? selectedName
                              : 'Tap to select or type a name...',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: hasSelection
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: hasSelection
                                ? AppTheme.textPrimary
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(LucideIcons.chevronDown,
                      size: 18, color: AppTheme.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Confirm button ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: hasSelection
                    ? () {
                        HapticFeedback.lightImpact();
                        ref
                            .read(inventoryItemMappingProvider.notifier)
                            .confirmMapping(item);
                      }
                    : null,
                icon: const Icon(LucideIcons.check, size: 16),
                label: const Text('Confirm Mapping'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade200,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mapped Item Row
// ─────────────────────────────────────────────────────────────────────────────

class _MappedItemRow extends StatelessWidget {
  final StockLevel item;
  final VoidCallback onClear;

  const _MappedItemRow({required this.item, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final onHand = (item.currentStock) + (item.manualAdjustment ?? 0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.checkCircle2,
              size: 18, color: Colors.green.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.internalItemName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  '→ ${item.customerItems}',
                  style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.partNumber}  •  On hand: $onHand',
                  style: const TextStyle(
                      fontSize: 10, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          // Priority badge
          if (item.priority != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6)),
              child: Text(item.priority!,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700)),
            ),
            const SizedBox(width: 6),
          ],
          // Clear button
          IconButton(
            icon: Icon(LucideIcons.x, size: 16, color: Colors.red.shade400),
            onPressed: onClear,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mapping Bottom Sheet (search customer items from verified_invoices)
// ─────────────────────────────────────────────────────────────────────────────

class _MappingBottomSheet extends ConsumerStatefulWidget {
  final StockLevel item;

  const _MappingBottomSheet({required this.item});

  @override
  ConsumerState<_MappingBottomSheet> createState() =>
      _MappingBottomSheetState();
}

class _MappingBottomSheetState extends ConsumerState<_MappingBottomSheet> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final existing = ref
        .read(inventoryItemMappingProvider)
        .selectedCustomerItems[widget.item.id];
    if (existing != null) _ctrl.text = existing;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    ref
        .read(inventoryItemMappingProvider.notifier)
        .searchCustomerItems(widget.item.id, query);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryItemMappingProvider);
    final results = state.searchResultsCache[widget.item.id] ?? [];
    final isSearching = state.searchLoading[widget.item.id] == true;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // Title row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Select Customer Item',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                      Text(
                        widget.item.internalItemName,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.item.partNumber,
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (_ctrl.text.isNotEmpty) {
                      ref
                          .read(inventoryItemMappingProvider.notifier)
                          .selectCustomerItem(widget.item.id, _ctrl.text);
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('Done',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: 'Search customer items or type a name...',
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                suffixIcon: _ctrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(LucideIcons.x, size: 16),
                        onPressed: () {
                          _ctrl.clear();
                          _onChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.surface,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.border)),
              ),
            ),
          ),

          // Helper label
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Icon(LucideIcons.info, size: 12, color: Colors.blue.shade400),
                const SizedBox(width: 4),
                Text(
                  _ctrl.text.isEmpty
                      ? 'Type to search your customer item names'
                      : '${results.length} matches found',
                  style: TextStyle(fontSize: 11, color: Colors.blue.shade500),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Results list
          Expanded(
            child: isSearching
                ? const Center(child: CircularProgressIndicator())
                : results.isEmpty && _ctrl.text.isNotEmpty
                    ? _buildNoResults()
                    : results.isEmpty
                        ? _buildTypeToSearch()
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            itemCount: results.length,
                            separatorBuilder: (_, __) =>
                                Divider(color: Colors.grey.shade100, height: 1),
                            itemBuilder: (context, index) {
                              final name = results[index];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 2),
                                leading: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(LucideIcons.package,
                                      size: 16, color: Colors.blue.shade600),
                                ),
                                title: Text(name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  _ctrl.text = name;
                                  ref
                                      .read(
                                          inventoryItemMappingProvider.notifier)
                                      .selectCustomerItem(widget.item.id, name);
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
          ),

          // Use typed text button
          if (_ctrl.text.isNotEmpty)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: OutlinedButton.icon(
                  onPressed: () {
                    ref
                        .read(inventoryItemMappingProvider.notifier)
                        .selectCustomerItem(widget.item.id, _ctrl.text);
                    Navigator.pop(context);
                  },
                  icon: const Icon(LucideIcons.pencil, size: 16),
                  label: Text('Use "${_ctrl.text}" as customer item'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.searchX, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'No matches found.\nType a custom name and tap "Use" below.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeToSearch() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.search, size: 40, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text(
              'Type to search customer item names\nfrom your invoices.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
