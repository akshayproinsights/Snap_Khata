import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/galla/domain/models/galla_transaction.dart';
import 'package:mobile/features/dashboard/presentation/providers/dashboard_providers.dart';

class GallaState {
  final bool isLoading;
  final String? error;
  final List<GallaTransaction> transactions;

  GallaState({
    this.isLoading = false,
    this.error,
    this.transactions = const [],
  });

  GallaState copyWith({
    bool? isLoading,
    String? error,
    List<GallaTransaction>? transactions,
  }) {
    return GallaState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      transactions: transactions ?? this.transactions,
    );
  }
}

final gallaProvider = NotifierProvider<GallaNotifier, GallaState>(GallaNotifier.new);

class GallaNotifier extends Notifier<GallaState> {
  @override
  GallaState build() {
    Future.microtask(fetchTransactions);
    return GallaState(isLoading: true);
  }

  Future<void> fetchTransactions() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final dio = ApiClient().dio;
      final response = await dio.get('/api/galla/transactions');
      
      final data = response.data['data'] as List?;
      if (data != null) {
        final transactions = data.map((e) => GallaTransaction.fromJson(e)).toList();
        state = state.copyWith(isLoading: false, transactions: transactions);
      } else {
        state = state.copyWith(isLoading: false, transactions: []);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> addTransaction(String type, double amount, String notes) async {
    try {
      final dio = ApiClient().dio;
      await dio.post('/api/galla/transaction', data: {
        'transaction_type': type,
        'amount': amount,
        'notes': notes,
      });
      
      await fetchTransactions();
      // Refresh dashboard totals to reflect the new cashInHand
      ref.read(dashboardTotalsProvider.notifier).refreshSilent();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}
