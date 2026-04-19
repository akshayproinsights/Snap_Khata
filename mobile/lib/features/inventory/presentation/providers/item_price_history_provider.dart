import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/inventory/data/inventory_repository.dart';
import 'package:mobile/features/inventory/domain/models/inventory_models.dart';

/// Provides item price history for a given item description.
final itemPriceHistoryProvider = FutureProvider.family
    .autoDispose<List<InventoryItem>, String>((ref, description) async {
  final repo = InventoryRepository();
  return repo.getPriceHistory(description: description);
});
