import 'package:flutter_riverpod/legacy.dart';
import 'package:mobile/models/pagination_state.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/udhar/domain/models/udhar_models.dart';

/// Configuration for transaction pagination
class TransactionPaginationConfig {
  final int pageSize;
  final String sortBy;
  final String sortDirection;
  final int ledgerId;

  TransactionPaginationConfig({
    this.pageSize = 30,
    this.sortBy = 'created_at',
    this.sortDirection = 'desc',
    required this.ledgerId,
  });

  TransactionPaginationConfig copyWith({
    int? pageSize,
    String? sortBy,
    String? sortDirection,
    int? ledgerId,
  }) {
    return TransactionPaginationConfig(
      pageSize: pageSize ?? this.pageSize,
      sortBy: sortBy ?? this.sortBy,
      sortDirection: sortDirection ?? this.sortDirection,
      ledgerId: ledgerId ?? this.ledgerId,
    );
  }
}

/// Provider for paginated transactions
class PaginatedTransactionsNotifier
    extends StateNotifier<PaginationState<LedgerTransaction>> {
  final ApiClient apiClient;
  TransactionPaginationConfig config;

  PaginatedTransactionsNotifier({
    required this.apiClient,
    required TransactionPaginationConfig initialConfig,
  })  : config = initialConfig,
        super(const PaginationState.initial()) {
    loadFirstPage();
  }

  /// Load the first page of transactions
  Future<void> loadFirstPage(
      {TransactionPaginationConfig? newConfig}) async {
    if (newConfig != null) {
      config = newConfig;
    }

    state = const PaginationState.loadingFirstPage();

    try {
      final response = await apiClient.get(
        '/api/udhar/ledgers/${config.ledgerId}/transactions',
      );

      final rawList = response.data as List<dynamic>? ?? [];
      final transactions = rawList
          .map((tx) => LedgerTransaction.fromJson(tx as Map<String, dynamic>))
          .toList();

      if (transactions.isEmpty) {
        state = const PaginationState.empty();
      } else {
        state = PaginationState.loaded(
          items: transactions,
          hasNext: false,
          nextCursor: null,
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

  /// Load the next page — not used currently since the backend returns all at once
  Future<void> loadNextPage() async {
    // The existing /api/udhar/ledgers/{id}/transactions endpoint returns all
    // transactions in one call — pagination can be added later.
    return;
  }

  /// Refresh the first page
  Future<void> refresh(
      {TransactionPaginationConfig? newConfig}) async {
    await loadFirstPage(newConfig: newConfig);
  }
}

/// Riverpod provider for paginated transactions — keyed by ledger ID (int)
final paginatedTransactionsProvider = StateNotifierProvider.family<
    PaginatedTransactionsNotifier,
    PaginationState<LedgerTransaction>,
    int>((ref, ledgerId) {
  final apiClient = ref.watch(apiClientProvider);
  return PaginatedTransactionsNotifier(
    apiClient: apiClient,
    initialConfig: TransactionPaginationConfig(ledgerId: ledgerId),
  );
});
