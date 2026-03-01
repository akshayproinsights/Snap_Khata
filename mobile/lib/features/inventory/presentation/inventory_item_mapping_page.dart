import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/inventory/domain/models/inventory_item_mapping_models.dart';
import 'package:mobile/features/inventory/presentation/providers/inventory_item_mapping_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile/shared/widgets/shimmer_placeholders.dart';

class InventoryItemMappingPage extends ConsumerWidget {
  const InventoryItemMappingPage({super.key});

  void _showItemSelectionSheet(
      BuildContext context, WidgetRef ref, CustomerItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _VendorItemSelectionSheet(item: item),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inventoryItemMappingProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Map Items',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: CustomScrollView(
        slivers: [
          // Header & Stats
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Search Bar
                  TextField(
                    onChanged: (v) => ref
                        .read(inventoryItemMappingProvider.notifier)
                        .setSearchQuery(v),
                    decoration: InputDecoration(
                      hintText: 'Search stock items...',
                      prefixIcon: const Icon(LucideIcons.search, size: 20),
                      filled: true,
                      fillColor: AppTheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Progress Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEFF6FF), Color(0xFFEEF2FF)],
                      ),
                      border: Border.all(color: Colors.blue.shade100),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Mapping Progress',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                            Text('${state.completionPercentage}% Complete',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: state.totalItems > 0
                              ? state.completionPercentage / 100
                              : 0,
                          backgroundColor: Colors.blue.shade100,
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(Colors.green),
                          borderRadius: BorderRadius.circular(4),
                          minHeight: 8,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatBadge(
                                state.pendingCount, 'Pending', Colors.orange),
                            _buildStatBadge(
                                state.doneCount, 'Done', Colors.green),
                            if (state.skippedCount > 0)
                              _buildStatBadge(
                                  state.skippedCount, 'Skipped', Colors.red),
                          ],
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Loading state
          if (state.isLoading && state.items.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppTheme.border.withOpacity(0.5)),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerPlaceholder(width: 180, height: 20),
                            SizedBox(height: 8),
                            ShimmerPlaceholder(width: 100, height: 14),
                            SizedBox(height: 24),
                            ShimmerPlaceholder(
                                width: double.infinity, height: 48),
                            SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ShimmerPlaceholder(width: 80, height: 24),
                                Row(
                                  children: [
                                    ShimmerPlaceholder(width: 60, height: 36),
                                    SizedBox(width: 8),
                                    ShimmerPlaceholder(width: 80, height: 36),
                                  ],
                                )
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: 4, // Show 4 skeletons
                ),
              ),
            )
          else if (state.items.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text('No items to map. All caught up!',
                    style: TextStyle(color: AppTheme.textSecondary)),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = state.items[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildItemCard(context, ref, state, item, index),
                    );
                  },
                  childCount: state.items.length,
                ),
              ),
            ),

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: state.doneCount > 0
          ? FloatingActionButton.extended(
              onPressed: () => _handleSync(context, ref),
              icon: const Icon(LucideIcons.refreshCw, color: Colors.white),
              label: Text('Sync ${state.doneCount} Items',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: Colors.green,
            )
          : null,
    );
  }

  Widget _buildStatBadge(int count, String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.shade200),
      ),
      child: Text('$count $label',
          style: TextStyle(
              color: color.shade800,
              fontSize: 12,
              fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildItemCard(BuildContext context, WidgetRef ref,
      InventoryItemMappingState state, CustomerItem item, int index) {
    final status = state.statuses[item.customerItem] ?? 'Pending';
    final isDone = status == 'Done';
    final isSkipped = status == 'Skipped';

    final customInput = state.customInputs[item.customerItem] ?? '';
    final priority = state.priorities[item.customerItem] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: isDone
            ? Colors.green.shade50
            : isSkipped
                ? Colors.red.shade50
                : AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDone
                ? Colors.green.shade200
                : isSkipped
                    ? Colors.red.shade200
                    : AppTheme.border),
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
            // Customer Item Title
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.customerItem,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      if (item.variationCount != null &&
                          item.variationCount! > 1)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12)),
                          child: Text('${item.variationCount} variations',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.blue.shade700)),
                        ),
                      const SizedBox(height: 4),
                      Text('${item.occurrenceCount} in stock',
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                if (isDone)
                  const Icon(LucideIcons.checkCircle2, color: Colors.green)
                else if (isSkipped)
                  const Icon(LucideIcons.xCircle, color: Colors.red)
              ],
            ),

            if (item.variations != null && item.variations!.length > 1) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border(
                      left: BorderSide(color: Colors.grey.shade300, width: 2)),
                ),
                child: Column(
                  children: item.variations!
                      .map((v) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Expanded(
                                    child: Text(v.originalDescription,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondary))),
                                Text('${v.occurrenceCount} inv',
                                    style: const TextStyle(
                                        color: AppTheme.textSecondary)),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              )
            ],

            const SizedBox(height: 16),

            // Select Standardized Item
            InkWell(
              onTap: (isDone || isSkipped)
                  ? null
                  : () => _showItemSelectionSheet(context, ref, item),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(12),
                  color: (isDone || isSkipped)
                      ? Colors.transparent
                      : Colors.grey.shade50,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mapped Customer Item Name',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            customInput.isNotEmpty
                                ? customInput
                                : 'Tap to select or type...',
                            style: TextStyle(
                              color: customInput.isNotEmpty
                                  ? AppTheme.textPrimary
                                  : AppTheme.textSecondary,
                              fontWeight: customInput.isNotEmpty
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isDone && !isSkipped)
                      const Icon(LucideIcons.chevronDown,
                          size: 20, color: AppTheme.textSecondary),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Priority & Actions
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      const Text('Priority:',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: priority,
                        underline: const SizedBox(),
                        icon: const Icon(LucideIcons.chevronDown, size: 14),
                        disabledHint: Text(priority.toString()),
                        onChanged: (isDone || isSkipped)
                            ? null
                            : (v) => ref
                                .read(inventoryItemMappingProvider.notifier)
                                .setPriority(item.customerItem, v!),
                        items: [0, 1, 2, 3, 4]
                            .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(e.toString(),
                                    style: const TextStyle(fontSize: 14))))
                            .toList(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!isDone && !isSkipped)
                        TextButton(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            ref
                                .read(inventoryItemMappingProvider.notifier)
                                .skipItem(item.customerItem);
                          },
                          child: const Text('Skip',
                              style: TextStyle(color: AppTheme.error)),
                        ),
                      if (!isDone && !isSkipped)
                        ElevatedButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            ref
                                .read(inventoryItemMappingProvider.notifier)
                                .markAsDone(item.customerItem);
                          },
                          icon: const Icon(LucideIcons.check, size: 16),
                          label: const Text('Done'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            minimumSize: const Size(0, 36),
                          ),
                        ),
                      if (isDone || isSkipped)
                        TextButton.icon(
                          onPressed: null,
                          icon: Icon(
                              isDone
                                  ? LucideIcons.checkCircle
                                  : LucideIcons.xCircle,
                              size: 16),
                          label: Text(isDone ? 'Matched' : 'Skipped'),
                          style: TextButton.styleFrom(
                              disabledForegroundColor:
                                  isDone ? Colors.green : Colors.red),
                        )
                    ],
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    )
        .animate()
        .fade(duration: 300.ms, delay: (index * 50).ms)
        .slideY(begin: 0.1, duration: 300.ms, curve: Curves.easeOut);
  }

  Future<void> _handleSync(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Sync & Finish'),
              content: const Text(
                  'Are you sure you want to apply all completed mappings?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white),
                  child: const Text('Sync'),
                ),
              ],
            ));

    if (confirm == true) {
      HapticFeedback.heavyImpact();
      ref.read(inventoryItemMappingProvider.notifier).syncAndFinish();
    }
  }
}

// Bottom Sheet
class _VendorItemSelectionSheet extends ConsumerStatefulWidget {
  final CustomerItem item;

  const _VendorItemSelectionSheet({required this.item});

  @override
  ConsumerState<_VendorItemSelectionSheet> createState() =>
      _VendorItemSelectionSheetState();
}

class _VendorItemSelectionSheetState
    extends ConsumerState<_VendorItemSelectionSheet> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-fill with existing custom input if any
    final customInput = ref
        .read(inventoryItemMappingProvider)
        .customInputs[widget.item.customerItem];
    if (customInput != null) {
      _searchController.text = customInput;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
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

    final displayList =
        _searchController.text.isNotEmpty && searchResults != null
            ? searchResults
            : suggestions;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Select Customer Item Name',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () {
                    ref
                        .read(inventoryItemMappingProvider.notifier)
                        .setCustomInput(
                            widget.item.customerItem, _searchController.text);
                    Navigator.pop(context);
                  },
                  child: const Text('Done',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search or enter custom name...',
                prefixIcon: const Icon(LucideIcons.search, size: 20),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : displayList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('No matches found.',
                                style:
                                    TextStyle(color: AppTheme.textSecondary)),
                            const SizedBox(height: 8),
                            if (_searchController.text.isNotEmpty)
                              ElevatedButton(
                                onPressed: () {
                                  ref
                                      .read(
                                          inventoryItemMappingProvider.notifier)
                                      .setCustomInput(widget.item.customerItem,
                                          _searchController.text);
                                  Navigator.pop(context);
                                },
                                child: Text('Use "${_searchController.text}"'),
                              )
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: displayList.length,
                        separatorBuilder: (_, __) =>
                            Divider(color: Colors.grey.shade200, height: 1),
                        itemBuilder: (context, index) {
                          final option = displayList[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(option.description,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500, fontSize: 14)),
                            subtitle: option.partNumber.isNotEmpty
                                ? Text('Part: ${option.partNumber}',
                                    style: const TextStyle(fontSize: 12))
                                : null,
                            trailing: option.matchScore != null
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: option.matchScore! >= 80
                                          ? Colors.green.shade50
                                          : Colors.yellow.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${option.matchScore!.round()}% match',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: option.matchScore! >= 80
                                              ? Colors.green.shade800
                                              : Colors.yellow.shade800),
                                    ),
                                  )
                                : null,
                            onTap: () {
                              ref
                                  .read(inventoryItemMappingProvider.notifier)
                                  .selectItem(widget.item.customerItem, option);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
