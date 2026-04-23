import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/network/sync_queue_service.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;

  // Uses PC's LAN IP for physical device testing.
  // For emulator/simulator use 'http://10.0.2.2:8000' (Android) or 'http://127.0.0.1:8000' (iOS sim).
  // For production, set to your deployed API URL.
  static final String _defaultBaseUrl = 'https://mydigientry.com';
  
  // Callback for unauthorized access (401)
  static VoidCallback? onUnauthorized;

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: _defaultBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120),
      sendTimeout: const Duration(seconds: 120),
      headers: {
        'Accept': 'application/json',
      },
    ));

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('auth_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            // Handle token expiration/unauthorized access globally
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('auth_token');
            // Trigger global unauthorized callback if registered
            if (onUnauthorized != null) {
              onUnauthorized!();
            }
          } else if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.unknown) {
            final method = e.requestOptions.method.toUpperCase();
            final isRetry =
                e.requestOptions.headers['x-offline-retry'] == 'true';
            // Skip offline queueing for multipart/form-data (file uploads).
            // FormData cannot be serialized to Hive, and upload_provider.dart
            // already handles its own offline queueing for file uploads.
            final contentType =
                e.requestOptions.headers['content-type']?.toString() ?? '';
            final isMultipart = e.requestOptions.data is FormData ||
                contentType.contains('multipart/form-data');

            if (!isRetry &&
                !isMultipart &&
                (method == 'POST' ||
                    method == 'PUT' ||
                    method == 'DELETE' ||
                    method == 'PATCH')) {
              try {
                // Determine the relative path without the base URL
                final baseUrl = e.requestOptions.baseUrl;
                var path = e.requestOptions.uri.toString();
                if (path.startsWith(baseUrl)) {
                  path = path.substring(baseUrl.length);
                } else {
                  path = e.requestOptions.path;
                }

                await SyncQueueService().queueRequest(
                  method,
                  path,
                  data: e.requestOptions.data,
                  queryParameters: e.requestOptions.queryParameters,
                );
                debugPrint('Offline mutation queued: $method $path');

                // Resolve the error so the UI doesn't crash, enabling Optimistic UI
                return handler.resolve(Response(
                  requestOptions: e.requestOptions,
                  statusCode: 200,
                  data: {
                    'status': 'queued_offline',
                    'message':
                        'Action saved offline and will sync when connected.'
                  },
                ));
              } catch (queueError) {
                debugPrint('Failed to queue offline mutation: $queueError');
              }
            } else {
              debugPrint('Network timeout/error: ${e.message}');
            }
          } else {
            debugPrint('API Error [${e.response?.statusCode}]: ${e.message}');
            if (e.response?.data != null) {
              debugPrint('Error detail: ${e.response?.data}');
            }
          }
          return handler.next(e);
        },
      ),
    );

    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => debugPrint(obj.toString()),
      ));
    }
  }
}
