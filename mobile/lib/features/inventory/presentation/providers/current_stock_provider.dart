import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:mobile/features/inventory/data/current_stock_repository.dart';
import 'package:mobile/features/inventory/domain/models/current_stock_models.dart';

final currentStockRepositoryProvider =
    Provider((ref) => CurrentStockRepository());

class CurrentStockState {
  final List<StockLevel> items;
  final StockSummary summary;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final String statusFilter;
  final String priorityFilter;
  final bool isCalculating;
  final bool hasMore;
  final int offset;
  final int limit;

  CurrentStockState({
    this.items = const [],
    StockSummary? summary,
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.statusFilter = 'all',
    this.priorityFilter = 'all',
    this.isCalculating = false,
    this.hasMore = true,
    this.offset = 0,
    this.limit = 20,
  }) : summary = summary ??
            StockSummary(
                totalStockValue: 0,
                lowStockItems: 0,
                outOfStock: 0,
                totalItems: 0);

  CurrentStockState copyWith({
    List<StockLevel>? items,
    StockSummary? summary,
    bool? isLoading,
    String? error,
    String? searchQuery,
    String? statusFilter,
    String? priorityFilter,
    bool? isCalculating,
    bool? hasMore,
    int? offset,
    int? limit,
  }) {
    return CurrentStockState(
      items: items ?? this.items,
      summary: summary ?? this.summary,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
      priorityFilter: priorityFilter ?? this.priorityFilter,
      isCalculating: isCalculating ?? this.isCalculating,
      hasMore: hasMore ?? this.hasMore,
      offset: offset ?? this.offset,
      limit: limit ?? this.limit,
    );
  }
}

class CurrentStockNotifier extends Notifier<CurrentStockState> {
  late final CurrentStockRepository _repository;
  Timer? _recalcTimer;

  @override
  CurrentStockState build() {
    _repository = ref.watch(currentStockRepositoryProvider);

    ref.onDispose(() {
      _recalcTimer?.cancel();
    });

    Future.microtask(() {
      fetchData();
      triggerRecalculation(); // Initial recalculation
    });
    return CurrentStockState();
  }

  Future<void> fetchData() async {
    if (state.isLoading) return;
    state =
        state.copyWith(isLoading: true, error: null, offset: 0, hasMore: true);
    try {
      final results = await Future.wait([
        _repository.getStockLevels(
          search: state.searchQuery,
          statusFilter: state.statusFilter,
          priorityFilter: state.priorityFilter,
          limit: state.limit,
          offset: 0,
        ),
        _repository.getStockSummary(),
      ]);

      final itemsData = results[0] as Map<String, dynamic>;
      final summary = results[1] as StockSummary;
      final items = itemsData['items'] as List<StockLevel>;

      // Apply Quick Reorder Sorting
      items.sort((a, b) {
        final stockA = a.currentStock + (a.manualAdjustment ?? 0);
        final stockB = b.currentStock + (b.manualAdjustment ?? 0);

        // Priority 1: Negative stock items first
        if (stockA < 0 && stockB >= 0) return -1;
        if (stockB < 0 && stockA >= 0) return 1;

        // Priority 2: Zero stock items second
        if (stockA == 0 && stockB > 0) return -1;
        if (stockB == 0 && stockA > 0) return 1;

        // Priority 3: Low stock items third
        final aIsLow = stockA > 0 && stockA <= a.reorderPoint;
        final bIsLow = stockB > 0 && stockB <= b.reorderPoint;

        if (aIsLow && !bIsLow) return -1;
        if (bIsLow && !aIsLow) return 1;

        // Default: maintain original order (by name)
        return a.internalItemName.compareTo(b.internalItemName);
      });

      final total = itemsData['total'] as int? ?? items.length;

      state = state.copyWith(
        items: items,
        summary: summary,
        isLoading: false,
        hasMore: items.length < total,
        offset: items.length,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchMoreData() async {
    if (state.isLoading || !state.hasMore) return;

    // Using a subtle loading state for pagination without clearing items
    state = state.copyWith(isLoading: true, error: null);
    try {
      final itemsData = await _repository.getStockLevels(
        search: state.searchQuery,
        statusFilter: state.statusFilter,
        priorityFilter: state.priorityFilter,
        limit: state.limit,
        offset: state.offset,
      );

      final newItems = itemsData['items'] as List<StockLevel>;

      final updatedItems = [...state.items, ...newItems];

      // Re-apply sorting for all items
      updatedItems.sort((a, b) {
        final stockA = a.currentStock + (a.manualAdjustment ?? 0);
        final stockB = b.currentStock + (b.manualAdjustment ?? 0);

        // Priority 1: Negative stock items first
        if (stockA < 0 && stockB >= 0) return -1;
        if (stockB < 0 && stockA >= 0) return 1;

        // Priority 2: Zero stock items second
        if (stockA == 0 && stockB > 0) return -1;
        if (stockB == 0 && stockA > 0) return 1;

        // Priority 3: Low stock items third
        final aIsLow = stockA > 0 && stockA <= a.reorderPoint;
        final bIsLow = stockB > 0 && stockB <= b.reorderPoint;

        if (aIsLow && !bIsLow) return -1;
        if (bIsLow && !aIsLow) return 1;

        // Default: maintain original order (by name)
        return a.internalItemName.compareTo(b.internalItemName);
      });

      final total =
          itemsData['total'] as int? ?? state.items.length + newItems.length;

      state = state.copyWith(
        items: updatedItems,
        isLoading: false,
        hasMore: updatedItems.length < total,
        offset: updatedItems.length,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    fetchData();
  }

  void setFilters({String? status, String? priority}) {
    state = state.copyWith(
      statusFilter: status ?? state.statusFilter,
      priorityFilter: priority ?? state.priorityFilter,
    );
    fetchData();
  }

  Future<void> updateStockLevel(int id, String field, dynamic value) async {
    try {
      // Optimistic update
      final newItems = state.items.map((item) {
        if (item.id == id) {
          if (field == 'reorder_point') {
            return StockLevel(
              id: item.id,
              partNumber: item.partNumber,
              internalItemName: item.internalItemName,
              customerItems: item.customerItems,
              currentStock: item.currentStock,
              reorderPoint: value as int,
              manualAdjustment: item.manualAdjustment,
              priority: item.priority,
              status: item.status,
              unitValue: item.unitValue,
            );
          }
          if (field == 'priority') {
            return StockLevel(
              id: item.id,
              partNumber: item.partNumber,
              internalItemName: item.internalItemName,
              customerItems: item.customerItems,
              currentStock: item.currentStock,
              reorderPoint: item.reorderPoint,
              manualAdjustment: item.manualAdjustment,
              priority: value as String,
              status: item.status,
              unitValue: item.unitValue,
            );
          }
          if (field == 'unit_value') {
            return StockLevel(
              id: item.id,
              partNumber: item.partNumber,
              internalItemName: item.internalItemName,
              customerItems: item.customerItems,
              currentStock: item.currentStock,
              reorderPoint: item.reorderPoint,
              manualAdjustment: item.manualAdjustment,
              priority: item.priority,
              status: item.status,
              unitValue: (value as num).toDouble(),
            );
          }
        }
        return item;
      }).toList();
      state = state.copyWith(items: newItems);

      await _repository.updateStockLevel(id, {field: value});
      triggerRecalculation();
    } catch (e) {
      fetchData(); // Revert
    }
  }

  Future<void> updatePhysicalCount(int id, int count) async {
    final item = state.items.firstWhere((i) => i.id == id);
    try {
      final systemStock = item.currentStock;
      final newAdjustment = count - systemStock;

      final newItems = state.items.map((i) {
        if (i.id == id) {
          return StockLevel(
            id: i.id,
            partNumber: i.partNumber,
            internalItemName: i.internalItemName,
            customerItems: i.customerItems,
            currentStock: i.currentStock,
            reorderPoint: i.reorderPoint,
            manualAdjustment: newAdjustment,
            priority: i.priority,
            status: i.status,
            unitValue: i.unitValue,
          );
        }
        return i;
      }).toList();
      state = state.copyWith(items: newItems);

      await _repository.updateStockAdjustment(item.partNumber, count);
      triggerRecalculation();
    } catch (e) {
      fetchData();
    }
  }

  Future<void> triggerRecalculation() async {
    _recalcTimer?.cancel();
    state = state.copyWith(isCalculating: true);
    try {
      final res = await _repository.calculateStockLevels();
      final taskId = res['task_id'];
      if (taskId != null) {
        _pollRecalculation(taskId);
      } else {
        state = state.copyWith(isCalculating: false);
        fetchData();
      }
    } catch (e) {
      state = state.copyWith(isCalculating: false);
      fetchData();
    }
  }

  void _pollRecalculation(String taskId) {
    _recalcTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final status = await _repository.getRecalculationStatus(taskId);
        if (status['status'] == 'completed' || status['status'] == 'failed') {
          timer.cancel();
          state = state.copyWith(isCalculating: false);
          if (status['status'] == 'completed') {
            fetchData();
          }
        }
      } catch (e) {
        timer.cancel();
        state = state.copyWith(isCalculating: false);
      }
    });
  }
}

final currentStockProvider =
    NotifierProvider<CurrentStockNotifier, CurrentStockState>(
        CurrentStockNotifier.new);
