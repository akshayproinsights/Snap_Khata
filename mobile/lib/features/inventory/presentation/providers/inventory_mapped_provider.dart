import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/inventory/data/inventory_mapped_repository.dart';
import 'package:mobile/features/inventory/domain/models/inventory_mapped_models.dart';

final inventoryMappedRepositoryProvider =
    Provider((ref) => InventoryMappedRepository());

class InventoryMappedState {
  final List<VendorMappingEntry> entries;
  final bool isLoading;
  final String? error;

  InventoryMappedState({
    this.entries = const [],
    this.isLoading = false,
    this.error,
  });

  InventoryMappedState copyWith({
    List<VendorMappingEntry>? entries,
    bool? isLoading,
    String? error,
  }) {
    return InventoryMappedState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  int get totalMapped => entries.length;
  int get addedCount => entries
      .where((e) =>
          e.status == 'Pending' ||
          e.status == 'Mark as Done' ||
          e.status == 'Added')
      .length;
  int get skippedCount =>
      entries.where((e) => e.status == 'Skip' || e.status == 'Skipped').length;
}

class InventoryMappedNotifier extends StateNotifier<InventoryMappedState> {
  final InventoryMappedRepository _repository;

  InventoryMappedNotifier(this._repository) : super(InventoryMappedState()) {
    fetchEntries();
  }

  Future<void> fetchEntries() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final entries = await _repository.getMappedEntries();
      // Sort newest first
      entries.sort((a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      state = state.copyWith(entries: entries, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> unmapEntry(int? id) async {
    if (id == null) return;
    try {
      await _repository.unmapEntry(id);
      fetchEntries(); // Refresh
    } catch (e) {
      state = state.copyWith(error: 'Failed to unmap: \$e');
    }
  }
}

final inventoryMappedProvider =
    StateNotifierProvider<InventoryMappedNotifier, InventoryMappedState>((ref) {
  return InventoryMappedNotifier(ref.watch(inventoryMappedRepositoryProvider));
});
