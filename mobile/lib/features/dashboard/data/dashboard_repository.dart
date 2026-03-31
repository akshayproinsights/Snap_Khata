import 'package:dio/dio.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/dashboard/domain/models/dashboard_models.dart';
import 'package:hive_flutter/hive_flutter.dart';

class DashboardRepository {
  final Dio _dio;

  DashboardRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  Future<DashboardKPIs> getKPIs({
    String? dateFrom,
    String? dateTo,
    Map<String, String>? filters,
  }) async {
    final Map<String, dynamic> queryParams = {};
    if (dateFrom != null) queryParams['date_from'] = dateFrom;
    if (dateTo != null) queryParams['date_to'] = dateTo;
    
    if (filters != null) {
      queryParams.addAll(filters);
    }

    try {
      final response = await _dio.get(
        '/api/dashboard/kpis',
        queryParameters: queryParams,
      );
      final cacheBox = Hive.box('dashboard_cache');
      cacheBox.put('kpis', response.data);
      return DashboardKPIs.fromJson(response.data);
    } catch (e) {
      final cacheBox = Hive.box('dashboard_cache');
      final cached = cacheBox.get('kpis');
      if (cached != null) {
        return DashboardKPIs.fromJson(Map<String, dynamic>.from(cached as Map));
      }
      throw Exception('Failed to fetch KPIs: $e');
    }
  }

  Future<RevenueSummary> getRevenueSummary({
    String? dateFrom,
    String? dateTo,
  }) async {
    final Map<String, dynamic> queryParams = {};
    if (dateFrom != null) queryParams['date_from'] = dateFrom;
    if (dateTo != null) queryParams['date_to'] = dateTo;

    try {
      final response = await _dio.get(
        '/api/dashboard/revenue-summary',
        queryParameters: queryParams,
      );
      final cacheBox = Hive.box('dashboard_cache');
      cacheBox.put('revenue_summary', response.data);
      return RevenueSummary.fromJson(
          Map<String, dynamic>.from(response.data as Map));
    } catch (e) {
      final cacheBox = Hive.box('dashboard_cache');
      final cached = cacheBox.get('revenue_summary');
      if (cached != null) {
        return RevenueSummary.fromJson(
            Map<String, dynamic>.from(cached as Map));
      }
      return RevenueSummary.empty();
    }
  }

  Future<StockSummary> getStockSummary() async {
    try {
      final response = await _dio.get('/api/dashboard/stock-summary');
      final cacheBox = Hive.box('dashboard_cache');
      cacheBox.put('stock_summary', response.data);
      return StockSummary.fromJson(response.data);
    } catch (e) {
      final cacheBox = Hive.box('dashboard_cache');
      final cached = cacheBox.get('stock_summary');
      if (cached != null) {
        return StockSummary.fromJson(Map<String, dynamic>.from(cached as Map));
      }
      throw Exception('Failed to fetch stock summary: $e');
    }
  }

  // Fallback for missing items from stock levels API similar to React
  Future<Map<String, dynamic>> getStockLevels({
    int? limit,
    int? offset,
    String? search,
  }) async {
    final Map<String, dynamic> queryParams = {};
    if (limit != null) queryParams['limit'] = limit;
    if (offset != null) queryParams['offset'] = offset;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    try {
      final response = await _dio.get(
        '/api/stock/levels',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      // Only cache if it's the default full fetch without pagination to not overwrite default cache
      if (limit == null && search == null) {
        final cacheBox = Hive.box('dashboard_cache');
        cacheBox.put('stock_levels', response.data);
      }
      return response.data;
    } catch (e) {
      if (limit == null && search == null) {
        final cacheBox = Hive.box('dashboard_cache');
        final cached = cacheBox.get('stock_levels');
        if (cached != null) {
          return Map<String, dynamic>.from(cached as Map);
        }
      }
      throw Exception('Failed to fetch stock levels: $e');
    }
  }

  Future<List<DailySalesVolume>> getDailySalesVolume({
    String? dateFrom,
    String? dateTo,
    Map<String, String>? filters,
  }) async {
    final Map<String, dynamic> queryParams = {};
    if (dateFrom != null) queryParams['date_from'] = dateFrom;
    if (dateTo != null) queryParams['date_to'] = dateTo;
    
    if (filters != null) {
      queryParams.addAll(filters);
    }

    try {
      final response = await _dio.get(
        '/api/dashboard/daily-sales-volume',
        queryParameters: queryParams,
      );
      final cacheBox = Hive.box('dashboard_cache');
      cacheBox.put('daily_sales', response.data);
      return (response.data as List)
          .map((json) => DailySalesVolume.fromJson(json))
          .toList();
    } catch (e) {
      final cacheBox = Hive.box('dashboard_cache');
      final cached = cacheBox.get('daily_sales');
      if (cached != null) {
        return (cached as List)
            .map((json) => DailySalesVolume.fromJson(
                Map<String, dynamic>.from(json as Map)))
            .toList();
      }
      throw Exception('Failed to fetch daily sales volume: $e');
    }
  }

  Future<List<StockAlert>> getStockAlerts({int limit = 10}) async {
    try {
      final response = await _dio.get(
        '/api/dashboard/stock-alerts',
        queryParameters: {'limit': limit},
      );
      final cacheBox = Hive.box('dashboard_cache');
      cacheBox.put('stock_alerts', response.data);
      return (response.data as List)
          .map((json) => StockAlert.fromJson(json))
          .toList();
    } catch (e) {
      // Try cache on failure
      final cacheBox = Hive.box('dashboard_cache');
      final cached = cacheBox.get('stock_alerts');
      if (cached != null) {
        return (cached as List)
            .map((json) =>
                StockAlert.fromJson(Map<String, dynamic>.from(json as Map)))
            .toList();
      }
      // Return empty list gracefully — stock alerts are non-critical
      return [];
    }
  }
}
