import 'package:flutter_riverpod/legacy.dart';
import 'package:mobile/models/pagination_state.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/udhar/domain/models/unified_party.dart';

/// Configuration for khata pagination
class KhataPaginationConfig {
  final int pageSize;
  final String sortBy;
  final String sortDirection;
  final String? searchQuery;
  final Map<String, dynamic> filters;

  KhataPaginationConfig({
    this.pageSize = 20,
    this.sortBy = 'updated_at',
    this.sortDirection = 'desc',
    this.searchQuery,
    this.filters = const {},
  });

  KhataPaginationConfig copyWith({
    int? pageSize,
    String? sortBy,
    String? sortDirection,
    String? searchQuery,
    Map<String, dynamic>? filters,
  }) {
    return KhataPaginationConfig(
      pageSize: pageSize ?? this.pageSize,
      sortBy: sortBy ?? this.sortBy,
      sortDirection: sortDirection ?? this.sortDirection,
      searchQuery: searchQuery ?? this.searchQuery,
      filters: filters ?? this.filters,
    );
  }
}

/// Provider for paginated khata parties
class PaginatedKhataNotifier
    extends StateNotifier<PaginationState<UnifiedParty>> {
  final ApiClient apiClient;
  KhataPaginationConfig config;

  PaginatedKhataNotifier({
    required this.apiClient,
    KhataPaginationConfig? initialConfig,
  })  : config = initialConfig ?? KhataPaginationConfig(),
        super(const PaginationState.initial()) {
    loadFirstPage();
  }

  /// Load the first page of khata parties
  Future<void> loadFirstPage({KhataPaginationConfig? newConfig}) async {
    if (newConfig != null) {
      config = newConfig;
    }

    state = const PaginationState.loadingFirstPage();

    try {
      final Map<String, dynamic> queryParams = <String, dynamic>{
        'limit': config.pageSize.toString(),
        'sort_by': config.sortBy,
        'sort_direction': config.sortDirection,
        if (config.searchQuery != null) 'search': config.searchQuery,
      };

      queryParams.addAll(config.filters);

      final response = await apiClient.get(
        '/khata/parties',
        queryParameters: queryParams,
      );

      final parties = (response.data['parties'] as List<dynamic>)
          .map((party) => UnifiedParty.fromJson(party as Map<String, dynamic>))
          .toList();

      final hasNext = response.data['has_next'] as bool? ?? false;
      final nextCursor = response.data['next_cursor'] as String?;

      if (parties.isEmpty) {
        state = const PaginationState.empty();
      } else {
        state = PaginationState.loaded(
          items: parties,
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

  /// Load the next page of khata parties
  Future<void> loadNextPage() async {
    if (!state.maybeWhen(
      loaded: (items, hasNext, _, __) => hasNext,
      orElse: () => false,
    )) {
      return;
    }

    final currentState = state as PaginationStateLoaded<UnifiedParty>;
    final nextCursor = currentState.nextCursor;

    if (nextCursor == null) return;

    state = PaginationState.loadingNextPage(previousItems: currentState.items);

    try {
      final Map<String, dynamic> queryParams = <String, dynamic>{
        'limit': config.pageSize.toString(),
        'cursor': nextCursor,
        'sort_by': config.sortBy,
        'sort_direction': config.sortDirection,
        if (config.searchQuery != null) 'search': config.searchQuery,
      };

      queryParams.addAll(config.filters);

      final response = await apiClient.get(
        '/khata/parties',
        queryParameters: queryParams,
      );

      final newParties = (response.data['parties'] as List<dynamic>)
          .map((party) => UnifiedParty.fromJson(party as Map<String, dynamic>))
          .toList();

      final hasNext = response.data['has_next'] as bool? ?? false;
      final nextCursorNew = response.data['next_cursor'] as String?;

      final allParties = [...currentState.items, ...newParties];

      state = PaginationState.loaded(
        items: allParties,
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
  Future<void> refresh({KhataPaginationConfig? newConfig}) async {
    await loadFirstPage(newConfig: newConfig);
  }
}

/// Riverpod provider for paginated khata
final paginatedKhataProvider = StateNotifierProvider<
    PaginatedKhataNotifier,
    PaginationState<UnifiedParty>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PaginatedKhataNotifier(apiClient: apiClient);
});
