import 'package:dio/dio.dart';
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

  /// Converts any exception to a concise, user-friendly message.
  String _friendlyError(Object e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return 'No internet connection. Please check your network and try again.';
      }
      final statusCode = e.response?.statusCode;
      if (statusCode == 500) {
        return 'Server error. Please try again in a moment.';
      } else if (statusCode == 400) {
        return 'Invalid data. Please check your inputs and try again.';
      } else if (statusCode == 401 || statusCode == 403) {
        return 'Session expired. Please log in again.';
      } else if (statusCode == 404) {
        return 'Record not found. It may have already been deleted.';
      } else if (statusCode != null) {
        return 'Request failed (error $statusCode). Please try again.';
      }
    }
    return 'Something went wrong. Please try again.';
  }

  Future<void> fetchReviewData() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final datesResult = await _repository.fetchDates();
      final amountsResult = await _repository.fetchAmounts();

      final grouped = _groupRecords(datesResult, amountsResult);
      state = state.copyWith(groups: grouped, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendlyError(e));
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
      state = state.copyWith(
          error: 'Could not update record. ${_friendlyError(e)}');
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
      state = state.copyWith(
          error: 'Could not update record. ${_friendlyError(e)}');
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
      state = state.copyWith(
          error: 'Could not delete record. ${_friendlyError(e)}');
    }
  }

  Future<void> syncAndFinish() async {
    state = state.copyWith(isSyncing: true, error: null);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      String? syncError;

      await for (final progress
          in _repository.syncAndFinishWithProgress(token)) {
        final stage = progress['stage'] as String? ?? '';
        final pct = (progress['percentage'] as num? ?? 0).toInt();
        final msg = progress['message'] as String? ?? '';

        // 'working' is a keepalive heartbeat — update message but keep last
        // real percentage so the progress bar doesn't jump backwards to -1
        if (stage == 'working') {
          final lastPct = state.syncProgress?.percentage ?? 0;
          state = state.copyWith(
            syncProgress: SyncProgress(stage, lastPct, msg),
          );
          continue;
        }

        state = state.copyWith(
          syncProgress: SyncProgress(stage, pct.clamp(0, 100), msg),
        );

        if (stage == 'complete') break;

        // Backend signalled an error — capture the message and stop
        if (stage == 'error') {
          syncError =
              msg.isNotEmpty ? msg : 'Sync failed on server. Please retry.';
          break;
        }
      }

      if (syncError != null) {
        state = state.copyWith(error: syncError);
        return;
      }

      // Remove groups that were processed (refresh)
      await fetchReviewData();
    } catch (e) {
      state = state.copyWith(error: 'Sync failed. ${_friendlyError(e)}');
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
      state = state.copyWith(
          error: 'Could not delete receipt. ${_friendlyError(e)}');
    }
  }
}

final reviewProvider =
    StateNotifierProvider<ReviewNotifier, ReviewState>((ref) {
  return ReviewNotifier(ref.watch(reviewRepositoryProvider));
});
