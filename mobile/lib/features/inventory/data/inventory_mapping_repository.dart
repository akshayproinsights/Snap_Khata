import 'package:dio/dio.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/inventory/domain/models/inventory_mapping_models.dart';

class InventoryMappingRepository {
  final Dio _dio;

  InventoryMappingRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  Future<Map<String, dynamic>> getGroupedItems(int page, int limit,
      {String? status}) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    if (status != null) {
      queryParams['status'] = status;
    }

    final response = await _dio.get('/api/inventory-mapping/grouped-items',
        queryParameters: queryParams);
    final items = (response.data['items'] as List?)
            ?.map((json) => GroupedItem.fromJson(json))
            .toList() ??
        [];
    return {
      'items': items,
      'total': response.data['total'] ?? 0,
    };
  }

  Future<List<InventorySuggestionItem>> getInventorySuggestions(
      String customerItem) async {
    final response = await _dio.get(
      '/api/inventory-mapping/customer-items/suggestions',
      queryParameters: {'customer_item': customerItem},
    );
    return (response.data['suggestions'] as List?)
            ?.map((json) => InventorySuggestionItem.fromJson(json))
            .toList() ??
        [];
  }

  Future<List<InventorySuggestionItem>> searchInventory(
      String query, int limit) async {
    final response = await _dio.get(
      '/api/inventory-mapping/customer-items/search',
      queryParameters: {'q': query, 'limit': limit},
    );
    return (response.data['results'] as List?)
            ?.map((json) => InventorySuggestionItem.fromJson(json))
            .toList() ??
        [];
  }

  Future<void> confirmMapping({
    required String customerItem,
    required List<int> groupedInvoiceIds,
    required int mappedInventoryItemId,
    required String mappedInventoryDescription,
  }) async {
    await _dio.post('/api/inventory-mapping/confirm', data: {
      'customer_item': customerItem,
      'grouped_invoice_ids': groupedInvoiceIds,
      'mapped_inventory_item_id': mappedInventoryItemId,
      'mapped_inventory_description': mappedInventoryDescription,
    });
  }

  Future<void> updateMappingStatus(int id, String status) async {
    await _dio.put('/api/inventory-mapping/$id/status', data: {
      'status': status,
    });
  }
}
