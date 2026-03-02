import 'package:dio/dio.dart';
import 'package:cross_file/cross_file.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/upload/domain/models/upload_models.dart';

class UploadRepository {
  final Dio _dio;

  UploadRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  // 1. Upload files to get temporary S3/R2 keys
  Future<List<String>> uploadFiles(List<XFile> files,
      {Function(int, int)? onProgress}) async {
    try {
      final formData = FormData();

      for (var file in files) {
        formData.files.add(MapEntry(
          'files',
          await MultipartFile.fromFile(file.path, filename: file.name),
        ));
      }

      final response = await _dio.post(
        '/api/upload/files',
        data: formData,
        onSendProgress: onProgress,
      );

      return List<String>.from(response.data['uploaded_files'] ?? []);
    } catch (e) {
      throw Exception('Failed to upload files: $e');
    }
  }

  // 2. Start asynchronous processing for uploaded keys
  Future<UploadTaskStatus> processInvoices(List<String> fileKeys,
      {bool forceUpload = false}) async {
    try {
      final response = await _dio.post(
        '/api/upload/process-files',
        data: {
          'file_keys': fileKeys,
          'force_upload': forceUpload,
        },
      );
      return UploadTaskStatus.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to start processing: $e');
    }
  }

  // 3. Poll for status
  Future<UploadTaskStatus> getProcessStatus(String taskId) async {
    try {
      final response = await _dio.get('/api/upload/process/status/$taskId');
      return UploadTaskStatus.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to fetch processing status: $e');
    }
  }

  Future<Map<String, dynamic>> getRecentTask() async {
    try {
      final response = await _dio.get('/api/upload/recent-task');
      return response.data;
    } catch (e) {
      throw Exception('Failed to fetch recent task: $e');
    }
  }

  Future<String> getFileUrl(String fileKey) async {
    try {
      final response = await _dio
          .get('/upload/file-url', queryParameters: {'file_key': fileKey});
      return response.data['url'];
    } catch (e) {
      throw Exception('Failed to get file URL: $e');
    }
  }

  Future<Map<String, dynamic>> getUploadHistory() async {
    try {
      final response = await _dio.get('/api/upload/upload-history');
      return response.data;
    } catch (e) {
      throw Exception('Failed to fetch upload history: $e');
    }
  }

  Future<void> deleteHistoryBatch(List<String> receiptNumbers) async {
    try {
      await _dio.post(
        '/api/upload/history/delete-batch',
        data: {'receipt_numbers': receiptNumbers},
      );
    } catch (e) {
      throw Exception('Failed to delete history batch: $e');
    }
  }
}
