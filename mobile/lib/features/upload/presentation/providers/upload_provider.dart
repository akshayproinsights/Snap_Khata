import 'dart:async';
import 'dart:io';
import 'package:cross_file/cross_file.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/upload/data/upload_repository.dart';
import 'package:mobile/features/upload/domain/models/upload_models.dart';
import 'package:mobile/features/shared/presentation/providers/background_task_provider.dart';
import 'package:mobile/core/routing/app_router.dart';
import 'package:mobile/core/network/sync_queue_service.dart';

final uploadRepositoryProvider = Provider<UploadRepository>((ref) {
  return UploadRepository();
});

class UploadState {
  /// NEW: rich per-file items (replaces plain XFile list)
  final List<UploadFileItem> fileItems;

  /// Legacy compatibility — derived from fileItems
  List<XFile> get selectedFiles =>
      fileItems.map((i) => XFile(i.path, name: i.name)).toList();

  final bool isUploading;
  final bool isProcessing;
  final double uploadProgress;
  final UploadTaskStatus? processingStatus;
  final String? error;
  final bool hasDuplicate;
  final UploadHistoryResponse? historyData;
  final bool isLoadingHistory;
  final String? historyError;

  UploadState({
    this.fileItems = const [],
    this.isUploading = false,
    this.isProcessing = false,
    this.uploadProgress = 0.0,
    this.processingStatus,
    this.error,
    this.hasDuplicate = false,
    this.historyData,
    this.isLoadingHistory = false,
    this.historyError,
  });

  int get pendingCount =>
      fileItems.where((f) => f.status == UploadFileStatus.idle).length;
  int get failedCount =>
      fileItems.where((f) => f.status == UploadFileStatus.failed).length;
  int get doneCount =>
      fileItems.where((f) => f.status == UploadFileStatus.done).length;
  bool get hasFiles => fileItems.isNotEmpty;
  bool get allDone => fileItems.isNotEmpty && doneCount == fileItems.length;

  UploadState copyWith({
    List<UploadFileItem>? fileItems,
    bool? isUploading,
    bool? isProcessing,
    double? uploadProgress,
    UploadTaskStatus? processingStatus,
    String? error,
    bool? hasDuplicate,
    UploadHistoryResponse? historyData,
    bool? isLoadingHistory,
    String? historyError,
  }) {
    return UploadState(
      fileItems: fileItems ?? this.fileItems,
      isUploading: isUploading ?? this.isUploading,
      isProcessing: isProcessing ?? this.isProcessing,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      processingStatus: processingStatus ?? this.processingStatus,
      error: error,
      hasDuplicate: hasDuplicate ?? this.hasDuplicate,
      historyData: historyData ?? this.historyData,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      historyError: historyError,
    );
  }
}

class UploadNotifier extends StateNotifier<UploadState> {
  final UploadRepository _repository;
  final BackgroundTaskNotifier _backgroundTask;
  Timer? _pollingTimer;

  UploadNotifier(this._repository, this._backgroundTask) : super(UploadState());

  Future<void> loadHistory() async {
    state = state.copyWith(isLoadingHistory: true, historyError: null);
    try {
      final data = await _repository.getUploadHistory();
      final historyResponse = UploadHistoryResponse.fromJson(data);
      state = state.copyWith(
        isLoadingHistory: false,
        historyData: historyResponse,
        historyError: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingHistory: false,
        historyError: e.toString(),
      );
    }
  }

  Future<void> addFiles(List<XFile> newFiles) async {
    final existingNames = state.fileItems.map((f) => f.name).toSet();
    final newItems = <UploadFileItem>[];

    for (final file in newFiles) {
      if (existingNames.contains(file.name)) continue;
      int? size;
      try {
        size = await File(file.path).length();
      } catch (_) {}
      newItems.add(UploadFileItem(
        path: file.path,
        name: file.name,
        sizeBytes: size,
      ));
    }

    state = state.copyWith(
      fileItems: [...state.fileItems, ...newItems],
      error: null,
    );
  }

  void removeFile(int index) {
    final updated = List<UploadFileItem>.from(state.fileItems);
    updated.removeAt(index);
    state = state.copyWith(fileItems: updated);
  }

  void clearFiles() {
    state = state.copyWith(fileItems: [], error: null, hasDuplicate: false);
  }

  /// Retry only failed files
  Future<void> retryFailed() async {
    final failed = state.fileItems
        .where((f) => f.status == UploadFileStatus.failed)
        .toList();
    if (failed.isEmpty) {
      return;
    }

    // Reset failed items to idle
    final updated = state.fileItems.map((item) {
      if (item.status == UploadFileStatus.failed) {
        return item.copyWith(status: UploadFileStatus.idle);
      }
      return item;
    }).toList();
    state = state.copyWith(fileItems: updated, error: null);

    await uploadAndProcess();
  }

  /// Force-upload all duplicates (bypass duplicate check)
  Future<void> forceUpload() async {
    final updated = state.fileItems.map((item) {
      if (item.status == UploadFileStatus.duplicate) {
        return item.copyWith(status: UploadFileStatus.idle);
      }
      return item;
    }).toList();
    state =
        state.copyWith(fileItems: updated, hasDuplicate: false, error: null);
    await uploadAndProcess(force: true);
  }

  Future<void> uploadAndProcess({bool force = false}) async {
    final toUpload = state.fileItems
        .where((f) => f.status == UploadFileStatus.idle)
        .toList();
    if (toUpload.isEmpty) return;

    // Mark all pending as uploading
    final uploading = state.fileItems.map((item) {
      if (item.status == UploadFileStatus.idle) {
        return item.copyWith(status: UploadFileStatus.uploading);
      }
      return item;
    }).toList();

    state = state.copyWith(
      fileItems: uploading,
      isUploading: true,
      error: null,
      uploadProgress: 0.0,
      processingStatus: null,
      hasDuplicate: false,
    );

    try {
      final xFiles = toUpload.map((f) => XFile(f.path, name: f.name)).toList();

      // 1. Upload files
      final fileKeys = await _repository.uploadFiles(
        xFiles,
        onProgress: (sent, total) {
          state = state.copyWith(uploadProgress: sent / total);
        },
      );

      // Mark as processing
      final processing = state.fileItems.map((item) {
        if (item.status == UploadFileStatus.uploading) {
          return item.copyWith(status: UploadFileStatus.processing);
        }
        return item;
      }).toList();
      state = state.copyWith(
        fileItems: processing,
        isUploading: false,
        isProcessing: true,
      );

      // 2. Start OCR processing
      final initialStatus =
          await _repository.processInvoices(fileKeys, forceUpload: force);
      state = state.copyWith(processingStatus: initialStatus);

      // Handle immediate duplicate detection
      if (initialStatus.status == 'duplicate_detected') {
        final dup = state.fileItems.map((item) {
          if (item.status == UploadFileStatus.processing) {
            return item.copyWith(status: UploadFileStatus.duplicate);
          }
          return item;
        }).toList();
        state = state.copyWith(
          fileItems: dup,
          isProcessing: false,
          hasDuplicate: true,
        );
        return;
      }

      // 3. Poll for completion
      _startPolling(initialStatus.taskId);
    } catch (e) {
      final errorString = e.toString();
      if (errorString.contains('DioException') ||
          errorString.contains('SocketException')) {
        // Queue offline
        await SyncQueueService()
            .queueUpload(toUpload.map((f) => f.path).toList());
        final queued = state.fileItems.map((item) {
          if (item.status == UploadFileStatus.uploading ||
              item.status == UploadFileStatus.processing) {
            return item.copyWith(
              status: UploadFileStatus.failed,
              errorMessage: 'Queued for sync when online',
            );
          }
          return item;
        }).toList();
        state = state.copyWith(
          fileItems: queued,
          isUploading: false,
          isProcessing: false,
        );
        _backgroundTask.completeTask('Offline: Queued for sync');
      } else {
        final failed = state.fileItems.map((item) {
          if (item.status == UploadFileStatus.uploading ||
              item.status == UploadFileStatus.processing) {
            return item.copyWith(
              status: UploadFileStatus.failed,
              errorMessage: errorString.replaceAll('Exception: ', ''),
            );
          }
          return item;
        }).toList();
        state = state.copyWith(
          fileItems: failed,
          isUploading: false,
          isProcessing: false,
          error: errorString.replaceAll('Exception: ', ''),
        );
      }
    }
  }

  void _startPolling(String taskId) {
    _backgroundTask.startTask('Processing Invoices via OCR...');
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final status = await _repository.getProcessStatus(taskId);
        state = state.copyWith(processingStatus: status);
        _backgroundTask.updateTask(status.message);

        if (status.status == 'completed') {
          timer.cancel();
          final done = state.fileItems.map((item) {
            if (item.status == UploadFileStatus.processing) {
              return item.copyWith(status: UploadFileStatus.done);
            }
            return item;
          }).toList();
          state = state.copyWith(fileItems: done, isProcessing: false);
          _backgroundTask.completeTaskWithAction(
            'Invoices Ready for Review',
            'Review',
            () => AppRouter.router.push('/review'),
          );
        } else if (status.status == 'failed') {
          timer.cancel();
          final failed = state.fileItems.map((item) {
            if (item.status == UploadFileStatus.processing) {
              return item.copyWith(
                  status: UploadFileStatus.failed,
                  errorMessage: status.message);
            }
            return item;
          }).toList();
          state = state.copyWith(fileItems: failed, isProcessing: false);
          _backgroundTask.completeTask('OCR processing failed');
        } else if (status.status == 'duplicate_detected') {
          timer.cancel();
          final dup = state.fileItems.map((item) {
            if (item.status == UploadFileStatus.processing) {
              return item.copyWith(status: UploadFileStatus.duplicate);
            }
            return item;
          }).toList();
          state = state.copyWith(
              fileItems: dup, isProcessing: false, hasDuplicate: true);
          _backgroundTask.completeTask('Duplicate invoice detected');
        }
      } catch (e) {
        timer.cancel();
        state =
            state.copyWith(isProcessing: false, error: 'Polling failed: $e');
        _backgroundTask.completeTask('Error during processing');
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}

final uploadProvider =
    StateNotifierProvider<UploadNotifier, UploadState>((ref) {
  final repository = ref.watch(uploadRepositoryProvider);
  final backgroundTask = ref.watch(backgroundTaskProvider.notifier);
  return UploadNotifier(repository, backgroundTask);
});
