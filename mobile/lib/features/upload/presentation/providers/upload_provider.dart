import 'dart:async';
import 'dart:io';
import 'package:cross_file/cross_file.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/upload/data/upload_repository.dart';
import 'package:mobile/features/upload/data/upload_persistence_service.dart';
import 'package:mobile/features/upload/domain/models/upload_models.dart';
import 'package:mobile/features/shared/presentation/providers/background_task_provider.dart';
import 'package:mobile/core/routing/app_router.dart';
import 'package:mobile/core/network/sync_queue_service.dart';

final uploadRepositoryProvider = Provider<UploadRepository>((ref) {
  return UploadRepository();
});

class UploadState {
  /// Rich per-file items
  final List<UploadFileItem> fileItems;

  /// Legacy compatibility
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

  /// Active task ID — stored in-memory AND on disk for kill-recovery
  final String? activeTaskId;

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
    this.activeTaskId,
  });

  int get pendingCount =>
      fileItems.where((f) => f.status == UploadFileStatus.idle).length;
  int get failedCount =>
      fileItems.where((f) => f.status == UploadFileStatus.failed).length;
  int get doneCount =>
      fileItems.where((f) => f.status == UploadFileStatus.done).length;
  bool get hasFiles => fileItems.isNotEmpty;
  bool get allDone => fileItems.isNotEmpty && doneCount == fileItems.length;

  /// True when a task is actively running (upload OR processing)
  bool get isActive => isUploading || isProcessing;

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
    String? activeTaskId,
    bool clearActiveTaskId = false,
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
      activeTaskId:
          clearActiveTaskId ? null : (activeTaskId ?? this.activeTaskId),
    );
  }
}

class UploadNotifier extends StateNotifier<UploadState> {
  final UploadRepository _repository;
  final BackgroundTaskNotifier _backgroundTask;
  Timer? _pollingTimer;
  int _consecutivePollingErrors = 0;
  static const int _maxPollingErrors = 3;

  UploadNotifier(this._repository, this._backgroundTask) : super(UploadState());

  // ─────────────────────────── History ────────────────────────────

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

  Future<void> deleteHistoryBatch(List<String> receiptIds) async {
    try {
      await _repository.deleteHistoryBatch(receiptIds);
      await loadHistory();
    } catch (e) {
      state = state.copyWith(historyError: 'Failed to delete batch: $e');
    }
  }

  // ─────────────────────────── File management ────────────────────

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

  /// Safe clear — no-op when a task is active.
  void clearFiles() {
    if (state.isActive) return;
    state = UploadState(
      historyData: state.historyData,
      isLoadingHistory: state.isLoadingHistory,
      historyError: state.historyError,
    );
  }

  /// Force-clear regardless of active state (used in error/duplicate/cancel flows).
  Future<void> forceReset() async {
    _pollingTimer?.cancel();
    _consecutivePollingErrors = 0;
    await UploadPersistenceService.clearTask();
    state = UploadState(
      historyData: state.historyData,
      isLoadingHistory: state.isLoadingHistory,
      historyError: state.historyError,
    );
  }

  // ─────────────────────────── Cold-launch recovery ───────────────

  /// Called from app startup AND from UploadPage.initState.
  /// Checks disk for a persisted task and re-attaches polling if found.
  Future<void> resumeIfActive() async {
    // 1. Already active in memory → just ensure polling is running
    if (state.isProcessing && state.activeTaskId != null) {
      if (_pollingTimer == null || !_pollingTimer!.isActive) {
        _startPolling(state.activeTaskId!);
      }
      return;
    }

    // 2. Already done in memory → navigate to review
    if (state.allDone) {
      await forceReset();
      AppRouter.router.go('/review');
      return;
    }

    // 3. Cold launch: check disk for a task the app left behind
    final savedTaskId = await UploadPersistenceService.loadActiveTaskId();
    if (savedTaskId == null) return;

    final fileCount = await UploadPersistenceService.loadActiveFileCount();

    // Build placeholder file items so the loading overlay shows correct count
    final placeholders = List.generate(
      fileCount,
      (i) => UploadFileItem(
        path: '',
        name: 'order',
        status: UploadFileStatus.processing,
      ),
    );

    state = state.copyWith(
      fileItems: placeholders,
      isProcessing: true,
      isUploading: false,
      activeTaskId: savedTaskId,
    );

    // Re-attach polling — the backend is still running
    _startPolling(savedTaskId);
  }

  // ─────────────────────────── Upload flow ────────────────────────

  Future<void> retryFailed() async {
    final failed = state.fileItems
        .where((f) => f.status == UploadFileStatus.failed)
        .toList();
    if (failed.isEmpty) return;

    final updated = state.fileItems.map((item) {
      if (item.status == UploadFileStatus.failed) {
        return item.copyWith(status: UploadFileStatus.idle);
      }
      return item;
    }).toList();
    state = state.copyWith(fileItems: updated, error: null);
    await uploadAndProcess();
  }

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
    // Guard: don't start a second upload if one is already active
    if (state.isActive) return;

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

      // 1. Upload files to R2
      final fileKeys = await _repository.uploadFiles(
        xFiles,
        onProgress: (sent, total) {
          state = state.copyWith(uploadProgress: sent / total);
        },
      );

      // Transition to processing phase
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

      // 2. Start AI processing
      final initialStatus =
          await _repository.processInvoices(fileKeys, forceUpload: force);

      // ✅ Persist task to disk — survives app kills
      await UploadPersistenceService.saveTask(
        initialStatus.taskId,
        fileCount: toUpload.length,
      );

      state = state.copyWith(
        processingStatus: initialStatus,
        activeTaskId: initialStatus.taskId,
      );

      // Immediate duplicate detection
      if (initialStatus.status == 'duplicate_detected') {
        await _handleDuplicate();
        return;
      }

      // 3. Poll for completion
      _startPolling(initialStatus.taskId);
    } catch (e) {
      await _handleUploadError(e.toString(), toUpload);
    }
  }

  // ─────────────────────────── Polling ────────────────────────────

  void _startPolling(String taskId) {
    _backgroundTask.startTask('Processing your orders…');
    _consecutivePollingErrors = 0;
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final status = await _repository.getProcessStatus(taskId);
        _consecutivePollingErrors = 0; // reset on success
        state = state.copyWith(processingStatus: status);
        _backgroundTask.updateTask(status.message);

        if (status.status == 'completed') {
          timer.cancel();
          await _handleCompleted();
        } else if (status.status == 'failed') {
          timer.cancel();
          await _handleProcessingFailed(status.message);
        } else if (status.status == 'duplicate_detected') {
          timer.cancel();
          await _handleDuplicate();
        }
      } catch (e) {
        _consecutivePollingErrors++;
        // Swallow transient errors — only give up after 3 consecutive failures
        if (_consecutivePollingErrors >= _maxPollingErrors) {
          timer.cancel();
          await UploadPersistenceService.clearTask();
          state = state.copyWith(
            isProcessing: false,
            error:
                'Network issue — please check your connection and try again.',
            clearActiveTaskId: true,
          );
          _backgroundTask.completeTask('Connection issue during processing');
        }
      }
    });
  }

  // ─────────────────────────── Terminal state handlers ────────────

  Future<void> _handleCompleted() async {
    await UploadPersistenceService.clearTask(); // ✅ clean up disk
    final done = state.fileItems.map((item) {
      if (item.status == UploadFileStatus.processing) {
        return item.copyWith(status: UploadFileStatus.done);
      }
      return item;
    }).toList();
    state = state.copyWith(
      fileItems: done,
      isProcessing: false,
      clearActiveTaskId: true,
    );
    _backgroundTask.completeTaskWithAction(
      'Orders ready to review!',
      'Review',
      () => AppRouter.router.go('/review'),
    );
  }

  Future<void> _handleProcessingFailed(String message) async {
    await UploadPersistenceService.clearTask();
    final failed = state.fileItems.map((item) {
      if (item.status == UploadFileStatus.processing) {
        return item.copyWith(
            status: UploadFileStatus.failed, errorMessage: message);
      }
      return item;
    }).toList();
    state = state.copyWith(
      fileItems: failed,
      isProcessing: false,
      clearActiveTaskId: true,
    );
    _backgroundTask.completeTask('Processing failed');
  }

  Future<void> _handleDuplicate() async {
    await UploadPersistenceService.clearTask();
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
      clearActiveTaskId: true,
    );
    _backgroundTask.completeTask('Duplicate order detected');
  }

  Future<void> _handleUploadError(
      String errorString, List<UploadFileItem> toUpload) async {
    await UploadPersistenceService.clearTask();
    if (errorString.contains('DioException') ||
        errorString.contains('SocketException')) {
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
        clearActiveTaskId: true,
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
        clearActiveTaskId: true,
      );
    }
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
