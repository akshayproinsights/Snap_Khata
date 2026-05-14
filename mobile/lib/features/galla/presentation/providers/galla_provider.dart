import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/galla/domain/models/galla_transaction.dart';
import 'package:mobile/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:mobile/features/dashboard/domain/models/dashboard_models.dart';
import 'package:intl/intl.dart';
class GallaState {
  final bool isLoading;
  final String? error;
  final List<GallaTransaction> transactions;
  final int days;

  GallaState({
    this.isLoading = false,
    this.error,
    this.transactions = const [],
    this.days = 7,
  });

  GallaState copyWith({
    bool? isLoading,
    String? error,
    List<GallaTransaction>? transactions,
    int? days,
  }) {
    return GallaState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      transactions: transactions ?? this.transactions,
      days: days ?? this.days,
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

  void changePeriod(int days) {
    state = state.copyWith(days: days);
  }

  List<AnalyticsDataPoint> getCashEarnedChartData() {
    final cutoffDate = DateTime.now().subtract(Duration(days: state.days));
    final Map<String, double> dailyTotals = {};
    final Map<String, int> dailyCounts = {};

    for (final tx in state.transactions) {
      if (tx.transactionType == 'CASH_SALE' || tx.transactionType == 'MONEY_IN') {
        final txDateStr = (tx.invoiceDate != null && tx.invoiceDate!.isNotEmpty) 
            ? tx.invoiceDate! 
            : tx.createdAt;
        final txDate = DateTime.tryParse(txDateStr) ?? DateTime.now();
        
        if (state.days == 365 || txDate.isAfter(cutoffDate)) {
          final dateKey = DateFormat('yyyy-MM-dd').format(txDate);
          dailyTotals[dateKey] = (dailyTotals[dateKey] ?? 0) + tx.amount;
          dailyCounts[dateKey] = (dailyCounts[dateKey] ?? 0) + 1;
        }
      }
    }

    // Sort by date ascending and format properly
    final sortedKeys = dailyTotals.keys.toList()..sort();
    return sortedKeys.map((date) => AnalyticsDataPoint(
      date: date,
      amount: dailyTotals[date]!.toInt(),
      count: dailyCounts[date] ?? 0,
    )).toList();
  }
}
