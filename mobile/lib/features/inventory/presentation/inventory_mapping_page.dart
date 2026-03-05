import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/inventory/domain/models/inventory_mapping_models.dart';
import 'package:mobile/features/inventory/presentation/providers/inventory_mapping_provider.dart';

class InventoryMappingPage extends ConsumerWidget {
  const InventoryMappingPage({super.key});

  void _showMappingSheet(
      BuildContext context, WidgetRef ref, GroupedItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MappingBottomSheet(item: item),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inventoryMappingProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Inventory Mapping',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton.icon(
            onPressed: () {
              ref.read(inventoryMappingProvider.notifier).fetchItems(
                    page: 1,
                    showCompleted: !state.showCompleted,
                  );
            },
            icon: Icon(
              state.showCompleted ? LucideIcons.checkCircle : LucideIcons.clock,
              size: 16,
              color: state.showCompleted ? AppTheme.success : AppTheme.primary,
            ),
            label: Text(
              state.showCompleted ? 'All' : 'Pending',
              style: TextStyle(
                color:
                    state.showCompleted ? AppTheme.success : AppTheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        ],
      ),
      body: state.isLoading && state.items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.items.isEmpty
              ? const Center(
                  child: Text('No items to map. All caught up!',
                      style: TextStyle(color: AppTheme.textSecondary)))
              : RefreshIndicator(
                  onRefresh: () => ref
                      .read(inventoryMappingProvider.notifier)
                      .fetchItems(page: 1),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.items.length + 1, // +1 for pagination
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      if (index == state.items.length) {
                        return _buildPagination(context, ref, state);
                      }

                      final item = state.items[index];
                      return _buildMappingCard(context, ref, state, item);
                    },
                  ),
                ),
    );
  }

  Widget _buildMappingCard(BuildContext context, WidgetRef ref,
      InventoryMappingState state, GroupedItem item) {
    final isConfirmed = item.status == 'Done';
    final selectedMapping = state.selectedMappings[item.customerItem];

    return Container(
      decoration: BoxDecoration(
        color: isConfirmed ? Colors.green.shade50 : AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isConfirmed ? Colors.green.shade200 : AppTheme.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.customerItem,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(LucideIcons.info,
                              size: 14, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text('${item.groupedCount} invoice(s) grouped',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 12)),
                        ],
                      )
                    ],
                  ),
                ),
                if (isConfirmed)
                  const Icon(LucideIcons.checkCircle2, color: AppTheme.success)
              ],
            ),

            const SizedBox(height: 16),

            // Mapping Selector
            InkWell(
              onTap: isConfirmed
                  ? null
                  : () => _showMappingSheet(context, ref, item),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(12),
                  color: isConfirmed ? Colors.transparent : Colors.grey.shade50,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mapped Vendor Item',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            selectedMapping?.description ??
                                'Select standardized item...',
                            style: TextStyle(
                              color: selectedMapping != null
                                  ? AppTheme.textPrimary
                                  : AppTheme.textSecondary,
                              fontWeight: selectedMapping != null
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isConfirmed)
                      const Icon(LucideIcons.chevronDown,
                          size: 20, color: AppTheme.textSecondary),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: (isConfirmed || selectedMapping == null)
                    ? null
                    : () {
                        ref
                            .read(inventoryMappingProvider.notifier)
                            .confirmMapping(item);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  disabledBackgroundColor: isConfirmed
                      ? Colors.green.shade100
                      : Colors.grey.shade200,
                  disabledForegroundColor: isConfirmed
                      ? Colors.green.shade800
                      : Colors.grey.shade500,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child:
                    Text(isConfirmed ? 'Matched & Confirmed' : 'Confirm Match'),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPagination(
      BuildContext context, WidgetRef ref, InventoryMappingState state) {
    if (state.total <= 20) return const SizedBox.shrink();

    final totalPages = (state.total / 20).ceil();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: state.page > 1
              ? () => ref
                  .read(inventoryMappingProvider.notifier)
                  .fetchItems(page: state.page - 1)
              : null,
          child: const Text('Previous'),
        ),
        Text('Page ${state.page} of $totalPages'),
        TextButton(
          onPressed: state.page < totalPages
              ? () => ref
                  .read(inventoryMappingProvider.notifier)
                  .fetchItems(page: state.page + 1)
              : null,
          child: const Text('Next'),
        ),
      ],
    );
  }
}

// Bottom Sheet for Searching & Selecting Mapping
class _MappingBottomSheet extends ConsumerStatefulWidget {
  final GroupedItem item;

  const _MappingBottomSheet({required this.item});

  @override
  ConsumerState<_MappingBottomSheet> createState() =>
      _MappingBottomSheetState();
}

class _MappingBottomSheetState extends ConsumerState<_MappingBottomSheet> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    ref
        .read(inventoryMappingProvider.notifier)
        .searchInventory(widget.item.customerItem, query);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryMappingProvider);
    final suggestions = state.suggestionsCache[widget.item.customerItem] ?? [];
    final searchResults = state.searchResultsCache[widget.item.customerItem];
    final isLoading =
        state.loadingSuggestions[widget.item.customerItem] == true;

    final displayList =
        _searchController.text.isNotEmpty && searchResults != null
            ? searchResults
            : suggestions;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
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
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Select Standard Item',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(LucideIcons.x),
                  onPressed: () => Navigator.pop(context),
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
                hintText: 'Search inventory...',
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
                    ? const Center(child: Text('No matches found'))
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
                                    fontWeight: FontWeight.w500)),
                            subtitle: Text('Part: ${option.partNumber}',
                                style: const TextStyle(fontSize: 12)),
                            onTap: () {
                              ref
                                  .read(inventoryMappingProvider.notifier)
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
