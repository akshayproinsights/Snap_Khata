import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/features/inventory/domain/models/inventory_models.dart';
import 'package:mobile/features/inventory/presentation/providers/paginated_inventory_provider.dart';
import 'package:mobile/features/inventory/presentation/widgets/invoice_item_card.dart';
import 'package:mobile/core/theme/context_extension.dart';
import 'package:shimmer/shimmer.dart';
import 'package:mobile/models/pagination_state.dart';

class ItemsPagePaginated extends ConsumerStatefulWidget {
  const ItemsPagePaginated({super.key});

  @override
  ConsumerState<ItemsPagePaginated> createState() =>
      _ItemsPagePaginatedState();
}

class _ItemsPagePaginatedState extends ConsumerState<ItemsPagePaginated> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      // Load next page when user is near the bottom
      ref.read(paginatedInventoryProvider.notifier).loadNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final paginationState = ref.watch(paginatedInventoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Inventory Items'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                // Trigger search with debounce
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) {
                    ref
                        .read(paginatedInventoryProvider.notifier)
                        .loadFirstPage(
                          newConfig: InventoryPaginationConfig(
                            searchQuery: value.isNotEmpty ? value : null,
                          ),
                        );
                  }
                });
              },
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(LucideIcons.search),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // Items list or skeleton
          Expanded(
            child: paginationState.when(
              initial: () => const _SkeletonLoader(),
              loadingFirstPage: () => const _SkeletonLoader(),
              loadingNextPage: (previousItems) => _buildItemsList(
                context,
                previousItems,
                true,
                isDark,
              ),
              loaded: (items, hasNext, nextCursor, isLoadingMore) =>
                  _buildItemsList(context, items, isLoadingMore, isDark),
              error: (message, previousItems) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.alertCircle,
                        size: 48, color: Colors.red.shade300),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading items',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        ref
                            .read(paginatedInventoryProvider.notifier)
                            .loadFirstPage();
                      },
                      icon: Icon(LucideIcons.refreshCw),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              empty: () => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.inbox,
                        size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No items found',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(
    BuildContext context,
    List<InventoryItem> items,
    bool isLoadingMore,
    bool isDark,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(paginatedInventoryProvider.notifier).refresh();
      },
      child: ListView.builder(
        controller: _scrollController,
        itemCount: items.length + (isLoadingMore ? 1 : 0),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          if (index == items.length) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(
                      isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
            );
          }

          final item = items[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InvoiceItemCard(
              item: item,
              onEdit: () {
                // TODO: Implement edit
              },
              onDelete: () {
                // TODO: Implement delete
              },
            ),
          );
        },
      ),
    );
  }
}

class _SkeletonLoader extends StatelessWidget {
  const _SkeletonLoader();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        itemCount: 6,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        },
      ),
    );
  }
}
