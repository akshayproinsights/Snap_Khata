import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/activities/domain/models/activity_item.dart';
import 'package:mobile/features/activities/presentation/providers/activity_provider.dart';
import 'package:mobile/features/activities/presentation/widgets/dual_action_fab.dart';
import 'package:mobile/features/activities/presentation/widgets/customer_activity_card.dart';
import 'package:mobile/features/activities/presentation/widgets/vendor_activity_card.dart';
import 'package:mobile/features/dashboard/presentation/providers/dashboard_providers.dart';

class RecentActivitiesPage extends ConsumerWidget {
  const RecentActivitiesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredActivitiesAsync = ref.watch(filteredActivitiesProvider);

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Recent Activities',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        backgroundColor: context.surfaceColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // Search Bar - Premium Refined
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search activities, names, or #ID...',
                hintStyle: TextStyle(color: context.textSecondaryColor.withValues(alpha: 0.6)),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: context.textSecondaryColor,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: context.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: context.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: context.primaryColor, width: 2),
                ),
                filled: true,
                fillColor: context.surfaceColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                ref.read(activitiesSearchQueryProvider.notifier).updateQuery(value);
              },
            ),
          ),

          // Filters Row - One-Handed Ergonomics
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  filter: ActivityFilter.all,
                  activeColor: context.primaryColor,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Customers',
                  filter: ActivityFilter.customers,
                  activeColor: context.successColor,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Suppliers',
                  filter: ActivityFilter.suppliers,
                  activeColor: Colors.orange, // Suppliers usually Payable
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          
          // Body List
          Expanded(
            child: filteredActivitiesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 48, color: context.errorColor),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load activities',
                      style: TextStyle(
                        color: context.textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ref.read(recentActivitiesProvider.notifier).refreshData();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (activities) {
                if (activities.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history_rounded, size: 64, color: context.textSecondaryColor.withValues(alpha: 0.2)),
                        const SizedBox(height: 16),
                        Text(
                          'No activities found',
                          style: TextStyle(
                            color: context.textSecondaryColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(recentActivitiesProvider.notifier).refreshData();
                  },
                  child: ListView.builder(
                    itemCount: activities.length,
                    padding: const EdgeInsets.only(bottom: 100), // Space for FAB
                    itemBuilder: (context, index) {
                      final item = activities[index];
                      return item.map(
                        customer: (c) => CustomerActivityCard(item: c),
                        vendor: (v) => VendorActivityCard(item: v),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: const DualActionFab(),
    );
  }
}

class _FilterChip extends ConsumerWidget {
  const _FilterChip({
    required this.label,
    required this.filter,
    required this.activeColor,
  });

  final String label;
  final ActivityFilter filter;
  final Color activeColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFilter = ref.watch(activeFilterProvider);
    final isSelected = activeFilter == filter;

    return GestureDetector(
      onTap: () {
        ref.read(activeFilterProvider.notifier).setFilter(filter);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : context.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : context.borderColor,
            width: 1.5,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: activeColor.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : context.textSecondaryColor,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
