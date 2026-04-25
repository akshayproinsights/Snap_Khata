import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/inventory/data/inventory_repository.dart';
import 'package:mobile/features/inventory/domain/models/inventory_models.dart';

/// Provides tracked supplier invoices from the `inventory_invoices` table
/// via GET /api/inventory/tracked-items.
/// Each unique vendor appears as a trackable item on the Track Items page.
final inventoryItemsProvider =
    FutureProvider.autoDispose<List<InventoryItem>>((ref) async {
  final repo = InventoryRepository();
  return repo.getTrackedItems();
});
