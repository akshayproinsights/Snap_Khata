import 'package:dio/dio.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/domain/models/user_model.dart';

class AuthRepository {
  final Dio _dio;

  AuthRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await _dio.post('/api/auth/login', data: {
        'username': username,
        'password': password,
      });
      return response.data;
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map<String, dynamic> && data['detail'] != null) {
          throw Exception(data['detail']);
        } else if (data is String) {
          throw Exception(
              'Server error: API endpoint returned incorrect format. Please verify the backend URL.');
        }
        throw Exception('Login failed. Please check your credentials.');
      }
      throw Exception('Network error during login');
    }
  }

  Future<User> getMe() async {
    try {
      final response = await _dio.get('/api/auth/me');
      return User.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to fetch user data');
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post('/api/auth/logout');
    } catch (e) {
      // Ignore errors on logout as token will be cleared locally anyway
    }
  }

  Future<List<Map<String, dynamic>>> getIndustries() async {
    try {
      final response = await _dio.get('/api/auth/industries');
      final industriesList = response.data['industries'] as List;
      return industriesList.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      throw Exception('Failed to fetch industries: $e');
    }
  }

  Future<Map<String, dynamic>> register(
      String username, String password, String shopName, String selectedIndustry) async {
    try {
      final response = await _dio.post('/api/auth/register', data: {
        'username': username,
        'password': password,
        'shop_name': shopName,
        'industry': selectedIndustry,
      });
      return response.data;
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map<String, dynamic> && data['detail'] != null) {
          throw Exception(data['detail']);
        }
      }
      throw Exception('Registration failed. Please try again.');
    }
  }
}
