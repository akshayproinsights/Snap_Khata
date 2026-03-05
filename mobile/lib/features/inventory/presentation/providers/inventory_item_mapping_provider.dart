import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/inventory/data/inventory_item_mapping_repository.dart';
import 'package:mobile/features/inventory/domain/models/inventory_item_mapping_models.dart';

final inventoryItemMappingRepositoryProvider =
    Provider((ref) => InventoryItemMappingRepository());

enum MappingTab { pending, mapped }

class InventoryItemMappingState {
  final List<CustomerItem> items; // pending unmapped items
  final List<MappedItem> mappedItems; // already-mapped items
  final bool isLoading;
  final bool isMappedLoading;
  final String? error;
  final String searchQuery;
  final MappingTab activeTab;

  // Suggestion / search caches
  final Map<String, List<VendorItem>> suggestionsCache;
  final Map<String, List<VendorItem>> searchResultsCache;
  final Map<String, bool> loadingSuggestions;

  // Local selection state (before confirming)
  final Map<String, VendorItem?> selectedMappings;
  final Map<String, String> customInputs;
  final Map<String, int> priorities;

  // Optimistic local status overrides after user taps Done/Skip
  final Map<String, String> pendingStatuses; // 'Done' | 'Skipped'

  InventoryItemMappingState({
    this.items = const [],
    this.mappedItems = const [],
    this.isLoading = false,
    this.isMappedLoading = false,
    this.error,
    this.searchQuery = '',
    this.activeTab = MappingTab.pending,
    this.suggestionsCache = const {},
    this.searchResultsCache = const {},
    this.loadingSuggestions = const {},
    this.selectedMappings = const {},
    this.customInputs = const {},
    this.priorities = const {},
    this.pendingStatuses = const {},
  });

  InventoryItemMappingState copyWith({
    List<CustomerItem>? items,
    List<MappedItem>? mappedItems,
    bool? isLoading,
    bool? isMappedLoading,
    String? error,
    String? searchQuery,
    MappingTab? activeTab,
    Map<String, List<VendorItem>>? suggestionsCache,
    Map<String, List<VendorItem>>? searchResultsCache,
    Map<String, bool>? loadingSuggestions,
    Map<String, VendorItem?>? selectedMappings,
    Map<String, String>? customInputs,
    Map<String, int>? priorities,
    Map<String, String>? pendingStatuses,
  }) {
    return InventoryItemMappingState(
      items: items ?? this.items,
      mappedItems: mappedItems ?? this.mappedItems,
      isLoading: isLoading ?? this.isLoading,
      isMappedLoading: isMappedLoading ?? this.isMappedLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      activeTab: activeTab ?? this.activeTab,
      suggestionsCache: suggestionsCache ?? this.suggestionsCache,
      searchResultsCache: searchResultsCache ?? this.searchResultsCache,
      loadingSuggestions: loadingSuggestions ?? this.loadingSuggestions,
      selectedMappings: selectedMappings ?? this.selectedMappings,
      customInputs: customInputs ?? this.customInputs,
      priorities: priorities ?? this.priorities,
      pendingStatuses: pendingStatuses ?? this.pendingStatuses,
    );
  }

  int get doneCount => pendingStatuses.values.where((s) => s == 'Done').length;
  int get skippedCount =>
      pendingStatuses.values.where((s) => s == 'Skipped').length;
  int get pendingCount => items.length - doneCount - skippedCount;
  int get totalItems => items.length;
  int get completionPercentage => totalItems > 0
      ? ((doneCount + skippedCount) / totalItems * 100).round()
      : 0;

  List<CustomerItem> get visibleItems =>
      items.where((i) => pendingStatuses[i.customerItem] == null).toList();
}

class InventoryItemMappingNotifier extends Notifier<InventoryItemMappingState> {
  late final InventoryItemMappingRepository _repository;

  @override
  InventoryItemMappingState build() {
    _repository = ref.watch(inventoryItemMappingRepositoryProvider);
    Future.microtask(() => fetchItems());
    return InventoryItemMappingState();
  }

  void setTab(MappingTab tab) {
    state = state.copyWith(activeTab: tab);
    if (tab == MappingTab.mapped && state.mappedItems.isEmpty) {
      _fetchMappedItems();
    }
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
      // Clear any pending statuses for items that no longer appear (already saved)
      final newStatuses = Map<String, String>.from(state.pendingStatuses)
        ..removeWhere((k, _) => !items.any((i) => i.customerItem == k));
      state = state.copyWith(
          items: items, isLoading: false, pendingStatuses: newStatuses);

      // Pre-fetch suggestions for first 10 items
      for (var item in items.take(10)) {
        if (!state.suggestionsCache.containsKey(item.customerItem)) {
          _fetchSuggestions(item.customerItem);
        }
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _fetchMappedItems() async {
    state = state.copyWith(isMappedLoading: true);
    try {
      final mapped = await _repository.getMappedCustomerItems();
      state = state.copyWith(mappedItems: mapped, isMappedLoading: false);
    } catch (e) {
      state = state.copyWith(isMappedLoading: false);
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

  void fetchSuggestionsIfNeeded(String customerItem) {
    if (!state.suggestionsCache.containsKey(customerItem)) {
      _fetchSuggestions(customerItem);
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
      final results = await _repository.searchVendorItems(query, 20);
      state = state.copyWith(
        searchResultsCache: {
          ...state.searchResultsCache,
          customerItem: results
        },
      );
    } catch (e) {
      // Ignore search errors silently
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
    final selectedVendorItem = state.selectedMappings[customerItem];

    if (customInput == null || customInput.trim().isEmpty) {
      state = state.copyWith(
          error: 'Please select or type a standardized item name');
      return;
    }

    // Optimistically mark as Done so item slides out of list
    state = state.copyWith(
      pendingStatuses: {...state.pendingStatuses, customerItem: 'Done'},
    );

    try {
      final item =
          state.items.firstWhere((i) => i.customerItem == customerItem);

      await _repository.confirmCustomerItemMapping(
        customerItem: customerItem,
        normalizedDescription: customInput.trim(),
        vendorItemId: selectedVendorItem?.id,
        vendorDescription: selectedVendorItem?.description,
        vendorPartNumber: selectedVendorItem?.partNumber,
        priority: state.priorities[customerItem] ?? 0,
        // Pass all variation names so they're all mapped together
        variations: item.allVariationDescriptions,
      );
    } catch (e) {
      // Revert optimistic update on failure
      final newStatuses = Map<String, String>.from(state.pendingStatuses);
      newStatuses.remove(customerItem);
      state = state.copyWith(
          pendingStatuses: newStatuses,
          error: 'Failed to save mapping. Please try again.');
    }
  }

  Future<void> skipItem(String customerItem) async {
    // Optimistically mark as Skipped
    state = state.copyWith(
      pendingStatuses: {...state.pendingStatuses, customerItem: 'Skipped'},
    );
    try {
      await _repository.skipCustomerItem(customerItem);
    } catch (e) {
      // Revert on failure
      final newStatuses = Map<String, String>.from(state.pendingStatuses);
      newStatuses.remove(customerItem);
      state = state.copyWith(
          pendingStatuses: newStatuses, error: 'Failed to skip item.');
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final inventoryItemMappingProvider =
    NotifierProvider<InventoryItemMappingNotifier, InventoryItemMappingState>(
        InventoryItemMappingNotifier.new);
