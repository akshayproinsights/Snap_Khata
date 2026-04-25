import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/features/dashboard/domain/models/dashboard_totals.dart';
import 'package:mobile/features/inventory/presentation/providers/inventory_items_provider.dart';
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
    final supabase = Supabase.instance.client;

    try {
      // Perform two concurrent Supabase aggregate queries
      final results = await Future.wait([
        supabase.from('customer_ledgers').select('balance_due.sum()').single(),
        supabase.from('vendor_ledgers').select('balance_due.sum()').single(),
      ]);

      // Handle nulls: If table is empty, sum returns null in some cases, or handle as 0.0
      // Depending on Supabase return format, we extract the sum.
      // Usually, with .select('balance_due.sum()').single(), it returns {'sum': value}
      
      final totalReceivable = _parseSum(results[0]);
      final totalPayable = _parseSum(results[1]);

      return DashboardTotals(
        totalReceivable: totalReceivable,
        totalPayable: totalPayable,
      );
    } catch (e) {
      // Return 0.0 on error or empty results
      return DashboardTotals.initial();
    }
  }

  double _parseSum(dynamic result) {
    if (result == null || result['sum'] == null) return 0.0;
    return (result['sum'] as num).toDouble();
  }

  /// Refreshes the dashboard totals.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}

/// Provider for pending supplier reviews count.
final pendingSupplierReviewsProvider = Provider<int>((ref) {
  final itemsAsync = ref.watch(inventoryItemsProvider);
  return itemsAsync.maybeWhen(
    data: (items) {
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
    },
    orElse: () => 0,
  );
});

/// Provider for pending customer reviews count.
final pendingCustomerReviewsProvider = Provider<int>((ref) {
  final customerReviewState = ref.watch(reviewProvider);
  return customerReviewState.groups.length;
});

