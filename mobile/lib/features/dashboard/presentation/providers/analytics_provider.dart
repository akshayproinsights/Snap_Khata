import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:mobile/features/dashboard/domain/models/dashboard_models.dart';
import 'package:mobile/features/dashboard/presentation/providers/dashboard_provider.dart';

class AnalyticsState {
  final DashboardAnalytics? analytics;
  final bool isLoading;
  final String? error;
  final int days; // Filter: 1, 7, 30

  AnalyticsState({
    this.analytics,
    this.isLoading = false,
    this.error,
    this.days = 30,
  });

  AnalyticsState copyWith({
    DashboardAnalytics? analytics,
    bool? isLoading,
    String? error,
    int? days,
  }) {
    return AnalyticsState(
      analytics: analytics ?? this.analytics,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      days: days ?? this.days,
    );
  }
}

class AnalyticsNotifier extends Notifier<AnalyticsState> {
  late final DashboardRepository _repository;

  @override
  AnalyticsState build() {
    _repository = ref.watch(dashboardRepositoryProvider);
    Future.microtask(() => fetchAnalytics());
    return AnalyticsState();
  }

  String _daysAgo(int days) {
    final date = DateTime.now().subtract(Duration(days: days));
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> fetchAnalytics({int? days}) async {
    final activeDays = days ?? state.days;
    state = state.copyWith(isLoading: true, error: null, days: activeDays);

    final dateFrom = _daysAgo(activeDays);

    try {
      final data = await _repository.getDashboardAnalytics(dateFrom: dateFrom);
      state = state.copyWith(analytics: data, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> changePeriod(int days) async {
    if (days == state.days) return;
    await fetchAnalytics(days: days);
  }
}

final analyticsProvider =
    NotifierProvider<AnalyticsNotifier, AnalyticsState>(AnalyticsNotifier.new);
