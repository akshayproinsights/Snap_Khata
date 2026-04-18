import 'package:dio/dio.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:flutter/foundation.dart';

class UsageRepository {
  final Dio dio;

  UsageRepository({Dio? dio}) : dio = dio ?? ApiClient().dio;

  Future<Map<String, dynamic>> getUsageStats() async {
    try {
      final response = await dio.get('/api/usage/stats');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error fetching usage stats: $e');
      throw Exception('Failed to load usage stats');
    }
  }
}
