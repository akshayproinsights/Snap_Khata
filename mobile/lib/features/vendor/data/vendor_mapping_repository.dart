import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/vendor/domain/models/vendor_mapping_models.dart';
import 'package:image_picker/image_picker.dart';

class VendorMappingRepository {
  final Dio _dio;

  VendorMappingRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  Future<Map<String, dynamic>> getExportData() async {
    final response = await _dio.get('/api/vendor-mapping/export-data');
    final items = (response.data['items'] as List)
        .map((e) => VendorMappingExportItem.fromJson(e))
        .toList();
    return {
      'items': items,
      'total': response.data['total'] ?? 0,
    };
  }

  Future<Map<String, dynamic>> uploadScan(XFile file,
      {Function(int, int)? onProgress}) async {
    final formData = FormData();

    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      formData.files.add(MapEntry(
        'file',
        MultipartFile.fromBytes(bytes, filename: file.name),
      ));
    } else {
      formData.files.add(MapEntry(
        'file',
        await MultipartFile.fromFile(file.path, filename: file.name),
      ));
    }

    final response = await _dio.post(
      '/api/vendor-mapping/upload-scan',
      data: formData,
      onSendProgress: onProgress,
    );
    return response.data;
  }

  Future<Map<String, dynamic>> uploadScans(List<XFile> files,
      {Function(int, int)? onProgress}) async {
    final formData = FormData();
    for (var file in files) {
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        formData.files.add(MapEntry(
          'files',
          MultipartFile.fromBytes(bytes, filename: file.name),
        ));
      } else {
        formData.files.add(MapEntry(
          'files',
          await MultipartFile.fromFile(file.path, filename: file.name),
        ));
      }
    }

    final response = await _dio.post(
      '/api/vendor-mapping/upload-scans',
      data: formData,
      onSendProgress: onProgress,
    );
    return response.data;
  }

  Future<Map<String, dynamic>> processScans(List<String> fileKeys) async {
    final response =
        await _dio.post('/api/vendor-mapping/process-scans', data: {
      'file_keys': fileKeys,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getProcessStatus(String taskId) async {
    final response =
        await _dio.get('/api/vendor-mapping/process/status/$taskId');
    return response.data;
  }

  Future<Map<String, dynamic>> extractFromImage(String imageUrl) async {
    final response =
        await _dio.post('/api/vendor-mapping/extract', queryParameters: {
      'image_url': imageUrl,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getEntries({String? status}) async {
    final response =
        await _dio.get('/api/vendor-mapping/entries', queryParameters: {
      if (status != null) 'status': status,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> updateEntry(
      int entryId, Map<String, dynamic> updates) async {
    final response =
        await _dio.put('/api/vendor-mapping/entries/$entryId', data: updates);
    return response.data;
  }

  Future<void> deleteEntry(int entryId) async {
    await _dio.delete('/api/vendor-mapping/entries/$entryId');
  }

  Future<Map<String, dynamic>> bulkSaveEntries(List<VendorMappingEntry> entries,
      {String? sourceImageUrl}) async {
    final response =
        await _dio.post('/api/vendor-mapping/entries/bulk-save', data: {
      'entries': entries.map((e) => e.toJson()).toList(),
      if (sourceImageUrl != null) 'source_image_url': sourceImageUrl,
    });
    return response.data;
  }

  Future<List<String>> searchCustomerItems(String query) async {
    final response = await _dio
        .get('/api/vendor-mapping/customer-items/search', queryParameters: {
      'query': query,
    });
    return (response.data['items'] as List)
        .map((e) => e['customer_item'] as String)
        .toList();
  }
}
