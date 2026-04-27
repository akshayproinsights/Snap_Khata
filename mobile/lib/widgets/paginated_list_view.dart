import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/pagination_state.dart';
import '../providers/pagination_provider.dart';
import 'pagination_widgets.dart';

/// Optimized paginated list view for all pages
/// This handles loading, errors, empty states, and infinite scroll
class PaginatedListView<T> extends ConsumerWidget {
  final StateNotifierProvider<dynamic, PaginationState<T>> provider;
  final Widget Function(BuildContext, T, int) itemBuilder;
  final VoidCallback? onRefresh;
  final String? emptyTitle;
  final String? emptySubtitle;
  final int loadMoreThreshold;
  final bool showLoadingIndicator;

  const PaginatedListView({
    super.key,
    required this.provider,
    required this.itemBuilder,
    this.onRefresh,
    this.emptyTitle = 'No Items Found',
    this.emptySubtitle = 'Try adjusting your filters',
    this.loadMoreThreshold = 5,
    this.showLoadingIndicator = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paginationState = ref.watch(provider);
    final notifier = ref.read(provider.notifier);

    return paginationState.when(
      initial: () => const Center(
        child: CircularProgressIndicator(),
      ),
      loadingFirstPage: () => _buildLoadingSkeleton(),
      loadingNextPage: (previousItems) {
        return _buildLoadedList(
          context,
          ref,
          previousItems,
          notifier,
          showLoadMore: true,
        );
      },
      loaded: (items, hasNext, nextCursor, isLoadingMore) {
        // Attach scroll listener for infinite scroll
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _attachScrollListener(ref, notifier, items.length, hasNext);
        });

        return _buildLoadedList(
          context,
          ref,
          items,
          notifier,
          showLoadMore: isLoadingMore,
        );
      },
      error: (message, previousItems) {
        return previousItems.isEmpty
            ? ErrorStateWidget(
          message: message,
          onRetry: () => notifier.loadFirstPage(),
        )
            : _buildLoadedListWithError(
          context,
          previousItems,
          message,
          onRetry: () => notifier.loadFirstPage(),
        );
      },
      empty: () => EmptyStateWidget(
        title: emptyTitle ?? 'No Items Found',
        subtitle: emptySubtitle ?? 'Try adjusting your filters',
        onRetry: () => notifier.loadFirstPage(),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    // This would be specialized skeleton for each page type
    // For now, generic loading
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading...'),
        ],
      ),
    );
  }

  Widget _buildLoadedList(
    BuildContext context,
    WidgetRef ref,
    List<T> items,
    dynamic notifier,
    {bool showLoadMore = false}
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        if (onRefresh != null) {
          onRefresh!();
        } else {
          await notifier.refresh();
        }
      },
      child: ListView.builder(
        itemCount: items.length + (showLoadMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == items.length) {
            return LoadMoreIndicator(isLoading: showLoadMore);
          }

          return itemBuilder(context, items[index], index);
        },
      ),
    );
  }

  Widget _buildLoadedListWithError(
    BuildContext context,
    List<T> items,
    String error, {
    required VoidCallback onRetry,
  }) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) => itemBuilder(context, items[index], index),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.red[50],
          child: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red[600]),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Error Loading More',
                      style: TextStyle(color: Colors.red[600], fontWeight: FontWeight.bold),
                    ),
                    Text(
                      error,
                      style: TextStyle(color: Colors.red[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _attachScrollListener(
    WidgetRef ref,
    dynamic notifier,
    int itemCount,
    bool hasNext,
  ) {
    // This would be attached to the scroll controller
    // Implementing infinite scroll pattern
    if (!hasNext || itemCount < loadMoreThreshold) return;

    // Logic to detect scroll near bottom and call loadNextPage
    // This is a simplified version - actual implementation needs ScrollController
  }
}

/// Pre-configured paginated list for inventory items
class PaginatedInventoryList extends ConsumerWidget {
  final Widget Function(BuildContext, dynamic, int) itemBuilder;
  final VoidCallback? onRefresh;
  final PaginationConfig? config;

  const PaginatedInventoryList({
    super.key,
    required this.itemBuilder,
    this.onRefresh,
    this.config,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finalConfig = config ?? PaginationConfig.defaults();

    return PaginatedListView(
      provider: PaginatedListProviderFactory.inventoryItemsProvider(finalConfig),
      itemBuilder: itemBuilder,
      onRefresh: onRefresh,
      emptyTitle: 'No Inventory Items',
      emptySubtitle: 'Upload your first invoice to get started',
    );
  }
}

/// Pre-configured paginated list for khata parties
class PaginatedKhataList extends ConsumerWidget {
  final Widget Function(BuildContext, dynamic, int) itemBuilder;
  final VoidCallback? onRefresh;
  final PaginationConfig? config;

  const PaginatedKhataList({
    super.key,
    required this.itemBuilder,
    this.onRefresh,
    this.config,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finalConfig = config ?? PaginationConfig.defaults();

    return PaginatedListView(
      provider: PaginatedListProviderFactory.khataPartiesProvider(finalConfig),
      itemBuilder: itemBuilder,
      onRefresh: onRefresh,
      emptyTitle: 'No Parties Yet',
      emptySubtitle: 'Create a party by uploading an invoice',
    );
  }
}

/// Pre-configured paginated list for upload tasks
class PaginatedUploadList extends ConsumerWidget {
  final Widget Function(BuildContext, dynamic, int) itemBuilder;
  final VoidCallback? onRefresh;
  final PaginationConfig? config;

  const PaginatedUploadList({
    super.key,
    required this.itemBuilder,
    this.onRefresh,
    this.config,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finalConfig = config ?? PaginationConfig.defaults();

    return PaginatedListView(
      provider: PaginatedListProviderFactory.uploadTasksProvider(finalConfig),
      itemBuilder: itemBuilder,
      onRefresh: onRefresh,
      emptyTitle: 'No Uploads Yet',
      emptySubtitle: 'Start by uploading your invoices',
    );
  }
}

/// Pre-configured paginated list for party transactions
class PaginatedTransactionList extends ConsumerWidget {
  final int ledgerId;
  final Widget Function(BuildContext, dynamic, int) itemBuilder;
  final VoidCallback? onRefresh;
  final PaginationConfig? config;

  const PaginatedTransactionList({
    super.key,
    required this.ledgerId,
    required this.itemBuilder,
    this.onRefresh,
    this.config,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finalConfig = config ?? PaginationConfig.defaults();

    return PaginatedListView(
      provider: PaginatedListProviderFactory.partyTransactionsProvider(
        (ledgerId: ledgerId, config: finalConfig),
      ),
      itemBuilder: itemBuilder,
      onRefresh: onRefresh,
      emptyTitle: 'No Transactions',
      emptySubtitle: 'No transaction history for this party',
    );
  }
}
