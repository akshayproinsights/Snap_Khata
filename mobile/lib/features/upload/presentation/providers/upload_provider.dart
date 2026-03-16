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

  /// True while the provider is checking disk / backend for an active task.
  /// The UI MUST show a loading screen (NOT the camera page) while this is true.
  final bool isRestoringState;

  // ── Sequential duplicate review queue (mirrors web app logic) ────────────
  /// Full list of duplicate objects returned by backend.
  final List<dynamic> duplicateQueue;

  /// Index of the duplicate currently being reviewed.
  final int currentDuplicateIndex;

  /// R2 file_keys the user chose to SKIP (not re-upload).
  final List<String> filesToSkip;

  /// R2 file_keys the user chose to REPLACE (force-upload over existing).
  final List<String> filesToForceUpload;

  /// All R2 keys that were uploaded in the initial upload phase.
  final List<String> allR2Keys;

  /// Number of skipped duplicates from the current upload session.
  final int skippedDuplicatesCount;

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
    this.isRestoringState = true,
    this.duplicateQueue = const [],
    this.currentDuplicateIndex = 0,
    this.filesToSkip = const [],
    this.filesToForceUpload = const [],
    this.allR2Keys = const [],
    this.skippedDuplicatesCount = 0,
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

  /// The duplicate currently being shown to the user (null when queue exhausted)
  dynamic get currentDuplicate =>
      duplicateQueue.isNotEmpty && currentDuplicateIndex < duplicateQueue.length
          ? duplicateQueue[currentDuplicateIndex]
          : null;

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
    bool? isRestoringState,
    List<dynamic>? duplicateQueue,
    int? currentDuplicateIndex,
    List<String>? filesToSkip,
    List<String>? filesToForceUpload,
    List<String>? allR2Keys,
    int? skippedDuplicatesCount,
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
      isRestoringState: isRestoringState ?? this.isRestoringState,
      duplicateQueue: duplicateQueue ?? this.duplicateQueue,
      currentDuplicateIndex:
          currentDuplicateIndex ?? this.currentDuplicateIndex,
      filesToSkip: filesToSkip ?? this.filesToSkip,
      filesToForceUpload: filesToForceUpload ?? this.filesToForceUpload,
      allR2Keys: allR2Keys ?? this.allR2Keys,
      skippedDuplicatesCount:
          skippedDuplicatesCount ?? this.skippedDuplicatesCount,
    );
  }
}

class UploadNotifier extends Notifier<UploadState> {
  late final UploadRepository _repository;
  late final BackgroundTaskNotifier _backgroundTask;
  Timer? _pollingTimer;
  DateTime? _pollingStartTime;
  int _consecutivePollingErrors = 0;
  static const int _maxPollingErrors = 3;
  bool _isPaused = false;   // true while app is in background
  String? _pausedTaskId;    // task to resume polling when foregrounded

  @override
  UploadState build() {
    _repository = ref.watch(uploadRepositoryProvider);
    _backgroundTask = ref.watch(backgroundTaskProvider.notifier);

    ref.onDispose(() {
      _pollingTimer?.cancel();
    });

    return UploadState();
  }

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

  /// Safe clear — no-op when a task is active OR restoring.
  void clearFiles() {
    if (state.isActive || state.isRestoringState) return;
    state = UploadState(
      historyData: state.historyData,
      isLoadingHistory: state.isLoadingHistory,
      historyError: state.historyError,
      isRestoringState: false,
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
      isRestoringState: false,
      skippedDuplicatesCount: 0,
    );
  }

  /// Called by the upload page when the BACKEND confirms an active task
  /// but the provider doesn't know about it (state was lost).
  /// This directly forces the provider into processing mode and starts polling.
  void forceIntoProcessingState(String taskId, int fileCount) {
    if (state.isProcessing && state.activeTaskId == taskId) {
      return; // already tracking
    }

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
      activeTaskId: taskId,
      isRestoringState: false,
    );

    // Re-persist to disk for future cold launches
    UploadPersistenceService.saveTask(taskId, fileCount: fileCount);

    // Start polling only if not already polling
    if (_pollingTimer == null || !_pollingTimer!.isActive) {
      _startPolling(taskId);
    }
  }

  // ─────────────────────────── Cold-launch & warm-resume recovery ──

  /// Called from app startup, from UploadPage.initState, AND when the user
  /// returns to the app (AppLifecycleState.resumed).
  ///
  /// Three-layer recovery:
  ///  1. In-memory state check (instant — no flicker)
  ///  2. Disk persistence check (SharedPreferences — fast)
  ///  3. Backend check (getRecentTask API — bulletproof)
  Future<void> resumeIfActive() async {
    // ── Layer 1: In-memory checks (synchronous, no async gap) ──────

    // 1a. Already uploading in memory → overlay is already showing
    if (state.isUploading) {
      state = state.copyWith(isRestoringState: false);
      return;
    }

    // 1b. Already processing in memory → just ensure polling is running
    if (state.isProcessing && state.activeTaskId != null) {
      if (_pollingTimer == null || !_pollingTimer!.isActive) {
        _startPolling(state.activeTaskId!);
      }
      state = state.copyWith(isRestoringState: false);
      return;
    }

    // 1c. Already done in memory → navigate to review
    if (state.allDone) {
      state = state.copyWith(isRestoringState: false);
      await forceReset();
      AppRouter.router.go('/review');
      return;
    }

    // 1d. Files stuck in 'uploading' status (interrupted R2 upload)
    final hasStuckUploading =
        state.fileItems.any((f) => f.status == UploadFileStatus.uploading);
    if (hasStuckUploading) {
      final recovered = state.fileItems.map((item) {
        if (item.status == UploadFileStatus.uploading) {
          return item.copyWith(status: UploadFileStatus.idle);
        }
        return item;
      }).toList();
      state = state.copyWith(
        fileItems: recovered,
        isUploading: false,
        isProcessing: false,
        error: null,
        isRestoringState: false,
      );
      return;
    }

    // ── Layer 2+3 require async — set restoring flag FIRST ─────────
    // This prevents the camera page from flashing during disk/backend I/O.
    state = state.copyWith(isRestoringState: true);

    // ── Layer 2: Disk persistence check ────────────────────────────

    // 2a. Check for persisted processing task (task ID on disk)
    final savedTaskId = await UploadPersistenceService.loadActiveTaskId();
    if (savedTaskId != null) {
      final fileCount = await UploadPersistenceService.loadActiveFileCount();
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
        isRestoringState: false,
      );
      _startPolling(savedTaskId);
      return;
    }

    // 2b. Check for interrupted upload-phase (R2 upload was in-flight)
    final hasUploadPhase = await UploadPersistenceService.hasUploadPhase();
    if (hasUploadPhase) {
      final filePaths = await UploadPersistenceService.loadUploadPhaseFiles();
      if (filePaths.isNotEmpty) {
        final items = filePaths.map((p) {
          final name = p.split('/').last.split('\\').last;
          return UploadFileItem(
              path: p, name: name, status: UploadFileStatus.idle);
        }).toList();
        state = state.copyWith(
          fileItems: items,
          isUploading: false,
          isProcessing: false,
          error: null,
          isRestoringState: false,
        );
        // Auto-retry — the user already tapped "Upload"
        await uploadAndProcess();
        return;
      } else {
        await UploadPersistenceService.clearUploadPhase();
      }
    }

    // ── Layer 3: Backend check — ultimate source of truth ──────────
    // Even if local persistence was lost, ask the backend if there's
    // an active task for this user. This covers every edge case.
    try {
      final recentTask = await _repository.getRecentTask();
      final taskStatus = recentTask['status'] as String? ?? '';
      final taskId = recentTask['task_id'] as String? ?? '';

      if (taskId.isNotEmpty &&
          (taskStatus == 'processing' ||
              taskStatus == 'queued' ||
              taskStatus == 'uploading')) {
        // Backend says there IS an active task — show the overlay
        final progress = recentTask['progress'] as Map<String, dynamic>? ?? {};
        final total = progress['total'] as int? ?? 1;

        final placeholders = List.generate(
          total,
          (i) => UploadFileItem(
            path: '',
            name: 'order',
            status: UploadFileStatus.processing,
          ),
        );

        // Re-persist to disk so next resume is faster
        await UploadPersistenceService.saveTask(taskId, fileCount: total);

        state = state.copyWith(
          fileItems: placeholders,
          isProcessing: true,
          isUploading: false,
          activeTaskId: taskId,
          isRestoringState: false,
        );
        _startPolling(taskId);
        return;
      }
    } catch (_) {
      // Network error — can't reach backend. Fall through to idle state.
    }

    // ── Nothing active anywhere — show camera page ─────────────────
    state = state.copyWith(isRestoringState: false);
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

    // ✅ Persist upload-phase BEFORE starting the R2 upload
    await UploadPersistenceService.saveUploadPhase(
      toUpload.map((f) => f.path).toList(),
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

      // ✅ Persist task to disk (also clears upload-phase)
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

  /// Returns the poll interval for a given elapsed time:
  ///   0–30s  → 2s   (fast feedback for the happy path)
  ///   30–120s → 5s  (moderate backoff)
  ///   120s+  → 10s  (slow backoff for long-running tasks)
  Duration _backoffInterval(Duration elapsed) {
    if (elapsed.inSeconds < 30) return const Duration(seconds: 2);
    if (elapsed.inSeconds < 120) return const Duration(seconds: 5);
    return const Duration(seconds: 10);
  }

  void _startPolling(String taskId) {
    _backgroundTask.startTask('Processing your orders…');
    _consecutivePollingErrors = 0;
    _isPaused = false;
    _pausedTaskId = null;
    _pollingStartTime = DateTime.now();
    _pollingTimer?.cancel();
    _scheduleNextPoll(taskId);
  }

  void _scheduleNextPoll(String taskId) {
    _pollingTimer?.cancel();
    final elapsed = DateTime.now().difference(_pollingStartTime ?? DateTime.now());
    _pollingTimer = Timer(_backoffInterval(elapsed), () => _executePoll(taskId));
  }

  Future<void> _executePoll(String taskId) async {
    // ── Paused? Park and wait for resume ──────────────────────────
    if (_isPaused) {
      _pausedTaskId = taskId;
      return;
    }

    // ── CLIENT-SIDE TIMEOUT (5 min) ──────────────────────────────
    // Backend keeps processing regardless — user gets result via
    // resumeIfActive() when they return to the app.
    if (_pollingStartTime != null) {
      final elapsed = DateTime.now().difference(_pollingStartTime!);
      if (elapsed.inMinutes >= 5) {
        _pollingTimer?.cancel();
        await UploadPersistenceService.clearTask();
        state = state.copyWith(
          isProcessing: false,
          error: 'Processing is taking longer than expected. Check back shortly.',
          clearActiveTaskId: true,
        );
        _backgroundTask.completeTask('Processing timed out');
        return;
      }
    }

    try {
      final status = await _repository.getProcessStatus(taskId);
      _consecutivePollingErrors = 0;
      state = state.copyWith(processingStatus: status);
      _backgroundTask.updateTask(status.message);

      if (status.status == 'completed') {
        _pollingTimer?.cancel();
        await _handleCompleted();
      } else if (status.status == 'failed') {
        _pollingTimer?.cancel();
        await _handleProcessingFailed(status.message);
      } else if (status.status == 'duplicate_detected') {
        _pollingTimer?.cancel();
        await _handleDuplicate();
      } else {
        // Still running — schedule next poll with backoff
        _scheduleNextPoll(taskId);
      }
    } catch (e) {
      _consecutivePollingErrors++;
      if (_consecutivePollingErrors >= _maxPollingErrors) {
        _pollingTimer?.cancel();
        await UploadPersistenceService.clearTask();
        state = state.copyWith(
          isProcessing: false,
          error: 'Network issue — please check your connection and try again.',
          clearActiveTaskId: true,
        );
        _backgroundTask.completeTask('Connection issue during processing');
      } else {
        // Transient error — still schedule next poll
        _scheduleNextPoll(taskId);
      }
    }
  }

  /// Called by the page when the app is backgrounded (paused/inactive).
  /// Cancels the active timer so zero requests hit the server in background.
  void pausePolling() {
    if (!state.isProcessing) return;
    _isPaused = true;
    _pausedTaskId = state.activeTaskId;
    _pollingTimer?.cancel();
  }

  /// Called by the page when the app returns to the foreground (resumed).
  /// Fires one immediate poll to sync state, then resumes backoff schedule.
  void resumePolling() {
    if (!_isPaused) return;
    _isPaused = false;
    final taskId = _pausedTaskId ?? state.activeTaskId;
    _pausedTaskId = null;
    if (taskId != null && state.isProcessing) {
      _executePoll(taskId); // immediate sync on return
    }
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
    final dupStatus = state.processingStatus;
    final duplicates = List<dynamic>.from(dupStatus?.duplicates ?? []);

    final int skippedCount = duplicates.length;

    final done = state.fileItems.map((item) {
      if (item.status == UploadFileStatus.processing) {
        return item.copyWith(status: UploadFileStatus.done);
      }
      return item;
    }).toList();

    state = state.copyWith(
      fileItems: done,
      isProcessing: false,
      hasDuplicate: false, // We aren't showing the queue anymore
      clearActiveTaskId: true,
      skippedDuplicatesCount: skippedCount,
      // no need to set duplicateQueue, etc. since we're done
    );
    _backgroundTask.completeTaskWithAction(
      'Orders ready to review!',
      'Review',
      () =>
          AppRouter.router.go('/review', extra: {'skippedCount': skippedCount}),
    );
  }

  // ─────────────────────────── Sequential duplicate review ────────────────

  /// User tapped "Skip" — do not re-upload this file.
  void skipCurrentDuplicate() {
    final current = state.currentDuplicate;
    if (current == null) return;
    final fileKey =
        (current as Map<String, dynamic>)['file_key'] as String? ?? '';
    final updatedSkip = [
      ...state.filesToSkip,
      if (fileKey.isNotEmpty) fileKey,
    ];
    final nextIndex = state.currentDuplicateIndex + 1;

    if (nextIndex >= state.duplicateQueue.length) {
      state = state.copyWith(
        filesToSkip: updatedSkip,
        currentDuplicateIndex: nextIndex,
      );
      finishDuplicateReview();
    } else {
      state = state.copyWith(
        filesToSkip: updatedSkip,
        currentDuplicateIndex: nextIndex,
      );
    }
  }

  /// User tapped "Replace Old" — force-overwrite the existing DB record.
  void replaceCurrentDuplicate() {
    final current = state.currentDuplicate;
    if (current == null) return;
    final fileKey =
        (current as Map<String, dynamic>)['file_key'] as String? ?? '';
    final updatedForce = [
      ...state.filesToForceUpload,
      if (fileKey.isNotEmpty) fileKey,
    ];
    final nextIndex = state.currentDuplicateIndex + 1;

    if (nextIndex >= state.duplicateQueue.length) {
      state = state.copyWith(
        filesToForceUpload: updatedForce,
        currentDuplicateIndex: nextIndex,
      );
      finishDuplicateReview();
    } else {
      state = state.copyWith(
        filesToForceUpload: updatedForce,
        currentDuplicateIndex: nextIndex,
      );
    }
  }

  /// Called after every duplicate in the queue has been reviewed.
  /// Mirrors processRemainingFiles() in the web app.
  Future<void> finishDuplicateReview() async {
    final forceList = state.filesToForceUpload;

    // All files that need processing = non-duplicates files + chosen replacements.
    // Since the backend already knows about the R2 keys, just re-submit
    // the force-upload list (non-duplicates were already handled before the
    // duplicate was found, so we only need to process the forced ones).
    final toProcess = [...forceList];

    // Clear duplicate UI state immediately so camera screen shows
    state = state.copyWith(
      hasDuplicate: false,
      duplicateQueue: [],
      currentDuplicateIndex: 0,
      filesToSkip: [],
      filesToForceUpload: [],
      allR2Keys: [],
    );

    if (toProcess.isEmpty) {
      // Nothing to process — go back to clean camera state
      await forceReset();
      return;
    }

    try {
      final processing = state.fileItems.map((item) {
        if (item.status == UploadFileStatus.duplicate ||
            item.status == UploadFileStatus.idle) {
          return item.copyWith(status: UploadFileStatus.processing);
        }
        return item;
      }).toList();
      state = state.copyWith(
        fileItems: processing,
        isProcessing: true,
        error: null,
      );

      final taskStatus =
          await _repository.processInvoices(toProcess, forceUpload: true);
      await UploadPersistenceService.saveTask(
        taskStatus.taskId,
        fileCount: toProcess.length,
      );
      state = state.copyWith(
        processingStatus: taskStatus,
        activeTaskId: taskStatus.taskId,
      );
      _startPolling(taskStatus.taskId);
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: 'Could not process remaining orders. Please try again.',
      );
    }
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
}

final uploadProvider =
    NotifierProvider<UploadNotifier, UploadState>(UploadNotifier.new);
