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
  final String customerFilter;
  final String vehicleFilter;
  final String partNumberFilter;
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
    this.customerFilter = '',
    this.vehicleFilter = '',
    this.partNumberFilter = '',
    this.filtersExpanded = false,
  });

  bool get hasActiveFilters =>
      customerFilter.isNotEmpty ||
      vehicleFilter.isNotEmpty ||
      partNumberFilter.isNotEmpty;

  int get activeFilterCount => [
        customerFilter,
        vehicleFilter,
        partNumberFilter,
      ].where((f) => f.isNotEmpty).length;

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
    String? customerFilter,
    String? vehicleFilter,
    String? partNumberFilter,
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
      customerFilter: customerFilter ?? this.customerFilter,
      vehicleFilter: vehicleFilter ?? this.vehicleFilter,
      partNumberFilter: partNumberFilter ?? this.partNumberFilter,
      filtersExpanded: filtersExpanded ?? this.filtersExpanded,
    );
  }
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  final DashboardRepository _repository;

  DashboardNotifier(this._repository) : super(DashboardState()) {
    refreshDashboard();
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
    final customer = state.customerFilter.isEmpty ? null : state.customerFilter;
    final vehicle = state.vehicleFilter.isEmpty ? null : state.vehicleFilter;
    final part = state.partNumberFilter.isEmpty ? null : state.partNumberFilter;

    try {
      // Fetch all data concurrently — stockAlerts returns [] on error
      final responses = await Future.wait([
        _repository.getKPIs(
          dateFrom: dateFrom,
          customerName: customer,
          vehicleNumber: vehicle,
          partNumber: part,
        ),
        _repository.getStockSummary(),
        _repository.getStockLevels(),
        _repository.getDailySalesVolume(
          dateFrom: dateFrom,
          customerName: customer,
          vehicleNumber: vehicle,
          partNumber: part,
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

  void setCustomerFilter(String value) {
    state = state.copyWith(customerFilter: value);
  }

  void setVehicleFilter(String value) {
    state = state.copyWith(vehicleFilter: value);
  }

  void setPartNumberFilter(String value) {
    state = state.copyWith(partNumberFilter: value);
  }

  Future<void> applyFilters() async {
    await refreshDashboard();
  }

  Future<void> clearFilters() async {
    state = state.copyWith(
      customerFilter: '',
      vehicleFilter: '',
      partNumberFilter: '',
      filtersExpanded: false,
    );
    await refreshDashboard();
  }
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  final repository = ref.watch(dashboardRepositoryProvider);
  return DashboardNotifier(repository);
});
