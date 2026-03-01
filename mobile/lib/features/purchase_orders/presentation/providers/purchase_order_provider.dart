import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/dashboard/domain/models/dashboard_models.dart';
import 'package:mobile/features/purchase_orders/data/purchase_order_repository.dart';
import 'package:mobile/features/purchase_orders/domain/models/purchase_order_models.dart';

final purchaseOrderRepositoryProvider =
    Provider<PurchaseOrderRepository>((ref) => PurchaseOrderRepository());

// ─── State ────────────────────────────────────────────────────────────────────

class PurchaseOrderState {
  final DraftPoSummary draft;
  final List<PurchaseOrder> history;
  final List<String> suppliers;
  final bool isLoading;
  final bool isProceeding;
  final String? error;
  final String? successPoNumber; // set after successful proceedToPO

  PurchaseOrderState({
    DraftPoSummary? draft,
    this.history = const [],
    this.suppliers = const [],
    this.isLoading = false,
    this.isProceeding = false,
    this.error,
    this.successPoNumber,
  }) : draft = draft ?? DraftPoSummary.empty();

  int get draftCount => draft.totalItems;
  bool get hasDraftItems => draft.items.isNotEmpty;

  PurchaseOrderState copyWith({
    DraftPoSummary? draft,
    List<PurchaseOrder>? history,
    List<String>? suppliers,
    bool? isLoading,
    bool? isProceeding,
    String? error,
    String? successPoNumber,
    bool clearSuccess = false,
    bool clearError = false,
  }) {
    return PurchaseOrderState(
      draft: draft ?? this.draft,
      history: history ?? this.history,
      suppliers: suppliers ?? this.suppliers,
      isLoading: isLoading ?? this.isLoading,
      isProceeding: isProceeding ?? this.isProceeding,
      error: clearError ? null : (error ?? this.error),
      successPoNumber:
          clearSuccess ? null : (successPoNumber ?? this.successPoNumber),
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class PurchaseOrderNotifier extends StateNotifier<PurchaseOrderState> {
  final PurchaseOrderRepository _repo;

  PurchaseOrderNotifier(this._repo) : super(PurchaseOrderState()) {
    loadDraft();
  }

  Future<void> loadDraft() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final results = await Future.wait([
        _repo.getDraftItems(),
        _repo.getSuppliers(),
      ]);
      state = state.copyWith(
        draft: results[0] as DraftPoSummary,
        suppliers: results[1] as List<String>,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadHistory() async {
    try {
      final history = await _repo.getPOHistory();
      state = state.copyWith(history: history);
    } catch (e) {
      debugPrint('loadHistory error: $e');
    }
  }

  /// Add item from the Create PO form.
  Future<bool> addItem(DraftPoItem item) async {
    final ok = await _repo.addDraftItem(item);
    if (ok) await loadDraft();
    return ok;
  }

  /// Quick-add from a StockAlert (dashboard or anywhere else).
  Future<bool> quickAddFromAlert(StockAlert alert) async {
    // Build a DraftPoItem from the alert data
    final item = DraftPoItem(
      partNumber: alert.partNumber,
      itemName: alert.itemName,
      currentStock: alert.currentStock,
      reorderPoint: alert.reorderPoint,
      reorderQty: alert.reorderPoint.ceil().clamp(1, 999),
      unitValue: null,
      priority: alert.isOutOfStock ? 'P0' : 'P1',
    );
    final ok = await _repo.addDraftItem(item);
    if (ok) await loadDraft();
    return ok;
  }

  /// Quick-add from the Dashboard Command Center search results (raw Map).
  Future<bool> quickAddFromDashboard(Map<String, dynamic> itemMap) async {
    final stock = (itemMap['current_stock'] as num?)?.toDouble() ?? 0;
    final reorder = (itemMap['reorder_point'] as num?)?.toDouble() ?? 0;
    final item = DraftPoItem(
      partNumber: itemMap['part_number'] as String? ?? '',
      itemName: itemMap['item_name'] as String? ?? '',
      currentStock: stock,
      reorderPoint: reorder,
      reorderQty: reorder.ceil().clamp(1, 999),
      unitValue: (itemMap['unit_value'] as num?)?.toDouble(),
      priority: stock <= 0 ? 'P0' : (stock < reorder ? 'P1' : 'P2'),
    );
    final ok = await _repo.addDraftItem(item);
    if (ok) await loadDraft();
    return ok;
  }

  Future<void> updateQty(String partNumber, int qty) async {
    if (qty <= 0) return;
    // Optimistic UI update first
    final updatedItems = state.draft.items.map((item) {
      if (item.partNumber == partNumber) return item.copyWithQty(qty);
      return item;
    }).toList();
    final totalCost =
        updatedItems.fold<double>(0, (sum, i) => sum + (i.estimatedCost ?? 0));
    state = state.copyWith(
      draft: DraftPoSummary(
        items: updatedItems,
        totalItems: updatedItems.length,
        totalEstimatedCost: totalCost,
      ),
    );
    // Sync to backend (best effort)
    await _repo.updateDraftQty(partNumber, qty);
  }

  Future<void> removeItem(String partNumber) async {
    // Optimistic UI
    final updatedItems =
        state.draft.items.where((i) => i.partNumber != partNumber).toList();
    final totalCost =
        updatedItems.fold<double>(0, (sum, i) => sum + (i.estimatedCost ?? 0));
    state = state.copyWith(
      draft: DraftPoSummary(
        items: updatedItems,
        totalItems: updatedItems.length,
        totalEstimatedCost: totalCost,
      ),
    );
    await _repo.removeDraftItem(partNumber);
  }

  Future<void> clearDraft() async {
    state = state.copyWith(draft: DraftPoSummary.empty());
    await _repo.clearDraft();
  }

  Future<void> proceedToPO(ProceedToPORequest request) async {
    state = state.copyWith(isProceeding: true, clearError: true);
    try {
      final poNumber = await _repo.proceedToPO(request);
      if (poNumber != null) {
        // Clear draft locally and reload history
        state = state.copyWith(
          isProceeding: false,
          draft: DraftPoSummary.empty(),
          successPoNumber: poNumber,
        );
        await loadHistory();
      } else {
        state = state.copyWith(
          isProceeding: false,
          error: 'Failed to generate purchase order. Please try again.',
        );
      }
    } catch (e) {
      state = state.copyWith(isProceeding: false, error: e.toString());
    }
  }

  void clearSuccess() => state = state.copyWith(clearSuccess: true);
  void clearError() => state = state.copyWith(clearError: true);

  Future<bool> deletePO(String poId) async {
    final success = await _repo.deletePurchaseOrder(poId);
    if (success) {
      await loadHistory();
    }
    return success;
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final purchaseOrderProvider =
    StateNotifierProvider<PurchaseOrderNotifier, PurchaseOrderState>((ref) {
  final repo = ref.watch(purchaseOrderRepositoryProvider);
  return PurchaseOrderNotifier(repo);
});
