import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/inventory/data/inventory_repository.dart';
import 'package:mobile/features/inventory/domain/models/inventory_models.dart';
import 'package:mobile/features/inventory/domain/utils/invoice_math_logic.dart';
import 'package:mobile/features/inventory/presentation/providers/inventory_items_provider.dart';
import 'package:mobile/features/inventory/presentation/providers/vendor_ledger_provider.dart';
import 'package:mobile/features/udhar/presentation/providers/udhar_dashboard_provider.dart';

final inventoryRepositoryProvider =
    Provider<InventoryRepository>((ref) => InventoryRepository());

class InventoryState {
  final List<InventoryItem> items;
  final bool isLoading;
  final bool isSyncing;
  final String? error;
  final DateTime? batchTimestamp; // Track when last batch was processed to identify new items

  InventoryState({
    this.items = const [],
    this.isLoading = false,
    this.isSyncing = false,
    this.error,
    this.batchTimestamp,
  });

  InventoryState copyWith({
    List<InventoryItem>? items,
    bool? isLoading,
    bool? isSyncing,
    String? error,
    DateTime? batchTimestamp,
  }) {
    return InventoryState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      error: error,
      batchTimestamp: batchTimestamp ?? this.batchTimestamp,
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
          final updatedJson = {...item.toJson(), ...updates};
          
          // Recompute math logic locally using InvoiceMathLogic
          final mathRes = InvoiceMathLogic.processItem(
            qty: (updatedJson['quantity'] as num?)?.toDouble() ?? 0.0,
            rate: (updatedJson['rate'] as num?)?.toDouble() ?? 0.0,
            origDiscPct: (updatedJson['disc_percent'] as num?)?.toDouble() ?? 0.0,
            origDiscAmt: (updatedJson['disc_amount'] as num?)?.toDouble() ?? 0.0,
            cgstPct: (updatedJson['cgst_percent'] as num?)?.toDouble() ?? 0.0,
            sgstPct: (updatedJson['sgst_percent'] as num?)?.toDouble() ?? 0.0,
            igstPct: (updatedJson['igst_percent'] as num?)?.toDouble() ?? 0.0,
            printedTotal: (updatedJson['printed_total'] as num?)?.toDouble() ?? 0.0,
            taxType: updatedJson['tax_type'] as String? ?? 'UNKNOWN',
          );
          
          updatedJson['gross_amount'] = mathRes['grossAmount'];
          updatedJson['disc_type'] = mathRes['discType'];
          updatedJson['disc_percent'] = mathRes['discPercent'];
          updatedJson['disc_amount'] = mathRes['discAmount'];
          updatedJson['taxable_amount'] = mathRes['taxableAmount'];
          updatedJson['cgst_percent'] = mathRes['cgstPercent'];
          updatedJson['cgst_amount'] = mathRes['cgstAmount'];
          updatedJson['sgst_percent'] = mathRes['sgstPercent'];
          updatedJson['sgst_amount'] = mathRes['sgstAmount'];
          updatedJson['igst_percent'] = mathRes['igstPercent'];
          updatedJson['igst_amount'] = mathRes['igstAmount'];
          updatedJson['net_bill'] = mathRes['netAmount'];
          updatedJson['mismatch_amount'] = mathRes['mismatchAmount'];
          updatedJson['needs_review'] = mathRes['needsReview'];

          return InventoryItem.fromJson(updatedJson);
        }
        return item;
      }).toList();
      state = state.copyWith(items: newItems);

      await _repository.updateInventoryItem(id, updates);
      ref.invalidate(inventoryItemsProvider);
      ref.invalidate(vendorLedgerProvider);
      ref.invalidate(udharDashboardProvider);
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
      ref.invalidate(inventoryItemsProvider);
      ref.invalidate(vendorLedgerProvider);
      ref.invalidate(udharDashboardProvider);
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
      ref.invalidate(inventoryItemsProvider);
      ref.invalidate(vendorLedgerProvider);
      ref.invalidate(udharDashboardProvider);
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete items: $e');
      await fetchItems(); // Revert
    }
  }

  Future<void> verifyInvoice(Map<String, dynamic> data) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      await _repository.verifyInvoice(data);
      ref.invalidate(inventoryItemsProvider);
      ref.invalidate(vendorLedgerProvider);
      ref.invalidate(udharDashboardProvider);
      await fetchItems(); // Refresh the items to remove the verified ones
    } catch (e) {
      state = state.copyWith(
          isLoading: false, error: 'Failed to verify invoice: $e');
      rethrow; // Rethrow so the UI can catch and show a snackbar
    }
  }

  Future<void> syncAndFinish() async {
    state = state.copyWith(isSyncing: true, error: null);
    final previousItems = state.items; // save for rollback
    try {
      // Find all pending items
      final pendingItems = state.items.where((i) => i.verificationStatus != 'Done').toList();
      
      // Optimistic Update: instantly remove pending items from UI
      final newItems = state.items.where((i) => i.verificationStatus == 'Done').toList();
      state = state.copyWith(items: newItems);

      // Group them by invoice number / vendor + date
      final Map<String, List<InventoryItem>> groups = {};
      for (final item in pendingItems) {
        final key = item.invoiceNumber.isNotEmpty
            ? item.invoiceNumber
            : '${item.invoiceDate}_${item.vendorName ?? ''}';
        final safeKey = key.isNotEmpty ? key : item.id.toString();
        
        if (!groups.containsKey(safeKey)) {
          groups[safeKey] = [];
        }
        groups[safeKey]!.add(item);
      }
      
      // For each group, call verifyInvoice
      final futures = <Future<void>>[];
      for (final groupItems in groups.values) {
        if (groupItems.isEmpty) continue;
        final firstItem = groupItems.first;
        
        // ── Two-Scenario Grand Total (mirrors inventory_invoice_review_page) ──
        final hasPerItemDiscount = groupItems.any(
          (i) => (i.discAmount ?? 0.0) > 0.01 || (i.discPercent ?? 0.0) > 0.01,
        );

        final adjList = firstItem.headerAdjustments ?? [];

        // ROUND_OFF / OTHER only — always applied on top in both scenarios
        final nonDiscountAdj = adjList.fold<double>(0.0, (sum, adj) {
          final t = adj.adjustmentType.toUpperCase();
          return (t == 'ROUND_OFF' || t == 'OTHER') ? sum + adj.amount : sum;
        });

        double baseTotal;
        if (hasPerItemDiscount) {
          // Scenario A: discounts already baked into each item's netAmount
          baseTotal = groupItems.fold(0.0, (sum, item) => sum + (item.netAmount ?? item.netBill));
        } else {
          // Scenario B: header-only discount → apply before GST
          final totalGross = groupItems.fold(0.0,
              (sum, item) => sum + (item.grossAmount ?? (item.qty * item.rate)));
          final headerDiscount = adjList.fold<double>(0.0, (sum, adj) {
            final t = adj.adjustmentType.toUpperCase();
            return (t == 'HEADER_DISCOUNT' || t == 'SCHEME') ? sum + adj.amount.abs() : sum;
          });
          final totalTaxable = (totalGross - headerDiscount).clamp(0.0, double.maxFinite);
          final origTaxable = groupItems.fold<double>(0.0,
              (sum, item) => sum + (item.taxableAmount ?? item.grossAmount ?? (item.qty * item.rate)));
          final totalGst = groupItems.fold<double>(0.0,
              (sum, item) => sum + (item.cgstAmount ?? 0.0) + (item.sgstAmount ?? 0.0) + (item.igstAmount ?? 0.0));
          final scaledGst = origTaxable > 0 ? totalGst * (totalTaxable / origTaxable) : totalGst;
          baseTotal = totalTaxable + scaledGst;
        }

        final totalAmount = baseTotal + nonDiscountAdj;
        final data = {
          'invoice_number': firstItem.invoiceNumber.isNotEmpty ? firstItem.invoiceNumber : 'Auto-Gen-${DateTime.now().millisecondsSinceEpoch}',
          'vendor_name': firstItem.vendorName ?? 'Unknown Vendor',
          'invoice_date': firstItem.invoiceDate,
          'payment_mode': 'Credit',
          'balance_owed': totalAmount,
          'amount_paid': 0.0,
          'item_ids': groupItems.map((i) => i.id).toList(),
          'final_total': totalAmount,
          'adjustments': (firstItem.headerAdjustments ?? []).map((a) => a.toJson()).toList(),
        };
        
        futures.add(_repository.verifyInvoice(data));
      }

      await Future.wait(futures);
      
      ref.invalidate(inventoryItemsProvider);
      ref.invalidate(udharDashboardProvider);

      // Finally, fetch items to ensure we are up to date
      await fetchItems();
    } catch (e) {
      state = state.copyWith(error: 'Sync failed: $e', items: previousItems);
    } finally {
      state = state.copyWith(isSyncing: false);
    }
  }
}

final inventoryProvider =
    NotifierProvider<InventoryNotifier, InventoryState>(InventoryNotifier.new);
