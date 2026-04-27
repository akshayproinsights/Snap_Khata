import 'package:freezed_annotation/freezed_annotation.dart';

part 'pagination_state.freezed.dart';

/// Immutable pagination cursor state
@freezed
// ignore: non_abstract_class_inherits_abstract_member
class PaginationCursor with _$PaginationCursor {
  const factory PaginationCursor({
    required String lastId,
    required dynamic lastValue,
    required String direction,
  }) = _PaginationCursor;
}

/// Immutable paginated response wrapper
@freezed
// ignore: non_abstract_class_inherits_abstract_member
class PaginatedData<T> with _$PaginatedData<T> {
  const PaginatedData._();

  const factory PaginatedData({
    required List<T> data,
    required int totalCount,
    required bool hasNext,
    required bool hasPrevious,
    required String? nextCursor,
    required String? previousCursor,
    required Map<String, dynamic> pageInfo,
  }) = _PaginatedData<T>;

  factory PaginatedData.empty() => const PaginatedData(
    data: [],
    totalCount: 0,
    hasNext: false,
    hasPrevious: false,
    nextCursor: null,
    previousCursor: null,
    pageInfo: {},
  );
}

/// Enhanced pagination state with loading/error handling
@freezed
class PaginationState<T> with _$PaginationState<T> {
  const PaginationState._();

  const factory PaginationState.initial() = PaginationStateInitial<T>;
  const factory PaginationState.loadingFirstPage() = PaginationStateLoadingFirstPage<T>;
  const factory PaginationState.loadingNextPage({
    required List<T> previousItems,
  }) = PaginationStateLoadingNextPage<T>;
  const factory PaginationState.loaded({
    required List<T> items,
    required bool hasNext,
    required String? nextCursor,
    required bool isLoadingMore,
  }) = PaginationStateLoaded<T>;
  const factory PaginationState.error({
    required String message,
    required List<T> previousItems,
  }) = PaginationStateError<T>;
  const factory PaginationState.empty() = PaginationStateEmpty<T>;

  /// Current displayed items
  List<T> get items {
    return when(
      initial: () => [],
      loadingFirstPage: () => [],
      loadingNextPage: (previousItems) => previousItems,
      loaded: (items, _, __, ___) => items,
      error: (_, previousItems) => previousItems,
      empty: () => [],
    );
  }

  bool get isLoading {
    return when(
      initial: () => false,
      loadingFirstPage: () => true,
      loadingNextPage: (_) => true,
      loaded: (_, _, __, isLoadingMore) => isLoadingMore,
      error: (_, __) => false,
      empty: () => false,
    );
  }

  bool get hasError {
    return maybeWhen(
      error: (_, __) => true,
      orElse: () => false,
    );
  }

  String? get errorMessage {
    return maybeWhen(
      error: (message, _) => message,
      orElse: () => null,
    );
  }
}

/// Configuration for pagination parameters
@freezed
// ignore: non_abstract_class_inherits_abstract_member
class PaginationConfig with _$PaginationConfig {
  const PaginationConfig._();

  const factory PaginationConfig({
    required int pageSize,
    required String sortBy,
    required String sortDirection,
    required String? searchQuery,
    required Map<String, dynamic> filters,
  }) = _PaginationConfig;

  factory PaginationConfig.defaults() => const PaginationConfig(
    pageSize: 20,
    sortBy: 'created_at',
    sortDirection: 'desc',
    searchQuery: null,
    filters: {},
  );
}

/// Statistics for monitoring pagination performance
@freezed
// ignore: non_abstract_class_inherits_abstract_member
class PaginationStats with _$PaginationStats {
  const factory PaginationStats({
    required int totalItemsLoaded,
    required int pageCount,
    required Duration loadTime,
    required String lastLoadedAt,
  }) = _PaginationStats;

  factory PaginationStats.initial() => PaginationStats(
    totalItemsLoaded: 0,
    pageCount: 0,
    loadTime: Duration.zero,
    lastLoadedAt: '',
  );
}

