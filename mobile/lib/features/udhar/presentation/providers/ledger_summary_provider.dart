import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:dio/dio.dart';
import '../../domain/models/ledger_dashboard_summary.dart';

class LedgerSummaryState {
  final bool isLoading;
  final LedgerDashboardSummary? summary;
  final String? error;

  LedgerSummaryState({
    this.isLoading = false,
    this.summary,
    this.error,
  });

  LedgerSummaryState copyWith({
    bool? isLoading,
    LedgerDashboardSummary? summary,
    String? error,
    bool clearError = false,
  }) {
    return LedgerSummaryState(
      isLoading: isLoading ?? this.isLoading,
      summary: summary ?? this.summary,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class LedgerSummaryNotifier extends Notifier<LedgerSummaryState> {
  late final Dio _dio;

  @override
  LedgerSummaryState build() {
    _dio = ApiClient().dio;
    Future.microtask(() => fetchSummary());
    return LedgerSummaryState();
  }

  Future<void> fetchSummary() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _dio.get('/api/udhar/dashboard-summary');
      final data = response.data['data'];
      if (data != null) {
        final summary = LedgerDashboardSummary.fromJson(data);
        state = state.copyWith(isLoading: false, summary: summary);
      } else {
        state = state.copyWith(
            isLoading: false, error: 'Failed to parse dashboard summary');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final ledgerSummaryProvider =
    NotifierProvider<LedgerSummaryNotifier, LedgerSummaryState>(
        LedgerSummaryNotifier.new);
