import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:mobile/features/dashboard/presentation/providers/dashboard_provider.dart';

class QuickReorderState {
  final bool isLoading;
  final bool isLoadingMore;
  final List<Map<String, dynamic>> items;
  final String searchQuery;
  final int totalItems;
  final int currentPage;
  final String? error;

  static const int itemsPerPage = 50;

  QuickReorderState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.items = const [],
    this.searchQuery = '',
    this.totalItems = 0,
    this.currentPage =
        0, // 0-indexed, meaning offset = currentPage * itemsPerPage
    this.error,
  });

  QuickReorderState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    List<Map<String, dynamic>>? items,
    String? searchQuery,
    int? totalItems,
    int? currentPage,
    String? error,
    bool clearError = false,
  }) {
    return QuickReorderState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      items: items ?? this.items,
      searchQuery: searchQuery ?? this.searchQuery,
      totalItems: totalItems ?? this.totalItems,
      currentPage: currentPage ?? this.currentPage,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class QuickReorderNotifier extends Notifier<QuickReorderState> {
  late final DashboardRepository _repository;

  @override
  QuickReorderState build() {
    _repository = ref.watch(dashboardRepositoryProvider);
    Future.microtask(() => loadItems(reset: true));
    return QuickReorderState();
  }

  Future<void> loadItems({bool reset = false}) async {
    if (reset) {
      state = state.copyWith(
          isLoading: true, currentPage: 0, items: [], clearError: true);
    } else {
      if (state.isLoadingMore || _hasReachedMax) return;
      state = state.copyWith(isLoadingMore: true, clearError: true);
    }

    try {
      final offset = state.currentPage * QuickReorderState.itemsPerPage;

      final response = await _repository.getStockLevels(
        limit: QuickReorderState.itemsPerPage,
        offset: offset,
        search: state.searchQuery,
      );

      final newItems = (response['items'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];

      final total = response['total'] as int? ?? 0;

      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        items: reset ? newItems : [...state.items, ...newItems],
        totalItems: total,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  void setSearchQuery(String query) {
    if (state.searchQuery == query) return;
    state = state.copyWith(searchQuery: query);
    loadItems(reset: true);
  }

  void goToPage(int pageIndex) async {
    if (pageIndex < 0 || pageIndex >= _totalPages) return;
    state = state.copyWith(
        currentPage: pageIndex, isLoading: true, items: [], clearError: true);

    try {
      final offset = pageIndex * QuickReorderState.itemsPerPage;
      final response = await _repository.getStockLevels(
        limit: QuickReorderState.itemsPerPage,
        offset: offset,
        search: state.searchQuery,
      );

      final newItems = (response['items'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];

      final total = response['total'] as int? ?? 0;

      state = state.copyWith(
        isLoading: false,
        items: newItems,
        totalItems: total,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void loadNextPage() {
    if (state.currentPage < _totalPages - 1) {
      goToPage(state.currentPage + 1);
    }
  }

  void loadPreviousPage() {
    if (state.currentPage > 0) {
      goToPage(state.currentPage - 1);
    }
  }

  int get _totalPages =>
      (state.totalItems / QuickReorderState.itemsPerPage).ceil();

  bool get _hasReachedMax => state.items.length >= state.totalItems;
}

// We will inject the shared repository
final quickReorderProvider =
    NotifierProvider<QuickReorderNotifier, QuickReorderState>(
        QuickReorderNotifier.new);
