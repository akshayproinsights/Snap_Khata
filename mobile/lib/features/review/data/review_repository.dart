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

  Future<void> updateAmountsBulk(List<ReviewRecord> records) async {
    await _dio.put('/api/review/amounts/update-bulk', data: records.map((r) => r.toJson()).toList());
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
    // Use a relative path — Dio will prepend the baseUrl automatically.
    // CRITICAL: Set receiveTimeout to Duration.zero (no timeout) for SSE.
    // The default 30s receiveTimeout kills the connection before sync finishes.
    final sseUrl =
        '/api/review/sync-finish/stream?token=${Uri.encodeComponent(token)}';

    final response = await _dio.get<ResponseBody>(
      sseUrl,
      options: Options(
        responseType: ResponseType.stream,
        receiveTimeout: Duration.zero, // ← No timeout for long-running SSE
        headers: {
          'Accept': 'text/event-stream',
          'Cache-Control': 'no-cache',
        },
      ),
    );

    final stream = response.data?.stream;
    if (stream == null) return;

    String buffer = '';
    await for (final chunk in stream) {
      buffer += utf8.decode(chunk, allowMalformed: true);

      while (buffer.contains('\n\n')) {
        final index = buffer.indexOf('\n\n');
        final message = buffer.substring(0, index);
        buffer = buffer.substring(index + 2);

        final lines = message.split('\n');
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
}
