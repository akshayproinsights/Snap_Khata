import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/inventory/data/inventory_mapping_repository.dart';
import 'package:mobile/features/inventory/domain/models/inventory_mapping_models.dart';

final inventoryMappingRepositoryProvider =
    Provider((ref) => InventoryMappingRepository());

class InventoryMappingState {
  final List<GroupedItem> items;
  final int total;
  final int page;
  final bool isLoading;
  final String? error;
  final bool showCompleted;

  // Cache for suggestions and search results
  final Map<String, List<InventorySuggestionItem>> suggestionsCache;
  final Map<String, List<InventorySuggestionItem>> searchResultsCache;
  final Map<String, bool> loadingSuggestions;

  // Current selections
  final Map<String, InventorySuggestionItem?> selectedMappings;

  InventoryMappingState({
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.isLoading = false,
    this.error,
    this.showCompleted = false,
    this.suggestionsCache = const {},
    this.searchResultsCache = const {},
    this.loadingSuggestions = const {},
    this.selectedMappings = const {},
  });

  InventoryMappingState copyWith({
    List<GroupedItem>? items,
    int? total,
    int? page,
    bool? isLoading,
    String? error,
    bool? showCompleted,
    Map<String, List<InventorySuggestionItem>>? suggestionsCache,
    Map<String, List<InventorySuggestionItem>>? searchResultsCache,
    Map<String, bool>? loadingSuggestions,
    Map<String, InventorySuggestionItem?>? selectedMappings,
  }) {
    return InventoryMappingState(
      items: items ?? this.items,
      total: total ?? this.total,
      page: page ?? this.page,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      showCompleted: showCompleted ?? this.showCompleted,
      suggestionsCache: suggestionsCache ?? this.suggestionsCache,
      searchResultsCache: searchResultsCache ?? this.searchResultsCache,
      loadingSuggestions: loadingSuggestions ?? this.loadingSuggestions,
      selectedMappings: selectedMappings ?? this.selectedMappings,
    );
  }
}

class InventoryMappingNotifier extends StateNotifier<InventoryMappingState> {
  final InventoryMappingRepository _repository;

  InventoryMappingNotifier(this._repository) : super(InventoryMappingState()) {
    fetchItems(page: 1);
  }

  Future<void> fetchItems({required int page, bool? showCompleted}) async {
    final statusFilter =
        (showCompleted ?? state.showCompleted) ? null : 'Pending';

    state = state.copyWith(
        isLoading: true,
        error: null,
        page: page,
        showCompleted: showCompleted ?? state.showCompleted);

    try {
      final result =
          await _repository.getGroupedItems(page, 20, status: statusFilter);
      final items = result['items'] as List<GroupedItem>;

      // Auto-populate mapped selections
      final newSelected =
          Map<String, InventorySuggestionItem?>.from(state.selectedMappings);
      for (final item in items) {
        if (item.mappedInventoryItemId != null &&
            item.mappedDescription != null) {
          newSelected[item.customerItem] = InventorySuggestionItem(
            id: item.mappedInventoryItemId!,
            description: item.mappedDescription!,
            partNumber: 'N/A', // Assuming we don't have it here
          );
        }
      }

      state = state.copyWith(
        items: items,
        total: result['total'],
        isLoading: false,
        selectedMappings: newSelected,
      );

      // Load suggestions for items without cache
      for (final item in items) {
        if (!state.suggestionsCache.containsKey(item.customerItem)) {
          _fetchSuggestions(item.customerItem);
        }
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _fetchSuggestions(String customerItem) async {
    state = state.copyWith(
        loadingSuggestions: {...state.loadingSuggestions, customerItem: true});

    try {
      final suggestions =
          await _repository.getInventorySuggestions(customerItem);
      state = state.copyWith(suggestionsCache: {
        ...state.suggestionsCache,
        customerItem: suggestions
      }, loadingSuggestions: {
        ...state.loadingSuggestions,
        customerItem: false
      });
    } catch (e) {
      state = state.copyWith(loadingSuggestions: {
        ...state.loadingSuggestions,
        customerItem: false
      });
    }
  }

  Future<void> searchInventory(String customerItem, String query) async {
    if (query.isEmpty) {
      final newSearchCache = Map<String, List<InventorySuggestionItem>>.from(
          state.searchResultsCache);
      newSearchCache.remove(customerItem);
      state = state.copyWith(searchResultsCache: newSearchCache);
      return;
    }

    try {
      final results = await _repository.searchInventory(query, 10);
      state = state.copyWith(
        searchResultsCache: {
          ...state.searchResultsCache,
          customerItem: results
        },
      );
    } catch (e) {
      // Ignore search errors
    }
  }

  void selectItem(String customerItem, InventorySuggestionItem? item) {
    state = state.copyWith(
      selectedMappings: {...state.selectedMappings, customerItem: item},
    );
  }

  Future<void> confirmMapping(GroupedItem item) async {
    final selected = state.selectedMappings[item.customerItem];
    if (selected == null) return;

    try {
      await _repository.confirmMapping(
        customerItem: item.customerItem,
        groupedInvoiceIds: item.groupedInvoiceIds,
        mappedInventoryItemId: selected.id,
        mappedInventoryDescription: selected.description,
      );
      // Refresh list
      fetchItems(page: state.page);
    } catch (e) {
      state = state.copyWith(error: 'Failed to confirm mapping: $e');
    }
  }

  Future<void> updateStatus(GroupedItem item, String status) async {
    if (item.id == null) return;
    try {
      await _repository.updateMappingStatus(item.id!, status);
      fetchItems(page: state.page);
    } catch (e) {
      state = state.copyWith(error: 'Failed to update status: $e');
    }
  }
}

final inventoryMappingProvider =
    StateNotifierProvider<InventoryMappingNotifier, InventoryMappingState>(
        (ref) {
  return InventoryMappingNotifier(
      ref.watch(inventoryMappingRepositoryProvider));
});
