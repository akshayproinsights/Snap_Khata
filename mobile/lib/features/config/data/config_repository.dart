import 'package:dio/dio.dart';
import 'package:mobile/core/network/api_client.dart';

class ConfigRepository {
  final Dio _dio;

  ConfigRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  Future<Map<String, dynamic>> getUserConfig() async {
    try {
      final response = await _dio.get('/api/config');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to load user config');
    }
  }
}
