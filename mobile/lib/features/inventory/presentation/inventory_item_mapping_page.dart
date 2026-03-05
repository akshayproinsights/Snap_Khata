import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/inventory/domain/models/inventory_item_mapping_models.dart';
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
            const Text('Inventory Mapping',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(
              state.activeTab == MappingTab.pending
                  ? '${state.visibleItems.length} items need mapping'
                  : '${state.mappedItems.length} items mapped',
              style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
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
          // ── Filter Tabs ──────────────────────────────────────────────────
          _buildFilterTabs(state),

          // ── Search bar (pending tab only) ─────────────────────────────────
          if (state.activeTab == MappingTab.pending) ...[
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
                      borderSide: const BorderSide(
                          color: AppTheme.primary, width: 1.5)),
                ),
              ),
            ),
          ],

          // ── Progress bar (pending only) ───────────────────────────────────
          if (state.activeTab == MappingTab.pending && state.totalItems > 0)
            _buildProgressBar(state),

          // ── Content ──────────────────────────────────────────────────────
          Expanded(
            child: state.activeTab == MappingTab.pending
                ? _buildPendingList(state)
                : _buildMappedList(state),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(InventoryItemMappingState state) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _FilterTab(
            label: 'Pending',
            icon: LucideIcons.clock,
            count: state.visibleItems.length,
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
            count: state.mappedItems.length,
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

  Widget _buildProgressBar(InventoryItemMappingState state) {
    final done = state.doneCount;
    final total = state.totalItems;
    final pct = state.completionPercentage;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$done of $total mapped',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
              Text('$pct%',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0 ? done / total : 0,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildPendingList(InventoryItemMappingState state) {
    if (state.isLoading && state.items.isEmpty) {
      return _buildShimmerList();
    }
    final visible = state.visibleItems;
    if (visible.isEmpty) {
      return _buildEmptyState(
        icon: LucideIcons.checkCircle2,
        color: Colors.green,
        title: 'All items mapped!',
        subtitle: 'Great work — every item in your invoices has been mapped.',
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(inventoryItemMappingProvider.notifier).fetchItems(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = visible[index];
          return _PendingItemCard(
            item: item,
            index: index,
            onMap: () => _showMappingSheet(context, item),
            onSkip: () {
              HapticFeedback.selectionClick();
              ref
                  .read(inventoryItemMappingProvider.notifier)
                  .skipItem(item.customerItem);
            },
          );
        },
      ),
    );
  }

  Widget _buildMappedList(InventoryItemMappingState state) {
    if (state.isMappedLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.mappedItems.isEmpty) {
      return _buildEmptyState(
        icon: LucideIcons.gitMerge,
        color: AppTheme.primary,
        title: 'No mapped items yet',
        subtitle: 'Items you map will appear here for review.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      itemCount: state.mappedItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = state.mappedItems[index];
        return _MappedItemRow(item: item);
      },
    );
  }

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
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ShimmerPlaceholder(width: 80, height: 32),
                ShimmerPlaceholder(width: 100, height: 32),
              ],
            ),
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

  void _showMappingSheet(BuildContext context, CustomerItem item) {
    ref
        .read(inventoryItemMappingProvider.notifier)
        .fetchSuggestionsIfNeeded(item.customerItem);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MappingBottomSheet(item: item),
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
            color:
                isActive ? activeColor.withValues(alpha: 0.12) : Colors.transparent,
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
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                      color: isActive ? activeColor : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(count.toString(),
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color:
                              isActive ? Colors.white : Colors.grey.shade700)),
                ),
              ]
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
  final CustomerItem item;
  final int index;
  final VoidCallback onMap;
  final VoidCallback onSkip;

  const _PendingItemCard({
    required this.item,
    required this.index,
    required this.onMap,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inventoryItemMappingProvider);
    final customInput = state.customInputs[item.customerItem] ?? '';
    final hasMapping = customInput.isNotEmpty;
    final priority = state.priorities[item.customerItem] ?? 0;
    final hasVariations =
        item.variationCount != null && item.variationCount! > 1;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: hasMapping ? Colors.blue.shade200 : AppTheme.border),
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
          // ── Header Row: 4 columns ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Col 1: Item name
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.customerItem,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      if (hasVariations)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(10)),
                          child: Text(
                            '${item.variationCount} names',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ),

                // Col 2: Count
                _InfoChip(
                  value: '${item.occurrenceCount}×',
                  label: 'invoices',
                  color: Colors.grey,
                ),
                const SizedBox(width: 8),

                // Col 3: Status
                _InfoChip(
                  value: hasMapping ? 'Ready' : 'Pending',
                  label: '',
                  color: hasMapping ? Colors.green : Colors.orange,
                  filled: true,
                ),
              ],
            ),
          ),

          // ── Variations list (collapsible) ────────────────────────────
          if (hasVariations && item.variations != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ALL NAME VARIANTS (will be mapped together)',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                          letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 6),
                    ...item.variations!.map((v) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1.5),
                          child: Row(
                            children: [
                              Icon(LucideIcons.arrowRight,
                                  size: 10, color: Colors.blue.shade400),
                              const SizedBox(width: 5),
                              Expanded(
                                  child: Text(v.originalDescription,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary))),
                              Text('${v.occurrenceCount}×',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.blue.shade600,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // ── Col 4: Mapped name selector (tap to open sheet) ──────────
          GestureDetector(
            onTap: onMap,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: hasMapping ? Colors.blue.shade50 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: hasMapping
                        ? Colors.blue.shade200
                        : Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    hasMapping ? LucideIcons.checkSquare : LucideIcons.gitMerge,
                    size: 16,
                    color: hasMapping
                        ? Colors.blue.shade600
                        : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STANDARDIZED NAME',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade500,
                              letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasMapping
                              ? customInput
                              : 'Tap to select or type a name...',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: hasMapping
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: hasMapping
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

          // ── Action row: Priority + Skip + Confirm ─────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: Row(
              children: [
                // Priority dropdown
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.flag,
                          size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      DropdownButton<int>(
                        value: priority,
                        isDense: true,
                        underline: const SizedBox(),
                        icon: const Icon(LucideIcons.chevronDown, size: 12),
                        style: const TextStyle(fontSize: 13),
                        items: [0, 1, 2, 3, 4]
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text('P$e',
                                      style: const TextStyle(fontSize: 13)),
                                ))
                            .toList(),
                        onChanged: (v) => ref
                            .read(inventoryItemMappingProvider.notifier)
                            .setPriority(item.customerItem, v!),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade400,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text('Skip'),
                ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  onPressed: hasMapping
                      ? () {
                          HapticFeedback.lightImpact();
                          ref
                              .read(inventoryItemMappingProvider.notifier)
                              .markAsDone(item.customerItem);
                        }
                      : null,
                  icon: const Icon(LucideIcons.check, size: 16),
                  label: const Text('Confirm'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade200,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fade(duration: 250.ms, delay: (index * 40).ms)
        .slideY(begin: 0.08, duration: 250.ms, curve: Curves.easeOut);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info Chip
// ─────────────────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final String value;
  final String label;
  final MaterialColor color;
  final bool filled;

  const _InfoChip({
    required this.value,
    required this.label,
    required this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color.shade50 : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.shade200),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color.shade700)),
          if (label.isNotEmpty)
            Text(label, style: TextStyle(fontSize: 9, color: color.shade500)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mapped Item Row (Mapped tab)
// ─────────────────────────────────────────────────────────────────────────────

class _MappedItemRow extends StatelessWidget {
  final MappedItem item;

  const _MappedItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final isSkipped = item.status == 'Skipped';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isSkipped ? Colors.red.shade100 : Colors.green.shade100),
      ),
      child: Row(
        children: [
          Icon(
            isSkipped ? LucideIcons.xCircle : LucideIcons.checkCircle2,
            size: 18,
            color: isSkipped ? Colors.red.shade400 : Colors.green,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.customerItem,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                if (item.normalizedDescription != null && !isSkipped) ...[
                  const SizedBox(height: 2),
                  Text(
                    '→ ${item.normalizedDescription}',
                    style:
                        TextStyle(fontSize: 12, color: Colors.green.shade700),
                  ),
                ],
              ],
            ),
          ),
          // Priority badge
          if (item.priority > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6)),
              child: Text('P${item.priority}',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700)),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mapping Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _MappingBottomSheet extends ConsumerStatefulWidget {
  final CustomerItem item;

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
        .customInputs[widget.item.customerItem];
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
        .setCustomInput(widget.item.customerItem, query);
    ref
        .read(inventoryItemMappingProvider.notifier)
        .searchVendorItems(widget.item.customerItem, query);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryItemMappingProvider);
    final suggestions = state.suggestionsCache[widget.item.customerItem] ?? [];
    final searchResults = state.searchResultsCache[widget.item.customerItem];
    final isLoading =
        state.loadingSuggestions[widget.item.customerItem] == true;
    final displayList = _ctrl.text.isNotEmpty && searchResults != null
        ? searchResults
        : suggestions;

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
                      const Text('Select Standardized Name',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                      Text(
                        widget.item.customerItem,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ref
                        .read(inventoryItemMappingProvider.notifier)
                        .setCustomInput(widget.item.customerItem, _ctrl.text);
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
                hintText: 'Search inventory or type a name...',
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
                      ? 'Showing best matches from your stock'
                      : 'Showing results from inventory',
                  style: TextStyle(fontSize: 11, color: Colors.blue.shade500),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Results list
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : displayList.isEmpty
                    ? _buildNoResults()
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: displayList.length,
                        separatorBuilder: (_, __) =>
                            Divider(color: Colors.grey.shade100, height: 1),
                        itemBuilder: (context, index) {
                          final opt = displayList[index];
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
                            title: Text(opt.description,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: opt.partNumber.isNotEmpty
                                ? Text('Part# ${opt.partNumber}',
                                    style: const TextStyle(fontSize: 11))
                                : null,
                            trailing: opt.matchScore != null
                                ? _MatchBadge(score: opt.matchScore!)
                                : null,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _ctrl.text = opt.description;
                              ref
                                  .read(inventoryItemMappingProvider.notifier)
                                  .selectItem(widget.item.customerItem, opt);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
          ),

          // Use free text button
          if (_ctrl.text.isNotEmpty)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: OutlinedButton.icon(
                  onPressed: () {
                    ref
                        .read(inventoryItemMappingProvider.notifier)
                        .setCustomInput(widget.item.customerItem, _ctrl.text);
                    Navigator.pop(context);
                  },
                  icon: const Icon(LucideIcons.pencil, size: 16),
                  label: Text('Use "${_ctrl.text}" as custom name'),
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
            Text(
              _ctrl.text.isEmpty
                  ? 'No suggestions available.\nType a name above.'
                  : 'No matches found.\nType a custom name and tap "Use" below.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Match Score Badge
// ─────────────────────────────────────────────────────────────────────────────

class _MatchBadge extends StatelessWidget {
  final double score;

  const _MatchBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    final isHigh = score >= 80;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isHigh ? Colors.green.shade50 : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isHigh ? Colors.green.shade200 : Colors.amber.shade200),
      ),
      child: Text(
        '${score.round()}%',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isHigh ? Colors.green.shade700 : Colors.amber.shade800,
        ),
      ),
    );
  }
}
