import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/inventory/data/inventory_repository.dart';
import 'package:mobile/features/inventory/domain/models/inventory_models.dart';

final inventoryRepositoryProvider =
    Provider<InventoryRepository>((ref) => InventoryRepository());

class InventoryState {
  final List<InventoryItem> items;
  final bool isLoading;
  final bool isSyncing;
  final String? error;

  InventoryState({
    this.items = const [],
    this.isLoading = false,
    this.isSyncing = false,
    this.error,
  });

  InventoryState copyWith({
    List<InventoryItem>? items,
    bool? isLoading,
    bool? isSyncing,
    String? error,
  }) {
    return InventoryState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      error: error,
    );
  }
}

class InventoryNotifier extends Notifier<InventoryState> {
  late final InventoryRepository _repository;

  @override
  InventoryState build() {
    _repository = ref.watch(inventoryRepositoryProvider);
    Future.microtask(() => fetchItems());
    return InventoryState();
  }

  Future<void> fetchItems({bool showAll = false}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final items = await _repository.getInventoryItems(showAll: showAll);
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Alias for refreshing all items (showAll: true).
  Future<void> refresh() => fetchItems(showAll: true);

  Future<void> updateItem(int id, Map<String, dynamic> updates) async {
    try {
      // Optimistic update
      final newItems = state.items.map((item) {
        if (item.id == id) {
          return InventoryItem.fromJson({...item.toJson(), ...updates});
        }
        return item;
      }).toList();
      state = state.copyWith(items: newItems);

      await _repository.updateInventoryItem(id, updates);
    } catch (e) {
      state = state.copyWith(error: 'Failed to update item: $e');
      await fetchItems(); // Revert
    }
  }

  Future<void> deleteItem(int id) async {
    try {
      // Optimistic
      final newItems = state.items.where((item) => item.id != id).toList();
      state = state.copyWith(items: newItems);

      await _repository.deleteInventoryItem(id);
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete item: $e');
      await fetchItems(); // Revert
    }
  }

  Future<void> bulkDeleteItems(List<int> ids) async {
    try {
      // Optimistic
      final newItems =
          state.items.where((item) => !ids.contains(item.id)).toList();
      state = state.copyWith(items: newItems);

      await _repository.deleteBulkInventoryItems(ids);
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete items: $e');
      await fetchItems(); // Revert
    }
  }

  Future<void> verifyInvoice(Map<String, dynamic> data) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      await _repository.verifyInvoice(data);
      await fetchItems(); // Refresh the items to remove the verified ones
    } catch (e) {
      state = state.copyWith(
          isLoading: false, error: 'Failed to verify invoice: $e');
      rethrow; // Rethrow so the UI can catch and show a snackbar
    }
  }

  Future<void> syncAndFinish() async {
    state = state.copyWith(isSyncing: true, error: null);
    try {
      await Future.delayed(const Duration(milliseconds: 1000));
      // Just fetch items to ensure we are up to date
      await fetchItems();
    } catch (e) {
      state = state.copyWith(error: 'Sync failed: $e');
    } finally {
      state = state.copyWith(isSyncing: false);
    }
  }
}

final inventoryProvider =
    NotifierProvider<InventoryNotifier, InventoryState>(InventoryNotifier.new);
