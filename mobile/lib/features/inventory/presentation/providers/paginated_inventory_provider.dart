import 'package:flutter_riverpod/legacy.dart';
import 'package:mobile/models/pagination_state.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/inventory/domain/models/inventory_models.dart';

/// Configuration for inventory pagination
class InventoryPaginationConfig {
  final int pageSize;
  final String sortBy;
  final String sortDirection;
  final String? searchQuery;

  InventoryPaginationConfig({
    this.pageSize = 25,
    this.sortBy = 'invoice_date',
    this.sortDirection = 'desc',
    this.searchQuery,
  });

  InventoryPaginationConfig copyWith({
    int? pageSize,
    String? sortBy,
    String? sortDirection,
    String? searchQuery,
  }) {
    return InventoryPaginationConfig(
      pageSize: pageSize ?? this.pageSize,
      sortBy: sortBy ?? this.sortBy,
      sortDirection: sortDirection ?? this.sortDirection,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

/// Provider for paginated inventory items
class PaginatedInventoryNotifier
    extends StateNotifier<PaginationState<InventoryItem>> {
  final ApiClient apiClient;
  InventoryPaginationConfig config;

  PaginatedInventoryNotifier({
    required this.apiClient,
    InventoryPaginationConfig? initialConfig,
  })  : config = initialConfig ?? InventoryPaginationConfig(),
        super(const PaginationState.initial()) {
    loadFirstPage();
  }

  /// Load the first page of inventory items
  Future<void> loadFirstPage({InventoryPaginationConfig? newConfig}) async {
    if (newConfig != null) {
      config = newConfig;
    }

    state = const PaginationState.loadingFirstPage();

    try {
      final response = await apiClient.get(
        '/inventory/items',
        queryParameters: {
          'limit': config.pageSize.toString(),
          'sort_by': config.sortBy,
          'sort_direction': config.sortDirection,
          if (config.searchQuery != null) 'search': config.searchQuery,
        },
      );

      final items = (response.data['items'] as List<dynamic>)
          .map((item) => InventoryItem.fromJson(item as Map<String, dynamic>))
          .toList();

      final hasNext = response.data['has_next'] as bool? ?? false;
      final nextCursor = response.data['next_cursor'] as String?;

      if (items.isEmpty) {
        state = const PaginationState.empty();
      } else {
        state = PaginationState.loaded(
          items: items,
          hasNext: hasNext,
          nextCursor: nextCursor,
          isLoadingMore: false,
        );
      }
    } catch (e) {
      state = PaginationState.error(
        message: e.toString(),
        previousItems: [],
      );
    }
  }

  /// Load the next page of inventory items
  Future<void> loadNextPage() async {
    final nextCursor = state.maybeMap(
      loaded: (s) => s.nextCursor,
      orElse: () => null,
    );

    if (nextCursor == null) return;

    final currentItems = state.items;
    state = PaginationState.loadingNextPage(previousItems: currentItems);

    try {
      final response = await apiClient.get(
        '/inventory/items',
        queryParameters: {
          'limit': config.pageSize.toString(),
          'cursor': nextCursor,
          'sort_by': config.sortBy,
          'sort_direction': config.sortDirection,
          if (config.searchQuery != null) 'search': config.searchQuery,
        },
      );

      final newItems = (response.data['items'] as List<dynamic>)
          .map((item) => InventoryItem.fromJson(item as Map<String, dynamic>))
          .toList();

      final hasNext = response.data['has_next'] as bool? ?? false;
      final nextCursorNew = response.data['next_cursor'] as String?;

      final allItems = [...currentItems, ...newItems];

      state = PaginationState.loaded(
        items: allItems,
        hasNext: hasNext,
        nextCursor: nextCursorNew,
        isLoadingMore: false,
      );
    } catch (e) {
      state = PaginationState.error(
        message: e.toString(),
        previousItems: currentItems,
      );
    }
  }

  /// Refresh the first page
  Future<void> refresh({InventoryPaginationConfig? newConfig}) async {
    await loadFirstPage(newConfig: newConfig);
  }
}

/// Riverpod provider for paginated inventory
final paginatedInventoryProvider = StateNotifierProvider<
    PaginatedInventoryNotifier,
    PaginationState<InventoryItem>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PaginatedInventoryNotifier(apiClient: apiClient);
});
