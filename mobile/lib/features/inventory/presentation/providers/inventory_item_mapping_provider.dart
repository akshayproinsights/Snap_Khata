import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/inventory/data/inventory_item_mapping_repository.dart';
import 'package:mobile/features/inventory/domain/models/inventory_item_mapping_models.dart';

final inventoryItemMappingRepositoryProvider =
    Provider((ref) => InventoryItemMappingRepository());

class InventoryItemMappingState {
  final List<CustomerItem> items;
  final bool isLoading;
  final String? error;
  final String searchQuery;

  // Caches
  final Map<String, List<VendorItem>> suggestionsCache;
  final Map<String, List<VendorItem>> searchResultsCache;
  final Map<String, bool> loadingSuggestions;

  // Local state before sync
  final Map<String, VendorItem?> selectedMappings;
  final Map<String, String> customInputs;
  final Map<String, int> priorities;
  final Map<String, String> statuses; // 'Pending', 'Done', 'Skipped'

  InventoryItemMappingState({
    this.items = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.suggestionsCache = const {},
    this.searchResultsCache = const {},
    this.loadingSuggestions = const {},
    this.selectedMappings = const {},
    this.customInputs = const {},
    this.priorities = const {},
    this.statuses = const {},
  });

  InventoryItemMappingState copyWith({
    List<CustomerItem>? items,
    bool? isLoading,
    String? error,
    String? searchQuery,
    Map<String, List<VendorItem>>? suggestionsCache,
    Map<String, List<VendorItem>>? searchResultsCache,
    Map<String, bool>? loadingSuggestions,
    Map<String, VendorItem?>? selectedMappings,
    Map<String, String>? customInputs,
    Map<String, int>? priorities,
    Map<String, String>? statuses,
  }) {
    return InventoryItemMappingState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      suggestionsCache: suggestionsCache ?? this.suggestionsCache,
      searchResultsCache: searchResultsCache ?? this.searchResultsCache,
      loadingSuggestions: loadingSuggestions ?? this.loadingSuggestions,
      selectedMappings: selectedMappings ?? this.selectedMappings,
      customInputs: customInputs ?? this.customInputs,
      priorities: priorities ?? this.priorities,
      statuses: statuses ?? this.statuses,
    );
  }

  int get doneCount => statuses.values.where((s) => s == 'Done').length;
  int get skippedCount => statuses.values.where((s) => s == 'Skipped').length;
  int get pendingCount => items.length;
  int get totalItems => items.length + doneCount + skippedCount;
  int get completionPercentage => totalItems > 0
      ? ((doneCount + skippedCount) / totalItems * 100).round()
      : 0;
}

class InventoryItemMappingNotifier
    extends StateNotifier<InventoryItemMappingState> {
  final InventoryItemMappingRepository _repository;

  InventoryItemMappingNotifier(this._repository)
      : super(InventoryItemMappingState()) {
    fetchItems();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    fetchItems();
  }

  Future<void> fetchItems() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final items =
          await _repository.getUnmappedCustomerItems(state.searchQuery);
      state = state.copyWith(items: items, isLoading: false);

      for (var item in items) {
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
      loadingSuggestions: {...state.loadingSuggestions, customerItem: true},
    );
    try {
      final suggestions =
          await _repository.getCustomerItemSuggestions(customerItem);
      state = state.copyWith(
        suggestionsCache: {
          ...state.suggestionsCache,
          customerItem: suggestions
        },
        loadingSuggestions: {...state.loadingSuggestions, customerItem: false},
      );
    } catch (e) {
      state = state.copyWith(
        loadingSuggestions: {...state.loadingSuggestions, customerItem: false},
      );
    }
  }

  Future<void> searchVendorItems(String customerItem, String query) async {
    if (query.isEmpty) {
      final newCache =
          Map<String, List<VendorItem>>.from(state.searchResultsCache);
      newCache.remove(customerItem);
      state = state.copyWith(searchResultsCache: newCache);
      return;
    }
    try {
      final results = await _repository.searchCustomerItemNames(query);
      state = state.copyWith(
        searchResultsCache: {
          ...state.searchResultsCache,
          customerItem: results
        },
      );
    } catch (e) {
      // Ignore
    }
  }

  void selectItem(String customerItem, VendorItem? item) {
    state = state.copyWith(
      selectedMappings: {...state.selectedMappings, customerItem: item},
      customInputs: {
        ...state.customInputs,
        customerItem: item?.description ?? ''
      },
    );
  }

  void setCustomInput(String customerItem, String value) {
    if (value != state.selectedMappings[customerItem]?.description) {
      final newMappings = Map<String, VendorItem?>.from(state.selectedMappings);
      newMappings.remove(customerItem);
      state = state.copyWith(
        customInputs: {...state.customInputs, customerItem: value},
        selectedMappings: newMappings,
      );
    } else {
      state = state.copyWith(
        customInputs: {...state.customInputs, customerItem: value},
      );
    }
  }

  void setPriority(String customerItem, int priority) {
    state = state.copyWith(
      priorities: {...state.priorities, customerItem: priority},
    );
  }

  Future<void> markAsDone(String customerItem) async {
    final customInput = state.customInputs[customerItem];

    if (customInput == null || customInput.trim().isEmpty) {
      state =
          state.copyWith(error: 'Please select or enter a customer item name');
      return;
    }

    try {
      final item =
          state.items.firstWhere((i) => i.customerItem == customerItem);
      await _repository.confirmStockItemMapping(
        partNumber: item.partNumber ?? '',
        internalItemName: item.customerItem,
        customerItemName: customInput,
        stockLevelId: item.stockLevelId,
      );
      state =
          state.copyWith(statuses: {...state.statuses, customerItem: 'Done'});
    } catch (e) {
      state = state.copyWith(error: 'Failed to confirm mapping: \$e');
    }
  }

  Future<void> skipItem(String customerItem) async {
    try {
      await _repository.skipCustomerItem(customerItem);
      state = state
          .copyWith(statuses: {...state.statuses, customerItem: 'Skipped'});
    } catch (e) {
      state = state.copyWith(error: 'Failed to skip item: \$e');
    }
  }

  Future<void> syncAndFinish() async {
    try {
      await _repository.syncCustomerItemMappings();
      state = state.copyWith(statuses: {});
      fetchItems();
    } catch (e) {
      state = state.copyWith(error: 'Failed to sync: \$e');
    }
  }
}

final inventoryItemMappingProvider = StateNotifierProvider<
    InventoryItemMappingNotifier, InventoryItemMappingState>((ref) {
  return InventoryItemMappingNotifier(
      ref.watch(inventoryItemMappingRepositoryProvider));
});
