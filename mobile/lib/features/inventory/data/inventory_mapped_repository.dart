import 'package:dio/dio.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/inventory/domain/models/inventory_mapped_models.dart';

class InventoryMappedRepository {
  final Dio _dio;

  InventoryMappedRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  Future<List<VendorMappingEntry>> getMappedEntries() async {
    final response = await _dio.get('/api/vendor-mapping/entries');
    final data = response.data;
    if (data['entries'] != null) {
      return (data['entries'] as List)
          .map((e) => VendorMappingEntry.fromJson(e))
          .toList();
    }
    return [];
  }

  Future<void> unmapEntry(int id) async {
    await _dio.delete('/api/vendor-mapping/entries/$id');
  }
}
