import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/features/upload/data/upload_repository.dart';
import 'package:mobile/features/inventory/data/inventory_upload_repository.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/sync_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:workmanager/workmanager.dart';

class SyncQueueService {
  static final SyncQueueService _instance = SyncQueueService._internal();
  factory SyncQueueService() => _instance;
  SyncQueueService._internal();

  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final UploadRepository _uploadRepository = UploadRepository();
  final InventoryUploadRepository _inventoryUploadRepository = InventoryUploadRepository();
  static ProviderContainer? _container;

  static void setContainer(ProviderContainer container) {
    _container = container;
  }

  bool _isProcessing = false;

  void init() {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      if (results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.wifi)) {
        processQueue();
      }
    });
  }

  void dispose() {
    _subscription?.cancel();
  }

  Future<void> queueUpload(List<String> filePaths, {String queueType = 'sales'}) async {
    final box = Hive.box('sync_queue');
    await box.add({
      'type': 'upload_invoices',
      'paths': filePaths,
      'queue_type': queueType,
      'timestamp': DateTime.now().toIso8601String(),
    });

    final results = await _connectivity.checkConnectivity();
    if (results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.wifi)) {
      processQueue();
    } else {
      // If offline, register a background task to sync when network returns
      if (!kIsWeb) {
        Workmanager().registerOneOffTask(
          'sync-upload-${DateTime.now().millisecondsSinceEpoch}',
          'syncDataTask',
          constraints: Constraints(networkType: NetworkType.connected),
        );
      }
    }
  }

  Future<void> queueRequest(String method, String url,
      {dynamic data, Map<String, dynamic>? queryParameters}) async {
    final box = Hive.box('sync_queue');
    // Sanitize data recursively if it contains custom objects, though Dio usually expects JSON maps.
    await box.add({
      'type': 'api_request',
      'method': method,
      'url': url,
      'data': data,
      'queryParameters': queryParameters,
      'timestamp': DateTime.now().toIso8601String(),
    });

    final results = await _connectivity.checkConnectivity();
    if (results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.wifi)) {
      processQueue();
    } else {
      // Register background sync task
      if (!kIsWeb) {
        Workmanager().registerOneOffTask(
          'sync-api-${DateTime.now().millisecondsSinceEpoch}',
          'syncDataTask',
          constraints: Constraints(networkType: NetworkType.connected),
        );
      }
    }
  }

  Future<void> processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;
    _container?.read(syncProvider.notifier).setSyncing(true);

    final box = Hive.box('sync_queue');

    // We iterate backwards to safely remove items while looping
    final keys = box.keys.toList();
    for (var key in keys) {
      final item = box.get(key) as Map;

      try {
        if (item['type'] == 'upload_invoices') {
          final paths = List<String>.from(item['paths'] as List);
          final xFiles = paths.map((path) => XFile(path)).toList();
          final queueType = item['queue_type'] as String? ?? 'sales';

          if (queueType == 'inventory') {
            final uploadedKeys = await _inventoryUploadRepository.uploadFiles(xFiles);
            await _inventoryUploadRepository.processInvoices(uploadedKeys);
          } else {
            final uploadedKeys = await _uploadRepository.uploadFiles(xFiles);
            await _uploadRepository.processInvoices(uploadedKeys);
          }

          // Successful, remove from queue
          await box.delete(key);
        } else if (item['type'] == 'api_request') {
          final dio = ApiClient().dio;
          final method = item['method'] as String;
          final url = item['url'] as String;
          final data = item['data'];

          Map<String, dynamic>? queryParams;
          if (item['queryParameters'] != null) {
            queryParams = Map<String, dynamic>.from(item['queryParameters']);
          }

          Response? response;
          final options = Options(headers: {'x-offline-retry': 'true'});
          switch (method.toUpperCase()) {
            case 'POST':
              response = await dio.post(url,
                  data: data, queryParameters: queryParams, options: options);
              break;
            case 'PUT':
              response = await dio.put(url,
                  data: data, queryParameters: queryParams, options: options);
              break;
            case 'DELETE':
              response = await dio.delete(url,
                  data: data, queryParameters: queryParams, options: options);
              break;
            case 'PATCH':
              response = await dio.patch(url,
                  data: data, queryParameters: queryParams, options: options);
              break;
            default:
              debugPrint('Unsupported offline request method: $method');
          }

          if (response != null &&
              response.statusCode != null &&
              response.statusCode! >= 200 &&
              response.statusCode! < 300) {
            await box.delete(key);
          } else if (response != null &&
              response.statusCode != null &&
              response.statusCode! >= 400 &&
              response.statusCode! < 500) {
            // Unrecoverable client error, remove from queue to avoid infinite loops
            await box.delete(key);
            debugPrint(
                'Discarded offline task due to client error: ${response.statusCode}');
          }
        }
      } catch (e) {
        // Failed, leave in queue to retry later
        debugPrint('Failed to process offline task: $e');
      }
    }

    _isProcessing = false;
    _container?.read(syncProvider.notifier).setSyncing(false);
  }
}
