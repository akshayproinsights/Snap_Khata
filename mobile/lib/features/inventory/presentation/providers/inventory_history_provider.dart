import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/inventory/data/inventory_repository.dart';
import 'package:mobile/features/upload/domain/models/upload_models.dart';

class InventoryDashboardData {
  final UploadHistoryResponse history;
  final int pendingReviewCount;

  InventoryDashboardData(this.history, this.pendingReviewCount);
}

final inventoryDashboardProvider =
    FutureProvider.autoDispose<InventoryDashboardData>((ref) async {
  final repo = InventoryRepository();
  final historyData = await repo.getUploadHistory();
  final history = UploadHistoryResponse.fromJson(historyData);

  int pendingReviewCount = 0;
  try {
    final taskData = await repo.getRecentTask();
    if (taskData['status'] == 'duplicate_detected') {
      pendingReviewCount = (taskData['duplicates'] as List?)?.length ?? 0;
    }
  } catch (e) {
    // ignore errors for recent task
  }

  return InventoryDashboardData(history, pendingReviewCount);
});
