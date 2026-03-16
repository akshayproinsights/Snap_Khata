import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/inventory/data/current_stock_repository.dart';
import 'package:mobile/features/inventory/domain/models/current_stock_models.dart';

final _stockRepoProvider = Provider((ref) => CurrentStockRepository());

enum MappingTab { pending, mapped }

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────
class InventoryItemMappingState {
  final List<StockLevel> allItems; // all stock_levels items
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final MappingTab activeTab;

  // Customer-item search results (from verified_invoices)
  final Map<int, List<String>> searchResultsCache; // stockLevelId → matches
  final Map<int, bool> searchLoading;

  // Selected customer-item name per stock level id (before confirming)
  final Map<int, String> selectedCustomerItems;

  // Recalculation state
  final bool isRecalculating;
  final String? recalcTaskId;
  final String? recalcMessage;

  InventoryItemMappingState({
    this.allItems = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.activeTab = MappingTab.pending,
    this.searchResultsCache = const {},
    this.searchLoading = const {},
    this.selectedCustomerItems = const {},
    this.isRecalculating = false,
    this.recalcTaskId,
    this.recalcMessage,
  });

  InventoryItemMappingState copyWith({
    List<StockLevel>? allItems,
    bool? isLoading,
    String? error,
    String? searchQuery,
    MappingTab? activeTab,
    Map<int, List<String>>? searchResultsCache,
    Map<int, bool>? searchLoading,
    Map<int, String>? selectedCustomerItems,
    bool? isRecalculating,
    String? recalcTaskId,
    String? recalcMessage,
  }) {
    return InventoryItemMappingState(
      allItems: allItems ?? this.allItems,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      activeTab: activeTab ?? this.activeTab,
      searchResultsCache: searchResultsCache ?? this.searchResultsCache,
      searchLoading: searchLoading ?? this.searchLoading,
      selectedCustomerItems:
          selectedCustomerItems ?? this.selectedCustomerItems,
      isRecalculating: isRecalculating ?? this.isRecalculating,
      recalcTaskId: recalcTaskId ?? this.recalcTaskId,
      recalcMessage: recalcMessage ?? this.recalcMessage,
    );
  }

  /// Items where customer_items is null or empty → need mapping
  List<StockLevel> get pendingItems {
    var list = allItems
        .where(
            (i) => i.customerItems == null || i.customerItems!.trim().isEmpty)
        .toList();
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list
          .where((i) =>
              i.internalItemName.toLowerCase().contains(q) ||
              i.partNumber.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  /// Items where customer_items is filled → already mapped
  List<StockLevel> get mappedItems {
    var list = allItems
        .where((i) =>
            i.customerItems != null && i.customerItems!.trim().isNotEmpty)
        .toList();
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list
          .where((i) =>
              i.internalItemName.toLowerCase().contains(q) ||
              i.partNumber.toLowerCase().contains(q) ||
              (i.customerItems?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return list;
  }

  int get pendingCount => pendingItems.length;
  int get mappedCount => mappedItems.length;
  int get totalItems => allItems.length;
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────
class InventoryItemMappingNotifier extends Notifier<InventoryItemMappingState> {
  late final CurrentStockRepository _repo;

  @override
  InventoryItemMappingState build() {
    _repo = ref.watch(_stockRepoProvider);
    Future.microtask(() => fetchItems());
    return InventoryItemMappingState();
  }

  // ── Tab & search ────────────────────────────────────────────────────────
  void setTab(MappingTab tab) {
    state = state.copyWith(activeTab: tab);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  // ── Fetch stock items (mirrors web's loadData) ──────────────────────────
  Future<void> fetchItems() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _repo.getStockLevels();
      final items = data['items'] as List<StockLevel>;
      state = state.copyWith(allItems: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ── Search customer items (mirrors web's handleSearchChange) ────────────
  Future<void> searchCustomerItems(int stockLevelId, String query) async {
    if (query.trim().isEmpty) {
      final cache = Map<int, List<String>>.from(state.searchResultsCache);
      cache.remove(stockLevelId);
      state = state.copyWith(searchResultsCache: cache);
      return;
    }

    state = state.copyWith(
      searchLoading: {...state.searchLoading, stockLevelId: true},
    );

    try {
      final results = await _repo.searchCustomerItems(query);
      state = state.copyWith(
        searchResultsCache: {
          ...state.searchResultsCache,
          stockLevelId: results,
        },
        searchLoading: {...state.searchLoading, stockLevelId: false},
      );
    } catch (e) {
      state = state.copyWith(
        searchLoading: {...state.searchLoading, stockLevelId: false},
      );
    }
  }

  // ── Select a customer item name (before confirming) ─────────────────────
  void selectCustomerItem(int stockLevelId, String customerItemName) {
    state = state.copyWith(
      selectedCustomerItems: {
        ...state.selectedCustomerItems,
        stockLevelId: customerItemName,
      },
    );
  }

  void clearSelection(int stockLevelId) {
    final updated = Map<int, String>.from(state.selectedCustomerItems);
    updated.remove(stockLevelId);
    state = state.copyWith(selectedCustomerItems: updated);
  }

  // ── Confirm mapping (mirrors web's handleSelectVendorItem) ──────────────
  Future<void> confirmMapping(StockLevel item) async {
    final customerItemName = state.selectedCustomerItems[item.id];
    if (customerItemName == null || customerItemName.trim().isEmpty) {
      state =
          state.copyWith(error: 'Please select or type a customer item name');
      return;
    }

    try {
      // Save mapping to vendor_mapping_entries (same as web)
      await _repo.saveCustomerItemMapping(
        partNumber: item.partNumber,
        vendorDescription: item.internalItemName,
        customerItemName: customerItemName.trim(),
      );

      // Clear selection
      final sel = Map<int, String>.from(state.selectedCustomerItems);
      sel.remove(item.id);
      state = state.copyWith(selectedCustomerItems: sel);

      // Reload data then trigger recalculation (same as web)
      await fetchItems();
      _triggerRecalculation();
    } catch (e) {
      state = state.copyWith(error: 'Failed to save mapping: $e');
    }
  }

  // ── Clear mapping (mirrors web's handleClearCustomerItem) ───────────────
  Future<void> clearMapping(StockLevel item) async {
    try {
      await _repo.clearCustomerItemMapping(item.partNumber);
      await fetchItems();
      _triggerRecalculation();
    } catch (e) {
      state = state.copyWith(error: 'Failed to clear mapping: $e');
    }
  }

  // ── Recalculation polling safeguards ─────────────────────────────────────
  DateTime? _recalcStartTime;
  int _consecutiveRecalcErrors = 0;
  static const int _maxRecalcErrors = 3;
  static const int _maxRecalcSeconds = 90; // DB aggregation, typically <15s

  Duration _recalcBackoff(Duration elapsed) {
    if (elapsed.inSeconds < 15) return const Duration(seconds: 2);
    if (elapsed.inSeconds < 45) return const Duration(seconds: 5);
    return const Duration(seconds: 10);
  }

  // ── Recalculation (mirrors web's triggerRecalculation) ──────────────────
  Future<void> _triggerRecalculation() async {
    try {
      _recalcStartTime = DateTime.now();
      _consecutiveRecalcErrors = 0;
      state = state.copyWith(isRecalculating: true);
      final result = await _repo.calculateStockLevels();
      final taskId = result['task_id'] as String?;
      if (taskId != null) {
        state = state.copyWith(
          recalcTaskId: taskId,
          recalcMessage: 'Recalculating stock...',
        );
        _pollRecalcStatus(taskId);
      }
    } catch (e) {
      state = state.copyWith(isRecalculating: false);
    }
  }

  Future<void> _pollRecalcStatus(String taskId) async {
    // Hard timeout
    final elapsed = DateTime.now().difference(_recalcStartTime ?? DateTime.now());
    if (elapsed.inSeconds >= _maxRecalcSeconds) {
      state = state.copyWith(isRecalculating: false, recalcMessage: null);
      return;
    }

    await Future.delayed(_recalcBackoff(elapsed));

    try {
      final status = await _repo.getRecalculationStatus(taskId);
      _consecutiveRecalcErrors = 0; // reset on success
      final statusStr = status['status'] as String?;
      state = state.copyWith(
        recalcMessage: status['message'] as String? ?? '',
      );

      if (statusStr == 'completed') {
        state = state.copyWith(isRecalculating: false, recalcMessage: null);
        await fetchItems(); // Reload after recalculation completes
      } else if (statusStr == 'failed') {
        state = state.copyWith(isRecalculating: false, recalcMessage: null);
      } else {
        // Still processing — continue with backoff
        _pollRecalcStatus(taskId);
      }
    } catch (e) {
      _consecutiveRecalcErrors++;
      if (_consecutiveRecalcErrors >= _maxRecalcErrors) {
        state = state.copyWith(isRecalculating: false, recalcMessage: null);
        return;
      }
      // Retry on transient error
      _pollRecalcStatus(taskId);
    }
  }

  Future<void> triggerRecalculation() => _triggerRecalculation();

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final inventoryItemMappingProvider =
    NotifierProvider<InventoryItemMappingNotifier, InventoryItemMappingState>(
        InventoryItemMappingNotifier.new);
