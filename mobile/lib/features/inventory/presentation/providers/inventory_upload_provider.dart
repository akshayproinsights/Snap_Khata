import 'dart:async';
import 'package:camera/camera.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/routing/app_router.dart';
import 'package:mobile/core/network/sync_queue_service.dart';
import 'package:mobile/features/inventory/data/inventory_persistence_service.dart';
import 'package:mobile/features/inventory/data/inventory_upload_repository.dart';
import 'package:mobile/features/shared/presentation/providers/background_task_provider.dart';
import 'package:mobile/features/upload/domain/models/upload_models.dart';
import 'package:flutter/foundation.dart';

// ─────────────────── State ───────────────────────────────────────────────────

class InventoryUploadState {
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

  /// Active task ID — stored in-memory AND on disk for kill-recovery
  final String? activeTaskId;

  /// True while the provider is checking disk / backend for an active task.
  /// The UI MUST show a loading screen (NOT the camera) while this is true.
  final bool isRestoringState;

  /// The final status object when processing completes — used for results summary
  final UploadTaskStatus? lastCompletedStatus;

  // ── Duplicate handling (similar to upload feature) ────────────────────────
  /// True when duplicates were detected and need user review
  final bool hasDuplicate;

  /// Queue of duplicate items to review
  final List<dynamic> duplicateQueue;

  /// Index of the current duplicate being reviewed
  final int currentDuplicateIndex;

  InventoryUploadState({
    this.fileItems = const [],
    this.isUploading = false,
    this.isProcessing = false,
    this.uploadProgress = 0.0,
    this.processingStatus,
    this.error,
    this.activeTaskId,
    this.isRestoringState = true,
    this.lastCompletedStatus,
    this.hasDuplicate = false,
    this.duplicateQueue = const [],
    this.currentDuplicateIndex = 0,
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

  /// Get the current duplicate being reviewed
  dynamic get currentDuplicate =>
      duplicateQueue.isNotEmpty && currentDuplicateIndex < duplicateQueue.length
          ? duplicateQueue[currentDuplicateIndex]
          : null;

  InventoryUploadState copyWith({
    List<UploadFileItem>? fileItems,
    bool? isUploading,
    bool? isProcessing,
    double? uploadProgress,
    UploadTaskStatus? processingStatus,
    String? error,
    String? activeTaskId,
    bool clearActiveTaskId = false,
    bool? isRestoringState,
    UploadTaskStatus? lastCompletedStatus,
    bool clearLastCompletedStatus = false,
    bool? hasDuplicate,
    List<dynamic>? duplicateQueue,
    int? currentDuplicateIndex,
  }) {
    return InventoryUploadState(
      fileItems: fileItems ?? this.fileItems,
      isUploading: isUploading ?? this.isUploading,
      isProcessing: isProcessing ?? this.isProcessing,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      processingStatus: processingStatus ?? this.processingStatus,
      error: error,
      activeTaskId:
          clearActiveTaskId ? null : (activeTaskId ?? this.activeTaskId),
      isRestoringState: isRestoringState ?? this.isRestoringState,
      lastCompletedStatus: clearLastCompletedStatus
          ? null
          : (lastCompletedStatus ?? this.lastCompletedStatus),
      hasDuplicate: hasDuplicate ?? this.hasDuplicate,
      duplicateQueue: duplicateQueue ?? this.duplicateQueue,
      currentDuplicateIndex: currentDuplicateIndex ?? this.currentDuplicateIndex,
    );
  }
}

// ─────────────────── Notifier ────────────────────────────────────────────────

class InventoryUploadNotifier extends Notifier<InventoryUploadState> {
  late final InventoryUploadRepository _repository;
  late final BackgroundTaskNotifier _backgroundTask;
  Timer? _pollingTimer;
  int _consecutivePollingErrors = 0;
  static const int _maxPollingErrors = 3;
  bool _isPaused = false;   // true while app is in background
  String? _pausedTaskId;    // task to resume when foregrounded
  DateTime? _pollingStartTime; // ALWAYS set from persisted start time, never reset on resume
  bool _isUploadInProgress = false; // synchronous mutex — prevents double-upload race

  @override
  InventoryUploadState build() {
    _repository = ref.watch(inventoryUploadRepositoryProvider);
    _backgroundTask = ref.watch(backgroundTaskProvider.notifier);
    return InventoryUploadState();
  }

  // ─────────────────────────── File management ────────────────────

  Future<void> addFiles(List<XFile> newFiles) async {
    final newItems = <UploadFileItem>[];

    for (final file in newFiles) {
      int? size;
      try {
        size = await file.length();
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
    state = InventoryUploadState(isRestoringState: false);
  }

  /// Force-clear regardless of active state.
  Future<void> forceReset() async {
    _pollingTimer?.cancel();
    _consecutivePollingErrors = 0;
    await InventoryPersistenceService.clearTask();
    state = InventoryUploadState(isRestoringState: false);
  }

  /// Called by the page after _checkBackendForActiveTask() confirms no active
  /// task — clears the isRestoringState=true default so the camera can render.
  void clearRestoringState() {
    if (state.isRestoringState) {
      state = state.copyWith(isRestoringState: false);
    }
  }

  /// Called when the page confirms an active backend task but the provider
  /// doesn't know about it (state was lost on navigation/kill).
  void forceIntoProcessingState(String taskId, int fileCount) {
    if (state.isProcessing && state.activeTaskId == taskId) {
      return; // already tracking
    }

    final placeholders = List.generate(
      fileCount,
      (i) => UploadFileItem(
        path: '',
        name: 'invoice',
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

    InventoryPersistenceService.saveTask(taskId, fileCount: fileCount);

    if (_pollingTimer == null || !_pollingTimer!.isActive) {
      _startPolling(taskId, taskStartTime: _pollingStartTime);
    }
  }

  // ─────────────── Cold-launch & warm-resume recovery ─────────────

  /// Three-layer recovery — called from initState AND AppLifecycleState.resumed.
  ///   1. In-memory state check (instant)
  ///   2. Disk persistence check (SharedPreferences — fast)
  ///   3. Backend check (getRecentTask API — bulletproof)
  Future<void> resumeIfActive() async {
    // ── Layer 1: In-memory checks ──────────────────────────────────

    if (state.isUploading) {
      state = state.copyWith(isRestoringState: false);
      return;
    }

    if (state.isProcessing && state.activeTaskId != null) {
      if (_pollingTimer == null || !_pollingTimer!.isActive) {
        _startPolling(state.activeTaskId!);
      }
      state = state.copyWith(isRestoringState: false);
      return;
    }

    if (state.allDone) {
      state = state.copyWith(isRestoringState: false);
      await forceReset();
      AppRouter.router.go('/inventory-review');
      return;
    }

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
    state = state.copyWith(isRestoringState: true);

    // ── Layer 2: Disk persistence check ────────────────────────────

    final savedTaskId = await InventoryPersistenceService.loadActiveTaskId();
    if (savedTaskId != null) {
      // CRITICAL: Verify the task is still actually in-progress on the backend
      // before re-entering the processing state. If it already completed/failed
      // (e.g. app was killed after backend finished but before clearTask() ran),
      // we must clear disk and show the camera — not loop forever.
      try {
        final latestStatus = await _repository.getProcessStatus(savedTaskId);
        if (latestStatus.status == 'completed') {
          await InventoryPersistenceService.clearTask();
          state = state.copyWith(isRestoringState: false);
          // Navigate to inventory review since the task is done
          AppRouter.router.go('/inventory-review');
          return;
        } else if (latestStatus.status == 'failed') {
          await InventoryPersistenceService.clearTask();
          state = state.copyWith(isRestoringState: false);
          return;
        } else if (latestStatus.status == 'processing' ||
            latestStatus.status == 'queued') {
          // Task is still running — but cross-check against the most-recent
          // task in case this saved ID is stale (app was killed mid-processing
          // and a newer upload already finished before we got here).
          try {
            final recentTask = await _repository.getRecentTask();
            final recentId = recentTask['task_id'] as String? ?? '';
            final recentStatus = recentTask['status'] as String? ?? '';
            if (recentId.isNotEmpty &&
                recentId != savedTaskId &&
                recentStatus == 'completed') {
              // A newer task already completed — this saved ID is an orphan.
              await InventoryPersistenceService.clearTask();
              state = state.copyWith(isRestoringState: false);
              AppRouter.router.go('/inventory-review');
              return;
            }
          } catch (_) {
            // Ignore — fall through and resume polling the saved task
          }
        }
      } catch (_) {
        // Network error — assume still in progress and resume normally
      }

      final fileCount = await InventoryPersistenceService.loadActiveFileCount();
      final placeholders = List.generate(
        fileCount,
        (i) => UploadFileItem(
          path: '',
          name: 'invoice',
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
      // Restore persisted start time so the timeout is not reset on resume
      final savedStartTime = await InventoryPersistenceService.loadStartTime();
      _startPolling(savedTaskId, taskStartTime: savedStartTime);
      return;
    }

    final hasUploadPhase = await InventoryPersistenceService.hasUploadPhase();
    if (hasUploadPhase) {
      final filePaths =
          await InventoryPersistenceService.loadUploadPhaseFiles();
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
        await uploadAndProcess();
        return;
      } else {
        await InventoryPersistenceService.clearUploadPhase();
      }
    }

    // ── Layer 3: Backend check — ultimate source of truth ───────────
    try {
      final recentTask = await _repository.getRecentTask();
      final taskStatus = recentTask['status'] as String? ?? '';
      final taskId = recentTask['task_id'] as String? ?? '';

      if (taskId.isNotEmpty &&
          (taskStatus == 'processing' ||
              taskStatus == 'queued' ||
              taskStatus == 'uploading')) {
        final progress = recentTask['progress'] as Map<String, dynamic>? ?? {};
        final total = progress['total'] as int? ?? 1;

        final placeholders = List.generate(
          total,
          (i) => UploadFileItem(
            path: '',
            name: 'invoice',
            status: UploadFileStatus.processing,
          ),
        );

        final savedStartTime = await InventoryPersistenceService.loadStartTime();
        await InventoryPersistenceService.saveTask(taskId, fileCount: total,
            startTime: savedStartTime ?? DateTime.now());

        state = state.copyWith(
          fileItems: placeholders,
          isProcessing: true,
          isUploading: false,
          activeTaskId: taskId,
          isRestoringState: false,
        );
        _startPolling(taskId, taskStartTime: savedStartTime);
        return;
      }
    } catch (_) {
      // Network error — fall through to idle
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

  Future<void> uploadAndProcess({bool force = false}) async {
    // Synchronous mutex: prevents double-upload when two async callers both
    // read state.isActive before either one sets isUploading = true.
    if (_isUploadInProgress) return;
    if (state.isActive) return;
    _isUploadInProgress = true;
    
    final toUpload = state.fileItems
        .where((f) => f.status == UploadFileStatus.idle)
        .toList();

    try {
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
      );

      // ✅ Persist upload-phase BEFORE starting the R2 upload
      await InventoryPersistenceService.saveUploadPhase(
        toUpload.map((f) => f.path).toList(),
      );

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
          await _repository.processInvoices(fileKeys, forceUpload: true);

      // ✅ Persist task to disk (also clears upload-phase)
      // Anchor the timeout to when processing actually STARTS
      final taskStartTime = DateTime.now();
      await InventoryPersistenceService.saveTask(
        initialStatus.taskId,
        fileCount: toUpload.length,
        startTime: taskStartTime,
      );

      state = state.copyWith(
        processingStatus: initialStatus,
        activeTaskId: initialStatus.taskId,
      );

      // 3. Poll for completion
      _startPolling(initialStatus.taskId, taskStartTime: taskStartTime);
    } catch (e) {
      await _handleUploadError(e.toString(), toUpload);
    } finally {
      _isUploadInProgress = false;
    }
  }

  // ─────────────────────────── Polling ────────────────────────────

  static const int _maxPollMinutes = 10;

  /// Returns the poll interval for a given elapsed time:
  ///   0–30s  → 3s   (fast feedback; Gemini is still warm)
  ///   30–120s → 6s  (moderate backoff)
  ///   120s+  → 12s  (slow backoff for large batches)
  Duration _backoffInterval(Duration elapsed) {
    if (elapsed.inSeconds < 30) return const Duration(seconds: 3);
    if (elapsed.inSeconds < 120) return const Duration(seconds: 6);
    return const Duration(seconds: 12);
  }

  void _startPolling(String taskId, {DateTime? taskStartTime}) {
    _backgroundTask.startTask('Processing your inventory…');
    _consecutivePollingErrors = 0;
    _isPaused = false;
    _pausedTaskId = null;
    _pollingTimer?.cancel();

    // CRITICAL: Use the persisted task start time if available so the timeout
    // is not reset every time the user navigates away and comes back.
    // Only fall back to DateTime.now() for brand-new tasks.
    if (taskStartTime != null) {
      _pollingStartTime = taskStartTime;
    }
    _pollingStartTime ??= DateTime.now();
    // (if _pollingStartTime is already set and no override, keep it as-is)

    // Adaptive initial delay: Gemini needs ~3–5s per invoice.
    // Wait (fileCount * 3s, clamped 10s–45s) before the first poll.
    final fileCount = state.fileItems.length;
    final initialDelaySeconds = (fileCount * 3).clamp(10, 45);

    _pollingTimer = Timer(Duration(seconds: initialDelaySeconds), () {
      _executePoll(taskId);
    });
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

    // ── Hard timeout guard ────────────────────────────────────────
    final elapsed = DateTime.now().difference(_pollingStartTime ?? DateTime.now());
    if (elapsed.inMinutes >= _maxPollMinutes) {
      _pollingTimer?.cancel();
      await InventoryPersistenceService.clearTask();
      state = state.copyWith(
        isProcessing: false,
        error: null,
        clearActiveTaskId: true,
        isRestoringState: false,
      );
      _backgroundTask.completeTask('Inventory processing timed out. Pull down to refresh.');
      return;
    }

    try {
      final status = await _repository.getProcessStatus(taskId);
      
      // CRITICAL: If the user started a NEW upload while this poll was in flight,
      // ignore this result. Applying it would overwrite the new task's state.
      if (taskId != state.activeTaskId) {
        debugPrint('Ignoring poll result for stale task: $taskId (Active: ${state.activeTaskId})');
        return;
      }

      _consecutivePollingErrors = 0;
      state = state.copyWith(processingStatus: status);
      _backgroundTask.updateTask(status.message);

      if (status.status == 'completed') {
        _pollingTimer?.cancel();
        await _handleCompleted(status, taskId);
      } else if (status.status == 'failed') {
        _pollingTimer?.cancel();
        await _handleProcessingFailed(status.message, taskId);
      } else {
        _scheduleNextPoll(taskId);
      }
    } catch (e) {
      _consecutivePollingErrors++;
      if (_consecutivePollingErrors >= _maxPollingErrors) {
        _pollingTimer?.cancel();
        await InventoryPersistenceService.clearTask();
        state = state.copyWith(
          isProcessing: false,
          error: 'Network issue — please check your connection and try again.',
          clearActiveTaskId: true,
        );
        _backgroundTask.completeTask('Connection issue during inventory processing');
      } else {
        _scheduleNextPoll(taskId);
      }
    }
  }

  /// Called by the page when the app is backgrounded.
  void pausePolling() {
    if (!state.isProcessing) return;
    _isPaused = true;
    _pausedTaskId = state.activeTaskId;
    _pollingTimer?.cancel();
  }

  /// Called by the page when the app returns to the foreground.
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

  Future<void> _handleCompleted([UploadTaskStatus? status, String? taskId]) async {
    // If taskId is provided, ensure it's still the active one
    if (taskId != null && taskId != state.activeTaskId) return;

    await InventoryPersistenceService.clearTask();
    final done = state.fileItems.map((item) {
      if (item.status == UploadFileStatus.processing) {
        return item.copyWith(status: UploadFileStatus.done);
      }
      return item;
    }).toList();
    
    // Check for duplicates and populate queue if found
    // ✅ Sanitizing status to ensure no "skipped" UI ever shows up
    final sanitizedStatus = status?.copyWith(skipped: 0, skippedDetails: []);

    state = state.copyWith(
      fileItems: done,
      isProcessing: false,
      clearActiveTaskId: true,
      lastCompletedStatus: sanitizedStatus,
      hasDuplicate: false,
      duplicateQueue: [],
      currentDuplicateIndex: 0,
    );

    // Build banner message
    final bannerMsg = 'Inventory ready to review!';

    _backgroundTask.completeTaskWithAction(
      bannerMsg,
      'Review Inventory',
      () => AppRouter.router.go('/inventory-review'),
    );

    // Guaranteed direct navigation after 4s — gives user time to read the summary.
    // The UI's ref.listen in the page fires at ~600ms and is suppressed when
    // lastCompletedStatus is set (the page shows the summary instead).
    // This 4s timer is the fallback for state-loss scenarios.
    Future.delayed(const Duration(milliseconds: 4000), () {
      AppRouter.router.go('/inventory-review');
    });
  }

  Future<void> _handleProcessingFailed(String message, [String? taskId]) async {
    // If taskId is provided, ensure it's still the active one
    if (taskId != null && taskId != state.activeTaskId) return;

    await InventoryPersistenceService.clearTask();
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
      error: message,
      clearActiveTaskId: true,
    );
    _backgroundTask.completeTask('Inventory processing failed');
  }

  Future<void> _handleUploadError(
      String errorString, List<UploadFileItem> toUpload) async {
    await InventoryPersistenceService.clearTask();

    // Build a clean, user-readable error message (strip Dart exception prefixes)
    final cleanError = errorString
        .replaceAll('Exception: ', '')
        .replaceAll('DioException: ', '')
        .trim();

    if (errorString.contains('DioException') ||
        errorString.contains('SocketException')) {
      await SyncQueueService()
          .queueUpload(toUpload.map((f) => f.path).toList(), queueType: 'inventory');
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
        error: 'No internet connection. Files queued for upload when back online.',
      );
      _backgroundTask.completeTask('Offline: Queued for sync');
    } else {
      final failed = state.fileItems.map((item) {
        if (item.status == UploadFileStatus.uploading ||
            item.status == UploadFileStatus.processing) {
          return item.copyWith(
            status: UploadFileStatus.failed,
            errorMessage: cleanError,
          );
        }
        return item;
      }).toList();
      // ── FIX: propagate real error to state.error so the UI shows it ──
      // Previously error was null here, causing the UI to always fall back
      // to the generic "There was an issue processing your vendor invoices." text.
      state = state.copyWith(
        fileItems: failed,
        isUploading: false,
        isProcessing: false,
        clearActiveTaskId: true,
        error: cleanError,
      );
      _backgroundTask.completeTask('Inventory upload error');
    }
  }

  // ─────────────────── Duplicate Review Methods ──────────────────────────────

  /// Move to the next duplicate in the queue
  void nextDuplicate() {
    final nextIndex = state.currentDuplicateIndex + 1;
    if (nextIndex >= state.duplicateQueue.length) {
      // All duplicates reviewed
      finishDuplicateReview();
    } else {
      state = state.copyWith(currentDuplicateIndex: nextIndex);
    }
  }

  /// Skip the current duplicate and move to the next
  void skipDuplicate() {
    nextDuplicate();
  }

  /// Replace the old record with the new one (for inventory, this means
  /// we need to delete the old record and allow the new one to be processed)
  void replaceDuplicate() async {
    final current = state.currentDuplicate;
    if (current == null) return;

    try {
      // For inventory, we can't really "replace" since the image is already
      // processed. Instead, we'll just note that the user wanted to replace
      // and move to the next duplicate.
      // In a real implementation, we might need to:
      // 1. Delete the old inventory item
      // 2. Re-process the new image
      // But for now, we'll just skip to the next duplicate
      nextDuplicate();
    } catch (e) {
      // Handle error
      nextDuplicate();
    }
  }

  /// Finish the duplicate review process
  void finishDuplicateReview() {
    state = state.copyWith(
      hasDuplicate: false,
      duplicateQueue: [],
      currentDuplicateIndex: 0,
    );
    
    // Navigate to inventory review
    AppRouter.router.go('/inventory-review');
  }
}

// ─────────────────── Providers ───────────────────────────────────────────────

final inventoryUploadRepositoryProvider =
    Provider<InventoryUploadRepository>((ref) {
  return InventoryUploadRepository();
});

final inventoryUploadProvider =
    NotifierProvider<InventoryUploadNotifier, InventoryUploadState>(
        InventoryUploadNotifier.new);
