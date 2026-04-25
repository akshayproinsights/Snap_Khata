import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/activities/data/repositories/activity_repository.dart';
import 'package:mobile/features/activities/domain/models/activity_item.dart';
import 'package:mobile/features/dashboard/presentation/providers/dashboard_providers.dart';

/// Provides the [ActivityRepository] instance.
/// The repository uses the authenticated [ApiClient] internally, so all
/// queries are automatically scoped to the logged-in merchant.
final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return ActivityRepository();
});

/// Holds the current string from the search bar.
final activitiesSearchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void updateQuery(String newQuery) {
    state = newQuery;
  }
}

/// An [AsyncNotifier] that fetches and caches the raw, unified list from the repository.
final recentActivitiesProvider =
    AsyncNotifierProvider<RecentActivitiesNotifier, List<ActivityItem>>(
  RecentActivitiesNotifier.new,
);

class RecentActivitiesNotifier extends AsyncNotifier<List<ActivityItem>> {
  @override
  Future<List<ActivityItem>> build() async {
    // Call the repository to fetch the 100 most recent activities.
    return ref.read(activityRepositoryProvider).fetchRecentActivities(limit: 100);
  }

  /// Manually invalidate and refresh the state.
  /// To be called after a user successfully scans a new purchase bill or customer receipt.
  Future<void> refreshData() async {
    ref.invalidateSelf();
    // Also invalidate dashboard totals as transactions affect balances
    ref.invalidate(dashboardTotalsProvider);
    await future;
  }
}

/// A derived provider that watches both the raw list, the search query, and the filter,
/// returning the locally filtered results without re-fetching from the backend.
final filteredActivitiesProvider = Provider<AsyncValue<List<ActivityItem>>>((ref) {
  final rawActivitiesAsync = ref.watch(recentActivitiesProvider);
  final searchQuery = ref.watch(activitiesSearchQueryProvider).toLowerCase().trim();
  final filter = ref.watch(activeFilterProvider);

  // if the raw data is in a loading or error state, pass that state through.
  return rawActivitiesAsync.whenData((activities) {
    var filtered = activities;

    // Apply Type Filter
    if (filter == ActivityFilter.customers) {
      filtered = filtered.where((a) => a.map(customer: (_) => true, vendor: (_) => false)).toList();
    } else if (filter == ActivityFilter.suppliers) {
      filtered = filtered.where((a) => a.map(customer: (_) => false, vendor: (_) => true)).toList();
    }

    // Apply Search Filter
    if (searchQuery.isEmpty) {
      return filtered;
    }

    return filtered.where((item) {
      final matchesName = item.entityName.toLowerCase().contains(searchQuery);
      final matchesId =
          item.displayId != null && item.displayId!.toLowerCase().contains(searchQuery);
      
      return matchesName || matchesId;
    }).toList();
  });
});
