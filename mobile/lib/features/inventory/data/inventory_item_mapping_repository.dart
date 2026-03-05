import 'package:dio/dio.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/inventory/domain/models/inventory_item_mapping_models.dart';

class InventoryItemMappingRepository {
  final Dio _dio;

  InventoryItemMappingRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  /// Returns unique customer items from verified_invoices (type='Part') that
  /// haven't been mapped yet. Mirrors the web app's "Items to Map" flow.
  /// Endpoint: GET /api/inventory-mapping/customer-items/unmapped
  Future<List<CustomerItem>> getUnmappedCustomerItems(String? search) async {
    final queryParams = <String, dynamic>{};
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    final response = await _dio.get(
      '/api/inventory-mapping/customer-items/unmapped',
      queryParameters: queryParams,
    );
    return (response.data['items'] as List?)
            ?.map((json) => CustomerItem.fromJson(json))
            .toList() ??
        [];
  }

  /// Get all mapped items (status=Done or Added) from inventory_mapped table.
  /// Endpoint: GET /api/inventory-mapping/customer-items/mapped
  Future<List<MappedItem>> getMappedCustomerItems() async {
    final response = await _dio.get(
      '/api/inventory-mapping/customer-items/mapped',
    );
    return (response.data['items'] as List?)
            ?.map((json) => MappedItem.fromJson(json))
            .toList() ??
        [];
  }

  /// Fuzzy suggestions for a given customer item name against inventory items.
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

  /// Live search inventory_items table as user types.
  /// Endpoint: GET /api/inventory-mapping/customer-items/search?q=...
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

  /// Confirm mapping: saves to inventory_mapped table (same as web app).
  /// supports mapping all spelling variations together.
  Future<void> confirmCustomerItemMapping({
    required String customerItem,
    required String normalizedDescription,
    int? vendorItemId,
    String? vendorDescription,
    String? vendorPartNumber,
    int priority = 0,
    List<String>? variations,
  }) async {
    await _dio.post('/api/inventory-mapping/customer-items/confirm', data: {
      'customer_item': customerItem,
      'normalized_description': normalizedDescription,
      'vendor_item_id': vendorItemId,
      'vendor_description': vendorDescription,
      'vendor_part_number': vendorPartNumber,
      'priority': priority,
      'variations': variations,
    });
  }

  /// Mark item as Skipped — won't appear in unmapped list anymore.
  Future<void> skipCustomerItem(String customerItem) async {
    await _dio.post(
      '/api/inventory-mapping/customer-items/skip',
      data: {'customer_item': customerItem},
    );
  }

  /// Finalize all Done mappings by marking them as synced.
  Future<Map<String, dynamic>> syncCustomerItemMappings() async {
    final response =
        await _dio.post('/api/inventory-mapping/customer-items/sync');
    return response.data;
  }

  /// Get summary stats: pending count, done count, skipped count.
  Future<Map<String, dynamic>> getMappingStats() async {
    final response =
        await _dio.get('/api/inventory-mapping/customer-items/stats');
    return response.data;
  }
}
