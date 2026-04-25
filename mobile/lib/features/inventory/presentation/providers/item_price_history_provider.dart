import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/inventory/data/inventory_repository.dart';
import 'package:mobile/features/inventory/domain/models/inventory_models.dart';

/// Provides price history for a vendor from inventory_invoices.
/// The [vendorName] parameter matches the `description` field returned
/// by /tracked-items (which is set to vendor_name on the backend).
final itemPriceHistoryProvider = FutureProvider.family
    .autoDispose<List<InventoryItem>, String>((ref, vendorName) async {
  final repo = InventoryRepository();
  return repo.getVendorPriceHistory(vendorName: vendorName);
});
