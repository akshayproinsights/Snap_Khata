import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/activities/presentation/providers/activity_provider.dart';
import 'package:mobile/features/activities/presentation/widgets/dual_action_fab.dart';

class RecentActivitiesPage extends ConsumerWidget {
  const RecentActivitiesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredActivitiesAsync = ref.watch(filteredActivitiesProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Recent Activities',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search activities, names, or invoice IDs...',
                prefixIcon: Icon(
                  Icons.search,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                ref.read(activitiesSearchQueryProvider.notifier).updateQuery(value);
              },
            ),
          ),
          
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
                    Text(
                      'Failed to load activities',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
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
                  return const Center(
                    child: Text('No activities found.'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(recentActivitiesProvider.notifier).refreshData();
                  },
                  child: ListView.builder(
                    itemCount: activities.length,
                    itemBuilder: (context, index) {
                      final item = activities[index];
                      return ListTile(
                        title: Text(
                          item.entityName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: item.displayId != null 
                            ? Text('ID: ${item.displayId}')
                            : null,
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
