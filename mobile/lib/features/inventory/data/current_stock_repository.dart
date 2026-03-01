import 'dart:io';
import 'package:dio/dio.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/inventory/domain/models/current_stock_models.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

class CurrentStockRepository {
  final Dio _dio;
  CurrentStockRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  Future<Map<String, dynamic>> getStockLevels({
    String? search,
    String? statusFilter,
    String? priorityFilter,
    int? limit,
    int? offset,
  }) async {
    final queryParams = <String, dynamic>{};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (statusFilter != null && statusFilter != 'all') {
      queryParams['status_filter'] = statusFilter;
    }
    if (priorityFilter != null && priorityFilter != 'all') {
      queryParams['priority_filter'] = priorityFilter;
    }
    if (limit != null) queryParams['limit'] = limit;
    if (offset != null) queryParams['offset'] = offset;
    queryParams['_t'] = DateTime.now().millisecondsSinceEpoch.toString();

    try {
      final response =
          await _dio.get('/api/stock/levels', queryParameters: queryParams);
      final cacheBox = Hive.box('stock_cache');
      cacheBox.put('stock_levels', response.data);

      final data = response.data;
      return {
        'items':
            (data['items'] as List).map((e) => StockLevel.fromJson(e)).toList(),
        'total': data['total'] ?? 0,
      };
    } catch (e) {
      final cacheBox = Hive.box('stock_cache');
      final cached = cacheBox.get('stock_levels');
      if (cached != null) {
        final data = Map<String, dynamic>.from(cached as Map);
        return {
          'items': (data['items'] as List)
              .map((e) =>
                  StockLevel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList(),
          'total': data['total'] ?? 0,
        };
      }
      throw Exception('Failed to fetch stock levels: $e');
    }
  }

  Future<StockSummary> getStockSummary() async {
    try {
      final response = await _dio.get('/api/stock/summary');
      final cacheBox = Hive.box('stock_cache');
      cacheBox.put('stock_summary', response.data);
      return StockSummary.fromJson(response.data['summary'] ?? response.data);
    } catch (e) {
      final cacheBox = Hive.box('stock_cache');
      final cached = cacheBox.get('stock_summary');
      if (cached != null) {
        final data = Map<String, dynamic>.from(cached as Map);
        return StockSummary.fromJson(data['summary'] ?? data);
      }
      throw Exception('Failed to fetch stock summary: $e');
    }
  }

  Future<void> updateStockLevel(int id, Map<String, dynamic> updates) async {
    await _dio.patch('/api/stock/levels/$id', data: updates);
  }

  Future<StockLevel> adjustStock(Map<String, dynamic> adjustment) async {
    final response = await _dio.post('/api/stock/adjust', data: adjustment);
    return StockLevel.fromJson(response.data);
  }

  Future<void> updateStockAdjustment(String partNumber, int physicalCount,
      {String? reason}) async {
    await _dio.post('/api/stock/update-stock-adjustment', data: {
      'part_number': partNumber,
      'physical_count': physicalCount,
      if (reason != null) 'reason': reason,
    });
  }

  Future<Map<String, dynamic>> calculateStockLevels() async {
    final response = await _dio.post('/api/stock/calculate');
    return response.data;
  }

  Future<Map<String, dynamic>> getRecalculationStatus(String taskId) async {
    final response = await _dio.get('/api/stock/calculate/status/$taskId');
    return response.data;
  }

  Future<Map<String, dynamic>> needsRecalculation() async {
    final response = await _dio.get('/api/stock/needs-recalculation');
    return response.data;
  }

  Future<Map<String, dynamic>> getStockHistory(String partNumber) async {
    final response =
        await _dio.get('/api/stock/history/${Uri.encodeComponent(partNumber)}');
    return response.data;
  }

  Future<void> updateStockTransaction({
    required String transactionId,
    required String type,
    required int quantity,
    double? rate,
  }) async {
    await _dio.put('/api/stock/transaction/$transactionId', data: {
      'type': type,
      'quantity': quantity,
      if (rate != null) 'rate': rate,
    });
  }

  Future<void> deleteStockTransaction({
    required String transactionId,
    required String type,
  }) async {
    await _dio
        .delete('/api/stock/transaction/$transactionId', data: {'type': type});
  }

  Future<void> deleteStockItem(String partNumber) async {
    await _dio.delete('/api/stock/item/${Uri.encodeComponent(partNumber)}');
  }

  Future<Map<String, dynamic>> deleteBulkStockItems(
      List<String> partNumbers) async {
    final response = await _dio.delete('/api/stock/items/bulk', data: {
      'part_numbers': partNumbers,
    });
    return response.data;
  }

  /// Export current stock levels as an Excel file.
  /// Returns the saved file path ready for sharing.
  Future<String> exportStockLevels({
    String? search,
    String? statusFilter,
    String? priorityFilter,
  }) async {
    final queryParams = <String, dynamic>{};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (statusFilter != null && statusFilter != 'all') {
      queryParams['status_filter'] = statusFilter;
    }
    if (priorityFilter != null && priorityFilter != 'all') {
      queryParams['priority_filter'] = priorityFilter;
    }

    final response = await _dio.get(
      '/api/stock/export',
      queryParameters: queryParams,
      options: Options(responseType: ResponseType.bytes),
    );

    final dir = await getTemporaryDirectory();
    final timestamp =
        DateTime.now().toIso8601String().replaceAll(RegExp(r'[:\.]'), '-');
    final filePath = '${dir.path}/stock_export_$timestamp.xlsx';
    final file = File(filePath);
    await file.writeAsBytes(response.data as List<int>);
    return filePath;
  }
}
