import 'package:flutter_riverpod/legacy.dart';
import 'package:mobile/models/pagination_state.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/upload/domain/models/upload_models.dart';

/// Configuration for upload tasks pagination
class UploadPaginationConfig {
  final int pageSize;
  final String sortBy;
  final String sortDirection;
  final String? status;

  UploadPaginationConfig({
    this.pageSize = 15,
    this.sortBy = 'created_at',
    this.sortDirection = 'desc',
    this.status,
  });

  UploadPaginationConfig copyWith({
    int? pageSize,
    String? sortBy,
    String? sortDirection,
    String? status,
  }) {
    return UploadPaginationConfig(
      pageSize: pageSize ?? this.pageSize,
      sortBy: sortBy ?? this.sortBy,
      sortDirection: sortDirection ?? this.sortDirection,
      status: status ?? this.status,
    );
  }
}

/// Provider for paginated upload tasks
class PaginatedUploadNotifier
    extends StateNotifier<PaginationState<UploadTask>> {
  final ApiClient apiClient;
  UploadPaginationConfig config;

  PaginatedUploadNotifier({
    required this.apiClient,
    UploadPaginationConfig? initialConfig,
  })  : config = initialConfig ?? UploadPaginationConfig(),
        super(const PaginationState.initial()) {
    loadFirstPage();
  }

  /// Load the first page of upload tasks
  Future<void> loadFirstPage({UploadPaginationConfig? newConfig}) async {
    if (newConfig != null) {
      config = newConfig;
    }

    state = const PaginationState.loadingFirstPage();

    try {
      final queryParams = {
        'limit': config.pageSize.toString(),
        'sort_by': config.sortBy,
        'sort_direction': config.sortDirection,
        if (config.status != null) 'status': config.status,
      };

      final response = await apiClient.get(
        '/uploads/tasks',
        queryParameters: queryParams,
      );

      final tasks = (response.data['tasks'] as List<dynamic>)
          .map((task) => UploadTask.fromJson(task as Map<String, dynamic>))
          .toList();

      final hasNext = response.data['has_next'] as bool? ?? false;
      final nextCursor = response.data['next_cursor'] as String?;

      if (tasks.isEmpty) {
        state = const PaginationState.empty();
      } else {
        state = PaginationState.loaded(
          items: tasks,
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

  /// Load the next page of upload tasks
  Future<void> loadNextPage() async {
    if (!state.maybeWhen(
      loaded: (items, hasNext, _, __) => hasNext,
      orElse: () => false,
    )) {
      return;
    }

    final currentState = state as PaginationStateLoaded<UploadTask>;
    final nextCursor = currentState.nextCursor;

    if (nextCursor == null) return;

    state = PaginationState.loadingNextPage(previousItems: currentState.items);

    try {
      final queryParams = {
        'limit': config.pageSize.toString(),
        'cursor': nextCursor,
        'sort_by': config.sortBy,
        'sort_direction': config.sortDirection,
        if (config.status != null) 'status': config.status,
      };

      final response = await apiClient.get(
        '/uploads/tasks',
        queryParameters: queryParams,
      );

      final newTasks = (response.data['tasks'] as List<dynamic>)
          .map((task) => UploadTask.fromJson(task as Map<String, dynamic>))
          .toList();

      final hasNext = response.data['has_next'] as bool? ?? false;
      final nextCursorNew = response.data['next_cursor'] as String?;

      final allTasks = [...currentState.items, ...newTasks];

      state = PaginationState.loaded(
        items: allTasks,
        hasNext: hasNext,
        nextCursor: nextCursorNew,
        isLoadingMore: false,
      );
    } catch (e) {
      state = PaginationState.error(
        message: e.toString(),
        previousItems: currentState.items,
      );
    }
  }

  /// Refresh the first page
  Future<void> refresh({UploadPaginationConfig? newConfig}) async {
    await loadFirstPage(newConfig: newConfig);
  }
}

/// Riverpod provider for paginated uploads
final paginatedUploadProvider = StateNotifierProvider<
    PaginatedUploadNotifier,
    PaginationState<UploadTask>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PaginatedUploadNotifier(apiClient: apiClient);
});
