import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/inventory/data/inventory_repository.dart';
import 'package:mobile/features/inventory/domain/models/inventory_models.dart';

/// Provides price history for a specific item by its description.
/// Reads from inventory_items (verified items only) via GET /api/inventory/item-price-history.
/// Sorted chronologically ASC so the sparkline shows oldest → newest.
final itemPriceHistoryProvider = FutureProvider.family
    .autoDispose<List<InventoryItem>, String>((ref, description) async {
  final repo = InventoryRepository();
  return repo.getItemPriceHistory(description: description);
});

/// Provider to fetch all items belonging to a specific invoice number.
/// Used when navigating from purchase history to the invoice review page.
final invoiceItemsProvider = FutureProvider.family
    .autoDispose<List<InventoryItem>, String>((ref, invoiceNumber) async {
  final repo = InventoryRepository();
  return repo.getItemsByInvoiceNumber(invoiceNumber);
});
