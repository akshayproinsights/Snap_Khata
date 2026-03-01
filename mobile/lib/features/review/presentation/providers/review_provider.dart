import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/review/data/review_repository.dart';
import 'package:mobile/features/review/domain/models/review_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

final reviewRepositoryProvider =
    Provider<ReviewRepository>((ref) => ReviewRepository());

class ReviewState {
  final List<InvoiceReviewGroup> groups;
  final bool isLoading;
  final bool isSyncing;
  final String? error;
  final SyncProgress? syncProgress;

  ReviewState({
    this.groups = const [],
    this.isLoading = false,
    this.isSyncing = false,
    this.error,
    this.syncProgress,
  });

  ReviewState copyWith({
    List<InvoiceReviewGroup>? groups,
    bool? isLoading,
    bool? isSyncing,
    String? error,
    SyncProgress? syncProgress,
  }) {
    return ReviewState(
      groups: groups ?? this.groups,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      error: error,
      syncProgress: syncProgress ?? this.syncProgress,
    );
  }
}

class SyncProgress {
  final String stage;
  final int percentage;
  final String message;

  SyncProgress(this.stage, this.percentage, this.message);
}

class ReviewNotifier extends StateNotifier<ReviewState> {
  final ReviewRepository _repository;

  ReviewNotifier(this._repository) : super(ReviewState()) {
    fetchReviewData();
  }

  Future<void> fetchReviewData() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final datesResult = await _repository.fetchDates();
      final amountsResult = await _repository.fetchAmounts();

      final grouped = _groupRecords(datesResult, amountsResult);
      state = state.copyWith(groups: grouped, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  List<InvoiceReviewGroup> _groupRecords(
      List<ReviewRecord> dates, List<ReviewRecord> amounts) {
    final Map<String, InvoiceReviewGroup> map = {};

    for (var date in dates) {
      map[date.receiptNumber] = InvoiceReviewGroup(
        receiptNumber: date.receiptNumber,
        header: date,
      );
    }

    for (var amount in amounts) {
      if (map.containsKey(amount.receiptNumber)) {
        final existing = map[amount.receiptNumber]!;
        map[amount.receiptNumber] = InvoiceReviewGroup(
          receiptNumber: existing.receiptNumber,
          header: existing.header,
          lineItems: [...existing.lineItems, amount],
        );
      } else {
        // Technically shouldn't happen without a header, but handle gracefully
        map[amount.receiptNumber] = InvoiceReviewGroup(
          receiptNumber: amount.receiptNumber,
          lineItems: [amount],
        );
      }
    }

    return map.values.toList();
  }

  Future<void> updateDateRecord(ReviewRecord newRecord) async {
    try {
      await _repository.updateSingleDate(newRecord);
      // Optimistic update locally
      final newGroups = state.groups.map((group) {
        if (group.receiptNumber == newRecord.receiptNumber &&
            group.header?.rowId == newRecord.rowId) {
          return InvoiceReviewGroup(
            receiptNumber: group.receiptNumber,
            header: newRecord,
            lineItems: group.lineItems,
          );
        }
        return group;
      }).toList();
      state = state.copyWith(groups: newGroups);
    } catch (e) {
      state = state.copyWith(error: 'Failed to update date: $e');
    }
  }

  Future<void> updateAmountRecord(ReviewRecord newRecord) async {
    try {
      await _repository.updateSingleAmount(newRecord);
      // Optimistic update locally
      final newGroups = state.groups.map((group) {
        if (group.receiptNumber == newRecord.receiptNumber) {
          final updatedLines = group.lineItems.map((item) {
            return item.rowId == newRecord.rowId ? newRecord : item;
          }).toList();
          return InvoiceReviewGroup(
            receiptNumber: group.receiptNumber,
            header: group.header,
            lineItems: updatedLines,
          );
        }
        return group;
      }).toList();
      state = state.copyWith(groups: newGroups);
    } catch (e) {
      state = state.copyWith(error: 'Failed to update amount: $e');
    }
  }

  Future<void> deleteRecord(String rowId, String receiptNumber) async {
    try {
      await _repository.deleteRecord(rowId);
      final newGroups = state.groups.map((group) {
        if (group.receiptNumber == receiptNumber) {
          final updatedLines =
              group.lineItems.where((item) => item.rowId != rowId).toList();
          return InvoiceReviewGroup(
            receiptNumber: group.receiptNumber,
            header: group.header,
            lineItems: updatedLines,
          );
        }
        return group;
      }).toList();
      state = state.copyWith(groups: newGroups);
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete record: $e');
    }
  }

  Future<void> syncAndFinish() async {
    state = state.copyWith(isSyncing: true, error: null);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      await for (final progress
          in _repository.syncAndFinishWithProgress(token)) {
        state = state.copyWith(
          syncProgress: SyncProgress(
            progress['stage'] ?? '',
            progress['percentage'] ?? 0,
            progress['message'] ?? '',
          ),
        );
        if (progress['stage'] == 'complete') {
          break;
        }
      }

      // Remove groups that were processed (refresh)
      await fetchReviewData();
    } catch (e) {
      state = state.copyWith(error: 'Sync failed: $e');
    } finally {
      state = state.copyWith(isSyncing: false, syncProgress: null);
    }
  }

  Future<void> deleteReceipt(String receiptNumber) async {
    try {
      await _repository.deleteReceipt(receiptNumber);
      final newGroups =
          state.groups.where((g) => g.receiptNumber != receiptNumber).toList();
      state = state.copyWith(groups: newGroups);
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete receipt: $e');
    }
  }
}

final reviewProvider =
    StateNotifierProvider<ReviewNotifier, ReviewState>((ref) {
  return ReviewNotifier(ref.watch(reviewRepositoryProvider));
});
