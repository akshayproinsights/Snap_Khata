import 'package:dio/dio.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/inventory/domain/models/inventory_models.dart';

class InventoryRepository {
  final Dio _dio;

  InventoryRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  Future<List<InventoryItem>> getInventoryItems({bool showAll = false}) async {
    final response = await _dio.get('/api/inventory/items', queryParameters: {
      'show_all': showAll,
    });
    final items = response.data['items'] as List?;
    return (items ?? []).map((json) => InventoryItem.fromJson(json)).toList();
  }

  Future<void> updateInventoryItem(int id, Map<String, dynamic> updates) async {
    await _dio.patch('/api/inventory/items/$id', data: updates);
  }

  Future<void> deleteInventoryItem(int id) async {
    await _dio.delete('/api/inventory/items/$id');
  }

  Future<void> deleteBulkInventoryItems(List<int> ids) async {
    await _dio.post('/api/inventory/items/delete-bulk', data: {'ids': ids});
  }

  Future<void> deleteByImageHash(String imageHash) async {
    await _dio.delete('/api/inventory/by-hash/$imageHash');
  }

  // Upload APIs
  Future<Map<String, dynamic>> uploadFiles(List<dynamic> files,
      {Function(int, int)? onProgress}) async {
    final formData = FormData();
    for (var file in files) {
      formData.files.add(MapEntry(
        'files',
        await MultipartFile.fromFile(file.path, filename: file.name),
      ));
    }
    final response = await _dio.post('/api/inventory/upload',
        data: formData, onSendProgress: onProgress);
    return response.data;
  }

  Future<Map<String, dynamic>> processInventory(List<String> fileKeys,
      {bool forceUpload = false}) async {
    final response = await _dio.post('/api/inventory/process', data: {
      'file_keys': fileKeys,
      'force_upload': forceUpload,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getProcessStatus(String taskId) async {
    final response = await _dio.get('/api/inventory/status/$taskId');
    return response.data;
  }

  Future<Map<String, dynamic>> getRecentTask() async {
    final response = await _dio.get('/api/inventory/recent-task');
    return response.data;
  }

  Future<Map<String, dynamic>> getUploadHistory() async {
    final response = await _dio.get('/api/inventory/upload-history');
    return response.data;
  }
}
