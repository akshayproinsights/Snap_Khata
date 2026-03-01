import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/review/domain/models/review_models.dart';

class ReviewRepository {
  final Dio _dio;

  ReviewRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  Future<List<ReviewRecord>> fetchDates() async {
    final response = await _dio.get('/api/review/dates');
    final records = response.data['records'] as List?;
    return (records ?? [])
        .map((json) => ReviewRecord.fromJson(json, isHeaderType: true))
        .toList();
  }

  Future<List<ReviewRecord>> fetchAmounts() async {
    final response = await _dio.get('/api/review/amounts');
    final records = response.data['records'] as List?;
    return (records ?? [])
        .map((json) => ReviewRecord.fromJson(json, isHeaderType: false))
        .toList();
  }

  Future<void> updateSingleDate(ReviewRecord record) async {
    await _dio.put('/api/review/dates/update', data: record.toJson());
  }

  Future<void> updateSingleAmount(ReviewRecord record) async {
    await _dio.put('/api/review/amounts/update', data: record.toJson());
  }

  Future<void> deleteReceipt(String receiptNumber) async {
    await _dio.delete('/api/review/receipt/$receiptNumber');
  }

  Future<void> deleteRecord(String rowId) async {
    await _dio.delete('/api/review/record/$rowId');
  }

  Future<void> saveDates(List<dynamic> records) async {
    await _dio.put('/api/review/dates', data: {'records': records});
  }

  Future<void> saveAmounts(List<dynamic> records) async {
    await _dio.put('/api/review/amounts', data: {'records': records});
  }

  Future<void> syncAndFinish() async {
    await _dio.post('/api/review/sync-finish');
  }

  // Handle SSE Server-Sent Events roughly mapping to frontend syncAndFinishWithProgress
  Stream<Map<String, dynamic>> syncAndFinishWithProgress(String token) async* {
    final baseURL = _dio.options.baseUrl.endsWith('/')
        ? _dio.options.baseUrl.substring(0, _dio.options.baseUrl.length - 1)
        : _dio.options.baseUrl;

    final url =
        '$baseURL/api/review/sync-finish/stream?token=${Uri.encodeComponent(token)}';

    final response = await _dio.get<ResponseBody>(
      url,
      options: Options(responseType: ResponseType.stream),
    );

    final stream = response.data?.stream;
    if (stream == null) return;

    await for (final chunk in stream) {
      final decoded = utf8.decode(chunk);
      // Basic SSE parser
      final lines = decoded.split('\n');
      for (final line in lines) {
        if (line.startsWith('data: ')) {
          try {
            final jsonStr = line.substring(6);
            yield jsonDecode(jsonStr);
          } catch (_) {}
        }
      }
    }
  }
}
