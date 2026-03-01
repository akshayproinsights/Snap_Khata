import 'package:dio/dio.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/inventory/domain/models/inventory_item_mapping_models.dart';

class InventoryItemMappingRepository {
  final Dio _dio;

  InventoryItemMappingRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  /// Returns stock-register items that have no customer_items mapping yet.
  /// This mirrors the web's "Items to Map" count (307 items from stock_levels
  /// where customer_items is null/empty).
  Future<List<CustomerItem>> getUnmappedCustomerItems(String? search) async {
    final queryParams = <String, dynamic>{};
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    final response = await _dio.get('/api/stock/unmapped-items',
        queryParameters: queryParams);
    return (response.data['items'] as List?)
            ?.map((json) => CustomerItem.fromJson(json))
            .toList() ??
        [];
  }

  Future<List<VendorItem>> getCustomerItemSuggestions(
      String customerItem) async {
    final response = await _dio.get(
      '/api/inventory-mapping/customer-items/suggestions',
      queryParameters: {'customer_item': customerItem},
    );
    return (response.data['suggestions'] as List?)
            ?.map((json) => VendorItem.fromJson(json))
            .toList() ??
        [];
  }

  Future<List<VendorItem>> searchVendorItems(String query, int limit) async {
    final response = await _dio.get(
      '/api/inventory-mapping/customer-items/search',
      queryParameters: {'query': query, 'limit': limit},
    );
    return (response.data['results'] as List?)
            ?.map((json) => VendorItem.fromJson(json))
            .toList() ??
        [];
  }

  /// Search for existing customer item names from verified invoices
  /// so users can pick a known customer name when mapping.
  Future<List<VendorItem>> searchCustomerItemNames(String query) async {
    try {
      final response = await _dio.get(
        '/api/verified/unique-customer-items',
        queryParameters: {'search': query},
      );
      final items = (response.data['customer_items'] as List?) ?? [];
      return items
          .asMap()
          .entries
          .map((e) => VendorItem(
                id: e.key,
                description: e.value as String,
                partNumber: '',
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Confirm mapping: save customer_item_name for a stock register item.
  /// This updates stock_levels.customer_items and creates a vendor_mapping_entries record.
  Future<void> confirmStockItemMapping({
    required String partNumber,
    required String internalItemName,
    required String customerItemName,
    int? stockLevelId,
  }) async {
    await _dio.post('/api/stock/map-customer-item', data: {
      'part_number': partNumber,
      'internal_item_name': internalItemName,
      'customer_item_name': customerItemName,
      'stock_level_id': stockLevelId,
    });
  }

  Future<void> skipCustomerItem(String customerItem) async {
    await _dio.post(
      '/api/inventory-mapping/customer-items/skip',
      queryParameters: {'customer_item': customerItem},
    );
  }

  Future<Map<String, dynamic>> syncCustomerItemMappings() async {
    final response =
        await _dio.post('/api/inventory-mapping/customer-items/sync');
    return response.data;
  }
}
