import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Skeleton loading widget for inventory items
class InventorySkeletonLoader extends StatelessWidget {
  final int itemCount;
  final bool isLoading;

  const InventorySkeletonLoader({
    super.key,
    this.itemCount = 8,
    this.isLoading = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return const SizedBox.shrink();

    return ListView.builder(
      itemCount: itemCount,
      itemBuilder: (context, index) => _InventorySkeleton(),
      physics: const NeverScrollableScrollPhysics(),
    );
  }
}

class _InventorySkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with invoice and vendor
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _skeletonBox(80, 16),
                    _skeletonBox(100, 16),
                  ],
                ),
                const SizedBox(height: 8),
                // Product name
                _skeletonBox(200, 14),
                const SizedBox(height: 8),
                // Details row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _skeletonBox(60, 12),
                    _skeletonBox(60, 12),
                    _skeletonBox(60, 12),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _skeletonBox(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// Skeleton loading widget for Khata parties list
class KhataPartiesSkeleton extends StatelessWidget {
  final int itemCount;
  final bool isLoading;

  const KhataPartiesSkeleton({
    super.key,
    this.itemCount = 8,
    this.isLoading = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return const SizedBox.shrink();

    return ListView.builder(
      itemCount: itemCount,
      itemBuilder: (context, index) => _KhataSkeleton(),
      physics: const NeverScrollableScrollPhysics(),
    );
  }
}

class _KhataSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Party name
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _skeletonBox(120, 16),
                    _skeletonBox(80, 16),
                  ],
                ),
                const SizedBox(height: 8),
                // Balance info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _skeletonBox(100, 14),
                    _skeletonBox(80, 14),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _skeletonBox(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// Skeleton loading widget for transaction items
class TransactionsSkeleton extends StatelessWidget {
  final int itemCount;
  final bool isLoading;

  const TransactionsSkeleton({
    super.key,
    this.itemCount = 8,
    this.isLoading = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return const SizedBox.shrink();

    return ListView.builder(
      itemCount: itemCount,
      itemBuilder: (context, index) => _TransactionSkeleton(),
      physics: const NeverScrollableScrollPhysics(),
    );
  }
}

class _TransactionSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _skeletonBox(100, 14),
                    const SizedBox(height: 4),
                    _skeletonBox(80, 12),
                  ],
                ),
                _skeletonBox(60, 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _skeletonBox(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// Skeleton loading widget for upload tasks
class UploadTasksSkeleton extends StatelessWidget {
  final int itemCount;
  final bool isLoading;

  const UploadTasksSkeleton({
    super.key,
    this.itemCount = 6,
    this.isLoading = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return const SizedBox.shrink();

    return ListView.builder(
      itemCount: itemCount,
      itemBuilder: (context, index) => _UploadTaskSkeleton(),
      physics: const NeverScrollableScrollPhysics(),
    );
  }
}

class _UploadTaskSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status badge and date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _skeletonBox(60, 20),
                    _skeletonBox(100, 12),
                  ],
                ),
                const SizedBox(height: 8),
                // Progress bar
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 8),
                // Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _skeletonBox(50, 12),
                    _skeletonBox(50, 12),
                    _skeletonBox(50, 12),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _skeletonBox(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// Empty state widget
class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onRetry;

  const EmptyStateWidget({
    super.key,
    this.title = 'No Items Found',
    this.subtitle = 'Try adjusting your filters',
    this.icon = Icons.inbox_outlined,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Error state widget
class ErrorStateWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorStateWidget({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            'Error Loading Data',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.red[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

/// Loading indicator for bottom of list (load more)
class LoadMoreIndicator extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onLoadMore;

  const LoadMoreIndicator({
    super.key,
    this.isLoading = false,
    this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}
