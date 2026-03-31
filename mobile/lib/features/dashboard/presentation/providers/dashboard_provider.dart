import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:mobile/features/dashboard/domain/models/dashboard_models.dart';

// Provides the DashboardRepository
final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository();
});

class DashboardState {
  final DashboardKPIs? kpis;
  final StockSummary? stockSummary;
  final Map<String, dynamic>? rawStockLevels;
  final List<DailySalesVolume>? dailySales;
  final List<StockAlert> stockAlerts;
  final RevenueSummary? revenueSummary;
  final DashboardPeriod period;
  final bool isLoading;
  final String? error;

  // Advanced filters
  final Map<String, String> dynamicFilters;
  final bool filtersExpanded;

  DashboardState({
    this.kpis,
    this.stockSummary,
    this.rawStockLevels,
    this.dailySales,
    this.stockAlerts = const [],
    this.revenueSummary,
    this.period = DashboardPeriod.month,
    this.isLoading = false,
    this.error,
    this.dynamicFilters = const {},
    this.filtersExpanded = false,
  });

  bool get hasActiveFilters => dynamicFilters.values.any((item) => item.isNotEmpty);

  int get activeFilterCount => dynamicFilters.values.where((item) => item.isNotEmpty).length;

  DashboardState copyWith({
    DashboardKPIs? kpis,
    StockSummary? stockSummary,
    Map<String, dynamic>? rawStockLevels,
    List<DailySalesVolume>? dailySales,
    List<StockAlert>? stockAlerts,
    RevenueSummary? revenueSummary,
    DashboardPeriod? period,
    bool? isLoading,
    String? error,
    Map<String, String>? dynamicFilters,
    bool? filtersExpanded,
  }) {
    return DashboardState(
      kpis: kpis ?? this.kpis,
      stockSummary: stockSummary ?? this.stockSummary,
      rawStockLevels: rawStockLevels ?? this.rawStockLevels,
      dailySales: dailySales ?? this.dailySales,
      stockAlerts: stockAlerts ?? this.stockAlerts,
      revenueSummary: revenueSummary ?? this.revenueSummary,
      period: period ?? this.period,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      dynamicFilters: dynamicFilters ?? this.dynamicFilters,
      filtersExpanded: filtersExpanded ?? this.filtersExpanded,
    );
  }
}

class DashboardNotifier extends Notifier<DashboardState> {
  late final DashboardRepository _repository;

  @override
  DashboardState build() {
    _repository = ref.watch(dashboardRepositoryProvider);
    Future.microtask(() => refreshDashboard());
    return DashboardState();
  }

  String _daysAgo(int days) {
    final date = DateTime.now().subtract(Duration(days: days));
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> refreshDashboard({DashboardPeriod? period}) async {
    final activePeriod = period ?? state.period;
    state = state.copyWith(isLoading: true, error: null, period: activePeriod);

    final dateFrom = _daysAgo(activePeriod.days);

    // Build optional filter args
    final filters = Map<String, String>.from(state.dynamicFilters)
      ..removeWhere((key, value) => value.isEmpty);

    try {
      // Fetch all data concurrently — stockAlerts returns [] on error
      final responses = await Future.wait([
        _repository.getKPIs(
          dateFrom: dateFrom,
          filters: filters,
        ),
        _repository.getStockSummary(),
        _repository.getStockLevels(),
        _repository.getDailySalesVolume(
          dateFrom: dateFrom,
          filters: filters,
        ),
        _repository.getStockAlerts(limit: 10),
        _repository.getRevenueSummary(dateFrom: dateFrom),
      ]);

      state = state.copyWith(
        kpis: responses[0] as DashboardKPIs,
        stockSummary: responses[1] as StockSummary,
        rawStockLevels: responses[2] as Map<String, dynamic>,
        dailySales: responses[3] as List<DailySalesVolume>,
        stockAlerts: responses[4] as List<StockAlert>,
        revenueSummary: responses[5] as RevenueSummary,
        isLoading: false,
      );
    } catch (e, stackTrace) {
      debugPrint('Dashboard refresh failed: $e\n$stackTrace');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> changePeriod(DashboardPeriod newPeriod) async {
    if (newPeriod == state.period) return;
    await refreshDashboard(period: newPeriod);
  }

  void toggleFiltersExpanded() {
    state = state.copyWith(filtersExpanded: !state.filtersExpanded);
  }

  void setDynamicFilter(String key, String value) {
    final newFilters = Map<String, String>.from(state.dynamicFilters);
    newFilters[key] = value;
    state = state.copyWith(dynamicFilters: newFilters);
  }

  Future<void> applyFilters() async {
    await refreshDashboard();
  }

  Future<void> clearFilters() async {
    state = state.copyWith(
      dynamicFilters: const {},
      filtersExpanded: false,
    );
    await refreshDashboard();
  }
}

final dashboardProvider =
    NotifierProvider<DashboardNotifier, DashboardState>(DashboardNotifier.new);
