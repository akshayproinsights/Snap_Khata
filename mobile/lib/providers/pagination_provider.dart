import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:dio/dio.dart';
import 'dart:async';

import '../models/pagination_state.dart';

/// Base class for paginated data providers
/// This handles all the heavy lifting for pagination
abstract class PaginatedDataProvider<T> {
  /// Fetch items from API with pagination
  Future<Map<String, dynamic>> fetchPage(
    String endpoint,
    int limit,
    String? cursor,
    PaginationConfig config,
  );

  /// Parse API response into items
  List<T> parseItems(Map<String, dynamic> response);

  /// Get the Riverpod provider key
  String get key;
}

/// Implements paginated data provider
class PaginatedDataProviderImpl<T> extends PaginatedDataProvider<T> {
  final Dio dio;
  final String endpoint;
  final List<T> Function(Map<String, dynamic>) parseItemsFn;

  PaginatedDataProviderImpl({
    required this.dio,
    required this.endpoint,
    required this.parseItemsFn,
  });

  @override
  Future<Map<String, dynamic>> fetchPage(
    String endpoint,
    int limit,
    String? cursor,
    PaginationConfig config,
  ) async {
    try {
      final queryParams = {
        'limit': limit.toString(),
        'sort_by': config.sortBy,
        'sort_direction': config.sortDirection,
      };

      if (cursor != null && cursor.isNotEmpty) {
        queryParams['cursor'] = cursor;
      }

      if (config.searchQuery != null && config.searchQuery!.isNotEmpty) {
        queryParams['search'] = config.searchQuery!;
      }

      queryParams.addAll(
        config.filters.map((k, v) => MapEntry(k, v.toString())),
      );

      final response = await dio.get(
        endpoint,
        queryParameters: queryParams,
        options: Options(
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          message: 'Failed to load data',
          type: DioExceptionType.badResponse,
        );
      }
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    }
  }

  @override
  List<T> parseItems(Map<String, dynamic> response) {
    return parseItemsFn(response);
  }

  @override
  String get key => endpoint;
}

/// Generic paginated list state notifier
class PaginatedListNotifier<T> extends StateNotifier<PaginationState<T>> {
  final PaginatedDataProvider<T> dataProvider;
  final String endpoint;
  PaginationConfig config;

  PaginatedListNotifier({
    required this.dataProvider,
    required this.endpoint,
    PaginationConfig? initialConfig,
  })  : config = initialConfig ?? PaginationConfig.defaults(),
        super(const PaginationState.initial()) {
    // Auto-load first page
    loadFirstPage();
  }

  /// Load the first page of results
  Future<void> loadFirstPage({PaginationConfig? newConfig}) async {
    if (newConfig != null) {
      config = newConfig;
    }

    state = const PaginationState.loadingFirstPage();

    try {
      final response = await dataProvider.fetchPage(
        endpoint,
        config.pageSize,
        null,
        config,
      );

      final items = dataProvider.parseItems(response);
      final hasNext = response['has_next'] as bool? ?? false;
      final nextCursor = response['next_cursor'] as String?;

      if (items.isEmpty) {
        state = const PaginationState.empty();
      } else {
        state = PaginationState.loaded(
          items: items,
          hasNext: hasNext,
          nextCursor: nextCursor,
          isLoadingMore: false,
        );
      }
    } catch (e) {
      state = PaginationState.error(
        message: e.toString(),
        previousItems: [],
      );
    }
  }

  /// Load the next page of results
  Future<void> loadNextPage() async {
    state.whenOrNull(
      loaded: (items, hasNext, nextCursor, _) {
        if (!hasNext || nextCursor == null) {
          return; // No more pages
        }

        _performLoadNextPage(items, nextCursor);
      },
    );
  }

  Future<void> _performLoadNextPage(
    List<T> currentItems,
    String? nextCursor,
  ) async {
    state = PaginationState.loadingNextPage(previousItems: currentItems);

    try {
      final response = await dataProvider.fetchPage(
        endpoint,
        config.pageSize,
        nextCursor,
        config,
      );

      final newItems = dataProvider.parseItems(response);
      final allItems = [...currentItems, ...newItems];
      final hasNext = response['has_next'] as bool? ?? false;
      final newNextCursor = response['next_cursor'] as String?;

      state = PaginationState.loaded(
        items: allItems,
        hasNext: hasNext,
        nextCursor: newNextCursor,
        isLoadingMore: false,
      );
    } catch (e) {
      state = PaginationState.error(
        message: e.toString(),
        previousItems: currentItems,
      );
    }
  }

  /// Refresh the first page (pull-to-refresh)
  Future<void> refresh() async {
    await loadFirstPage();
  }

  /// Update pagination configuration and reload
  Future<void> updateConfig(PaginationConfig newConfig) async {
    config = newConfig;
    await loadFirstPage();
  }

  /// Reset to initial state
  void reset() {
    state = const PaginationState.initial();
    loadFirstPage();
  }
}

/// Provider factory for creating paginated list providers
class PaginatedListProviderFactory {
  /// Create a paginated list provider for inventory items
  static final inventoryItemsProvider =
      StateNotifierProvider.autoDispose.family<
          PaginatedListNotifier<dynamic>,
          PaginationState<dynamic>,
          PaginationConfig>((ref, config) {
    final dio = ref.watch(dioProvider);

    final dataProvider = PaginatedDataProviderImpl(
      dio: dio,
      endpoint: '/api/inventory/items',
      parseItemsFn: (response) {
        final list = response['data'] as List? ?? [];
        return list
            .cast<Map<String, dynamic>>()
            .map((item) => InventoryItemDTO.fromJson(item))
            .toList();
      },
    );

    return PaginatedListNotifier(
      dataProvider: dataProvider,
      endpoint: '/api/inventory/items',
      initialConfig: config,
    );
  });

  /// Create a paginated list provider for khata parties
  static final khataPartiesProvider =
      StateNotifierProvider.autoDispose.family<
          PaginatedListNotifier<dynamic>,
          PaginationState<dynamic>,
          PaginationConfig>((ref, config) {
    final dio = ref.watch(dioProvider);

    final dataProvider = PaginatedDataProviderImpl(
      dio: dio,
      endpoint: '/api/khata/parties',
      parseItemsFn: (response) {
        final list = response['data'] as List? ?? [];
        return list
            .cast<Map<String, dynamic>>()
            .map((item) => KhataPartyDTO.fromJson(item))
            .toList();
      },
    );

    return PaginatedListNotifier(
      dataProvider: dataProvider,
      endpoint: '/api/khata/parties',
      initialConfig: config,
    );
  });

  /// Create a paginated list provider for party transactions
  static final partyTransactionsProvider =
      StateNotifierProvider.autoDispose.family<
          PaginatedListNotifier<dynamic>,
          PaginationState<dynamic>,
          ({int ledgerId, PaginationConfig config})>((ref, params) {
    final dio = ref.watch(dioProvider);
    final ledgerId = params.ledgerId;
    final config = params.config;

    final dataProvider = PaginatedDataProviderImpl(
      dio: dio,
      endpoint: '/api/khata/ledgers/$ledgerId/transactions',
      parseItemsFn: (response) {
        final list = response['data'] as List? ?? [];
        return list
            .cast<Map<String, dynamic>>()
            .map((item) => TransactionDTO.fromJson(item))
            .toList();
      },
    );

    return PaginatedListNotifier(
      dataProvider: dataProvider,
      endpoint: '/api/khata/ledgers/$ledgerId/transactions',
      initialConfig: config,
    );
  });

  /// Create a paginated list provider for upload tasks
  static final uploadTasksProvider =
      StateNotifierProvider.autoDispose.family<
          PaginatedListNotifier<dynamic>,
          PaginationState<dynamic>,
          PaginationConfig>((ref, config) {
    final dio = ref.watch(dioProvider);

    final dataProvider = PaginatedDataProviderImpl(
      dio: dio,
      endpoint: '/api/uploads/tasks',
      parseItemsFn: (response) {
        final list = response['data'] as List? ?? [];
        return list
            .cast<Map<String, dynamic>>()
            .map((item) => UploadTaskDTO.fromJson(item))
            .toList();
      },
    );

    return PaginatedListNotifier(
      dataProvider: dataProvider,
      endpoint: '/api/uploads/tasks',
      initialConfig: config,
    );
  });
}

// DTOs that need to be defined separately
class InventoryItemDTO {
  final String id;
  final String invoiceNumber;
  final String vendorName;
  final String invoiceDate;
  final int quantity;
  final double rate;
  final double lineTotal;
  final String? hsnCode;
  final String productName;

  InventoryItemDTO({
    required this.id,
    required this.invoiceNumber,
    required this.vendorName,
    required this.invoiceDate,
    required this.quantity,
    required this.rate,
    required this.lineTotal,
    required this.hsnCode,
    required this.productName,
  });

  factory InventoryItemDTO.fromJson(Map<String, dynamic> json) {
    return InventoryItemDTO(
      id: json['id'] as String? ?? '',
      invoiceNumber: json['invoice_number'] as String? ?? '',
      vendorName: json['vendor_name'] as String? ?? '',
      invoiceDate: json['invoice_date'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 0,
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      lineTotal: (json['line_total'] as num?)?.toDouble() ?? 0.0,
      hsnCode: json['hsn_code'] as String?,
      productName: json['product_name'] as String? ?? '',
    );
  }
}

class KhataPartyDTO {
  final String id;
  final String customerName;
  final double balanceDue;
  final double totalDue;
  final String updatedAt;

  KhataPartyDTO({
    required this.id,
    required this.customerName,
    required this.balanceDue,
    required this.totalDue,
    required this.updatedAt,
  });

  factory KhataPartyDTO.fromJson(Map<String, dynamic> json) {
    return KhataPartyDTO(
      id: json['id'] as String? ?? '',
      customerName: json['customer_name'] as String? ?? '',
      balanceDue: (json['balance_due'] as num?)?.toDouble() ?? 0.0,
      totalDue: (json['total_due'] as num?)?.toDouble() ?? 0.0,
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }
}

class TransactionDTO {
  final String id;
  final String transactionDate;
  final String transactionType;
  final double amount;
  final String? receiptNumber;
  final String? notes;
  final String createdAt;

  TransactionDTO({
    required this.id,
    required this.transactionDate,
    required this.transactionType,
    required this.amount,
    required this.receiptNumber,
    required this.notes,
    required this.createdAt,
  });

  factory TransactionDTO.fromJson(Map<String, dynamic> json) {
    return TransactionDTO(
      id: json['id'] as String? ?? '',
      transactionDate: json['transaction_date'] as String? ?? '',
      transactionType: json['transaction_type'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      receiptNumber: json['receipt_number'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class UploadTaskDTO {
  final String id;
  final String status;
  final String createdAt;
  final int fileCount;
  final int processedCount;
  final int errorCount;
  final String message;

  UploadTaskDTO({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.fileCount,
    required this.processedCount,
    required this.errorCount,
    required this.message,
  });

  factory UploadTaskDTO.fromJson(Map<String, dynamic> json) {
    return UploadTaskDTO(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      fileCount: json['file_count'] as int? ?? 0,
      processedCount: json['processed_count'] as int? ?? 0,
      errorCount: json['error_count'] as int? ?? 0,
      message: json['message'] as String? ?? '',
    );
  }
}

// Import for Dio provider (assuming it exists)
final dioProvider = Provider((ref) {
  // Return your Dio instance here
  return Dio(BaseOptions(
    baseUrl: 'https://api.snapkhata.com',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));
});
