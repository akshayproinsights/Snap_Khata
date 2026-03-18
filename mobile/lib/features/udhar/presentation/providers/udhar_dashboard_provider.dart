import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:dio/dio.dart';
import '../../domain/models/dashboard_summary_model.dart';

class UdharDashboardState {
  final bool isLoading;
  final DashboardSummary? summary;
  final String? error;

  UdharDashboardState({
    this.isLoading = false,
    this.summary,
    this.error,
  });

  UdharDashboardState copyWith({
    bool? isLoading,
    DashboardSummary? summary,
    String? error,
    bool clearError = false,
  }) {
    return UdharDashboardState(
      isLoading: isLoading ?? this.isLoading,
      summary: summary ?? this.summary,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class UdharDashboardNotifier extends Notifier<UdharDashboardState> {
  late final Dio _dio;

  @override
  UdharDashboardState build() {
    _dio = ApiClient().dio;
    Future.microtask(() => fetchSummary());
    return UdharDashboardState();
  }

  Future<void> fetchSummary() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _dio.get('/api/udhar/dashboard-summary');
      final data = response.data['data'];
      if (data != null) {
        state = state.copyWith(
          isLoading: false,
          summary: DashboardSummary.fromJson(data),
        );
      } else {
        state = state.copyWith(
            isLoading: false, error: 'Failed to parse dashboard summary');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final udharDashboardProvider =
    NotifierProvider<UdharDashboardNotifier, UdharDashboardState>(
        UdharDashboardNotifier.new);
