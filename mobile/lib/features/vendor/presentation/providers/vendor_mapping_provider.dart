import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'package:mobile/features/vendor/data/vendor_mapping_repository.dart';
import 'package:mobile/features/vendor/domain/models/vendor_mapping_models.dart';

final vendorMappingRepositoryProvider =
    Provider((ref) => VendorMappingRepository());

class VendorMappingState {
  final List<VendorMappingExportItem> exportItems;
  final bool isLoadingExport;

  final List<VendorMappingEntry> reviewQueue;

  final List<XFile> uploadedFiles;
  final bool isUploading;
  final String
      processingStatus; // idle, uploading, processing, queued, completed, failed
  final double uploadProgress;
  final String? activeTaskId;
  final String? error;

  VendorMappingState({
    this.exportItems = const [],
    this.isLoadingExport = false,
    this.reviewQueue = const [],
    this.uploadedFiles = const [],
    this.isUploading = false,
    this.processingStatus = 'idle',
    this.uploadProgress = 0.0,
    this.activeTaskId,
    this.error,
  });

  VendorMappingState copyWith({
    List<VendorMappingExportItem>? exportItems,
    bool? isLoadingExport,
    List<VendorMappingEntry>? reviewQueue,
    List<XFile>? uploadedFiles,
    bool? isUploading,
    String? processingStatus,
    double? uploadProgress,
    String? activeTaskId,
    String? error,
  }) {
    return VendorMappingState(
      exportItems: exportItems ?? this.exportItems,
      isLoadingExport: isLoadingExport ?? this.isLoadingExport,
      reviewQueue: reviewQueue ?? this.reviewQueue,
      uploadedFiles: uploadedFiles ?? this.uploadedFiles,
      isUploading: isUploading ?? this.isUploading,
      processingStatus: processingStatus ?? this.processingStatus,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      activeTaskId: activeTaskId ?? this.activeTaskId,
      error: error,
    );
  }
}

class VendorMappingNotifier extends Notifier<VendorMappingState> {
  late final VendorMappingRepository _repository;
  Timer? _pollingTimer;
  int _consecutivePollingErrors = 0;
  static const int _maxPollingErrors = 3;
  static const int _maxPollSeconds = 90; // vendor mapping is fast (10-30s typical)
  bool _isPaused = false;
  String? _pausedTaskId;
  DateTime? _pollingStartTime;

  @override
  VendorMappingState build() {
    _repository = ref.watch(vendorMappingRepositoryProvider);

    ref.onDispose(() {
      _pollingTimer?.cancel();
    });

    // Initialize data asynchronously after build
    Future.microtask(() => fetchExportData());
    return VendorMappingState();
  }

  Future<void> fetchExportData() async {
    state = state.copyWith(isLoadingExport: true, error: null);
    try {
      final data = await _repository.getExportData();
      final items = data['items'] as List<VendorMappingExportItem>;
      state = state.copyWith(exportItems: items, isLoadingExport: false);
    } catch (e) {
      state = state.copyWith(isLoadingExport: false, error: e.toString());
    }
  }

  void addToReviewQueue(VendorMappingEntry entry) {
    state = state.copyWith(reviewQueue: [...state.reviewQueue, entry]);
  }

  void updateReviewItem(int index, VendorMappingEntry updatedEntry) {
    final queue = List<VendorMappingEntry>.from(state.reviewQueue);
    queue[index] = updatedEntry;
    state = state.copyWith(reviewQueue: queue);
  }

  void removeFromReviewQueue(int index) {
    final queue = List<VendorMappingEntry>.from(state.reviewQueue);
    queue.removeAt(index);
    state = state.copyWith(reviewQueue: queue);
  }

  void addFiles(List<XFile> files) {
    state = state.copyWith(uploadedFiles: [...state.uploadedFiles, ...files]);
  }

  void removeFile(int index) {
    final files = List<XFile>.from(state.uploadedFiles);
    files.removeAt(index);
    state = state.copyWith(uploadedFiles: files);
  }

  void clearFiles() {
    state = state.copyWith(uploadedFiles: []);
  }

  Future<void> uploadAndProcessScans() async {
    if (state.uploadedFiles.isEmpty) return;

    state = state.copyWith(
      isUploading: true,
      processingStatus: 'uploading',
      uploadProgress: 0,
      error: null,
    );

    try {
      // 1. Upload
      final uploadRes = await _repository.uploadScans(
        state.uploadedFiles,
        onProgress: (sent, total) {
          state = state.copyWith(uploadProgress: sent / total);
        },
      );

      if (uploadRes['success'] != true) throw Exception(uploadRes['message']);
      final fileKeys = List<String>.from(uploadRes['uploaded_files'] ?? []);

      // 2. Process
      final processRes = await _repository.processScans(fileKeys);
      state = state.copyWith(
        activeTaskId: processRes['task_id'],
        processingStatus: processRes['status'],
        isUploading: false,
      );

      _startPolling(processRes['task_id']);
    } catch (e) {
      state = state.copyWith(
        isUploading: false,
        processingStatus: 'failed',
        error: e.toString(),
      );
    }
  }

  void _startPolling(String taskId) {
    _consecutivePollingErrors = 0;
    _isPaused = false;
    _pausedTaskId = null;
    _pollingStartTime = DateTime.now();
    _pollingTimer?.cancel();
    _scheduleNextPoll(taskId);
  }

  Duration _backoffInterval(Duration elapsed) {
    if (elapsed.inSeconds < 30) return const Duration(seconds: 2);
    if (elapsed.inSeconds < 90) return const Duration(seconds: 5);
    return const Duration(seconds: 10);
  }

  void _scheduleNextPoll(String taskId) {
    _pollingTimer?.cancel();
    final elapsed = DateTime.now().difference(_pollingStartTime ?? DateTime.now());
    _pollingTimer = Timer(_backoffInterval(elapsed), () => _executePoll(taskId));
  }

  Future<void> _executePoll(String taskId) async {
    if (_isPaused) { _pausedTaskId = taskId; return; }

    // Hard timeout
    final elapsed = DateTime.now().difference(_pollingStartTime ?? DateTime.now());
    if (elapsed.inSeconds >= _maxPollSeconds) {
      _pollingTimer?.cancel();
      state = state.copyWith(
        processingStatus: 'failed',
        error: 'Processing timed out. Please try again.',
        activeTaskId: null,
      );
      return;
    }

    try {
      final status = await _repository.getProcessStatus(taskId);
      _consecutivePollingErrors = 0;
      final currentStatus = status['status'];
      state = state.copyWith(processingStatus: currentStatus);

      if (currentStatus == 'completed') {
        _pollingTimer?.cancel();
        final rows = status['rows'] as List;
        final entries = rows
            .map((row) => VendorMappingEntry(
                  rowNumber: row['row_number'],
                  vendorDescription: row['vendor_description'],
                  partNumber: row['part_number'],
                  stock: row['stock'],
                  reorder: row['reorder'],
                  notes: row['notes'],
                  status: 'Pending',
                  systemQty: row['system_qty'],
                  variance: row['variance'],
                ))
            .toList();
        state = state.copyWith(
          reviewQueue: [...state.reviewQueue, ...entries],
          uploadedFiles: [],
          activeTaskId: null,
          processingStatus: 'idle',
        );
      } else if (currentStatus == 'failed') {
        _pollingTimer?.cancel();
        state = state.copyWith(
          processingStatus: 'failed',
          error: status['message'],
          activeTaskId: null,
        );
      } else {
        _scheduleNextPoll(taskId);
      }
    } catch (e) {
      _consecutivePollingErrors++;
      if (_consecutivePollingErrors >= _maxPollingErrors) {
        _pollingTimer?.cancel();
        state = state.copyWith(
          processingStatus: 'failed',
          error: 'Network issue — please check your connection.',
          activeTaskId: null,
        );
      } else {
        _scheduleNextPoll(taskId);
      }
    }
  }

  /// Pause polling when the app is backgrounded.
  void pausePolling() {
    if (state.processingStatus == 'idle' || state.processingStatus == 'completed') return;
    _isPaused = true;
    _pausedTaskId = state.activeTaskId;
    _pollingTimer?.cancel();
  }

  /// Resume polling when the app comes back to foreground.
  void resumePolling() {
    if (!_isPaused) return;
    _isPaused = false;
    final taskId = _pausedTaskId ?? state.activeTaskId;
    _pausedTaskId = null;
    if (taskId != null) _executePoll(taskId);
  }

  Future<bool> bulkSaveReviewQueue() async {
    if (state.reviewQueue.isEmpty) return false;
    try {
      await _repository.bulkSaveEntries(state.reviewQueue);
      state = state.copyWith(reviewQueue: []);
      fetchExportData();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<List<String>> searchCustomerItems(String query) async {
    return _repository.searchCustomerItems(query);
  }
}

final vendorMappingProvider =
    NotifierProvider<VendorMappingNotifier, VendorMappingState>(
        VendorMappingNotifier.new);
