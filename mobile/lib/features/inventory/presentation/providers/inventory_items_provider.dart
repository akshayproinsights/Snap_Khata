import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/inventory/data/inventory_repository.dart';
import 'package:mobile/features/inventory/domain/models/inventory_models.dart';

/// Provides all inventory items from the `inventory_items` table
/// via GET /api/inventory/items?show_all=true.
/// This is the correct data source for the Inventory main page.
final inventoryItemsProvider =
    FutureProvider.autoDispose<List<InventoryItem>>((ref) async {
  final repo = InventoryRepository();
  return repo.getInventoryItems(showAll: true);
});
