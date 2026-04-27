import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/features/upload/domain/models/upload_models.dart';
import 'package:mobile/features/upload/presentation/providers/paginated_upload_provider.dart';
import 'package:mobile/core/theme/context_extension.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import 'package:mobile/models/pagination_state.dart';

class UploadTrackingPagePaginated extends ConsumerStatefulWidget {
  const UploadTrackingPagePaginated({super.key});

  @override
  ConsumerState<UploadTrackingPagePaginated> createState() =>
      _UploadTrackingPagePaginatedState();
}

class _UploadTrackingPagePaginatedState
    extends ConsumerState<UploadTrackingPagePaginated> {
  final ScrollController _scrollController = ScrollController();
  String _selectedStatus = 'all';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      // Load next page when user is near the bottom
      ref.read(paginatedUploadProvider.notifier).loadNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final paginationState = ref.watch(paginatedUploadProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Upload Tracking'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Status filter chips
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    'All',
                    'all',
                    _selectedStatus == 'all',
                    isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Processing',
                    'processing',
                    _selectedStatus == 'processing',
                    isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Completed',
                    'completed',
                    _selectedStatus == 'completed',
                    isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Failed',
                    'failed',
                    _selectedStatus == 'failed',
                    isDark,
                  ),
                ],
              ),
            ),
          ),
          // Tasks list or skeleton
          Expanded(
            child: paginationState.when(
              initial: () => const _SkeletonLoader(),
              loadingFirstPage: () => const _SkeletonLoader(),
              loadingNextPage: (previousItems) => _buildTasksList(
                context,
                previousItems,
                true,
                isDark,
              ),
              loaded: (items, hasNext, nextCursor, isLoadingMore) =>
                  _buildTasksList(context, items, isLoadingMore, isDark),
              error: (message, previousItems) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.alertCircle,
                        size: 48, color: Colors.red.shade300),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading uploads',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        ref
                            .read(paginatedUploadProvider.notifier)
                            .loadFirstPage();
                      },
                      icon: Icon(LucideIcons.refreshCw),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              empty: () => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.uploadCloud,
                        size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No uploads found',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    bool isSelected,
    bool isDark,
  ) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedStatus = value;
        });
        ref.read(paginatedUploadProvider.notifier).loadFirstPage(
              newConfig: UploadPaginationConfig(
                status: value == 'all' ? null : value,
              ),
            );
      },
    );
  }

  Widget _buildTasksList(
    BuildContext context,
    List<UploadTask> tasks,
    bool isLoadingMore,
    bool isDark,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(paginatedUploadProvider.notifier).refresh();
      },
      child: ListView.builder(
        controller: _scrollController,
        itemCount: tasks.length + (isLoadingMore ? 1 : 0),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          if (index == tasks.length) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(
                      isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
            );
          }

          final task = tasks[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildTaskCard(context, task),
          );
        },
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, UploadTask task) {
    final statusColor = _getStatusColor(task.status);
    final statusIcon = _getStatusIcon(task.status);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upload Task',
                        style: context.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM dd, yyyy hh:mm a')
                            .format(task.createdAt),
                        style: context.textTheme.labelSmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        statusIcon,
                        size: 14,
                        color: statusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        task.status.toUpperCase(),
                        style: context.textTheme.labelSmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Items processed:',
                  style: context.textTheme.labelSmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  '${task.itemsCount}/${task.totalItems}',
                  style: context.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            ...[
            const SizedBox(height: 8),
            Text(
              task.message,
              style: context.textTheme.labelSmall?.copyWith(
                color: Colors.grey.shade600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'processing':
      case 'queued':
        return Colors.blue;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return LucideIcons.check;
      case 'processing':
      case 'queued':
        return LucideIcons.clock;
      case 'failed':
        return LucideIcons.x;
      default:
        return LucideIcons.helpCircle;
    }
  }
}

class _SkeletonLoader extends StatelessWidget {
  const _SkeletonLoader();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        itemCount: 6,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
      ),
    );
  }
}
