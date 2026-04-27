import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';

/// Memory-efficient pagination caching strategy
/// Limits cached data to prevent memory bloat
class PaginationCaching {
  static const int maxCachedItems = 500;
  static const int maxPages = 20;
  static const Duration cacheDuration = Duration(minutes: 5);

  /// Prune old items from cache to prevent unlimited memory growth
  static Future<void> pruneCache<T>(
    String key,
    List<T> items, {
    int maxItems = maxCachedItems,
  }) async {
    if (items.length > maxItems) {
      // Keep only the most recent items
      final prunedItems = items.sublist(items.length - maxItems);
      
      try {
        final box = await Hive.openBox('pagination_cache');
        await box.put(key, prunedItems);
      } catch (e) {
        debugPrint('Error pruning cache: $e');
      }
    }
  }

  /// Clear cache for a specific key
  static Future<void> clearCache(String key) async {
    try {
      final box = await Hive.openBox('pagination_cache');
      await box.delete(key);
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  /// Clear all pagination cache
  static Future<void> clearAllCache() async {
    try {
      final box = await Hive.openBox('pagination_cache');
      await box.clear();
    } catch (e) {
      debugPrint('Error clearing all cache: $e');
    }
  }

  /// Get cached items
  static Future<List<T>?> getCache<T>(String key) async {
    try {
      final box = await Hive.openBox('pagination_cache');
      return box.get(key) as List<T>?;
    } catch (e) {
      debugPrint('Error getting cache: $e');
      return null;
    }
  }
}

/// Memory-efficient scroll position tracking
class ScrollPositionTracker {
  static const String _boxName = 'scroll_positions';

  /// Save scroll position for a specific page
  static Future<void> saveScrollPosition(
    String pageKey,
    double scrollOffset,
  ) async {
    try {
      final box = await Hive.openBox(_boxName);
      await box.put(pageKey, scrollOffset);
    } catch (e) {
      debugPrint('Error saving scroll position: $e');
    }
  }

  /// Get saved scroll position
  static Future<double?> getScrollPosition(String pageKey) async {
    try {
      final box = await Hive.openBox(_boxName);
      return box.get(pageKey) as double?;
    } catch (e) {
      debugPrint('Error getting scroll position: $e');
      return null;
    }
  }

  /// Clear all scroll positions
  static Future<void> clearAll() async {
    try {
      final box = await Hive.openBox(_boxName);
      await box.clear();
    } catch (e) {
      debugPrint('Error clearing scroll positions: $e');
    }
  }
}

/// Memory monitoring and optimization
class MemoryOptimizer {
  /// Check if memory usage is getting too high
  static bool isMemoryUsageHigh(
    int currentItemCount, {
    int thresholdItems = PaginationCaching.maxCachedItems,
  }) {
    return currentItemCount > thresholdItems;
  }

  /// Get memory optimization recommendations
  static String getOptimizationRecommendations(int itemCount) {
    if (itemCount > PaginationCaching.maxCachedItems * 2) {
      return 'Critical: Memory usage is very high. Consider clearing old pages.';
    } else if (itemCount > PaginationCaching.maxCachedItems) {
      return 'Warning: Memory usage is high. Consider implementing virtual scrolling.';
    }
    return 'Memory usage is normal.';
  }

  /// Clear memory by removing oldest pages
  static Future<void> clearOldestPage(
    String cacheKey,
    List<dynamic> items, {
    int itemsPerPage = 25,
  }) async {
    if (items.length > PaginationCaching.maxCachedItems) {
      final itemsToRemove = items.length - PaginationCaching.maxCachedItems;
      final newItems = items.skip(itemsToRemove).toList();
      
      try {
        final box = await Hive.openBox('pagination_cache');
        await box.put(cacheKey, newItems);
      } catch (e) {
        debugPrint('Error clearing oldest page: $e');
      }
    }
  }
}
