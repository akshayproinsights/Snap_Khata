import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/dashboard/domain/models/dashboard_totals.dart';
import 'package:mobile/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:mobile/features/review/presentation/providers/review_provider.dart';


/// Holds the current filter for the activity list (All, Customers, Suppliers).
final activeFilterProvider = NotifierProvider<ActiveFilterNotifier, ActivityFilter>(ActiveFilterNotifier.new);

class ActiveFilterNotifier extends Notifier<ActivityFilter> {
  @override
  ActivityFilter build() => ActivityFilter.all;
  
  void setFilter(ActivityFilter filter) => state = filter;
}

enum ActivityFilter { all, customers, suppliers, items }

/// An [AsyncNotifier] that fetches aggregate totals from Supabase.
final dashboardTotalsProvider = AsyncNotifierProvider<DashboardTotalsNotifier, DashboardTotals>(
  DashboardTotalsNotifier.new,
);

class DashboardTotalsNotifier extends AsyncNotifier<DashboardTotals> {
  @override
  Future<DashboardTotals> build() async {
    final dio = ApiClient().dio;

    try {
      final response = await dio.get('/api/udhar/dashboard-summary');
      final data = response.data['data'];
      if (data != null) {
        return DashboardTotals(
          totalReceivable: double.tryParse(data['total_receivable']?.toString() ?? '0') ?? 0.0,
          totalPayable: double.tryParse(data['total_payable']?.toString() ?? '0') ?? 0.0,
        );
      }
      throw Exception('Invalid response: data is null');
    } catch (e) {
      // Re-throw to allow UI to show error state instead of silently returning 0s
      throw Exception('Failed to load dashboard totals: $e');
    }
  }

  /// Refreshes the dashboard totals.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}

/// Provider for pending supplier reviews count.
final pendingSupplierReviewsProvider = Provider<int>((ref) {
  final inventoryState = ref.watch(inventoryProvider);
  final items = inventoryState.items;
  
  final Map<String, bool> unverifiedReceipts = {};
  for (final item in items) {
    if (item.verificationStatus != 'Done') {
      final key = item.invoiceNumber.isNotEmpty
          ? item.invoiceNumber
          : '${item.invoiceDate}_${item.vendorName ?? ''}';
      final safeKey = key.isNotEmpty ? key : item.id.toString();
      unverifiedReceipts[safeKey] = true;
    }
  }
  return unverifiedReceipts.length;
});

/// Provider for pending customer reviews count.
final pendingCustomerReviewsProvider = Provider<int>((ref) {
  final customerReviewState = ref.watch(reviewProvider);
  return customerReviewState.groups.length;
});
