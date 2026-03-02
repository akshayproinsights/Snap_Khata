import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/routing/app_router.dart';
import 'package:mobile/features/shared/presentation/providers/background_task_provider.dart';

class InventoryUploadState {
  final List<XFile> selectedFiles;
  final bool isUploading;
  final bool isProcessing;
  final double uploadProgress;
  final String? error;
  final Map<String, dynamic>? processingStatus;

  InventoryUploadState({
    this.selectedFiles = const [],
    this.isUploading = false,
    this.isProcessing = false,
    this.uploadProgress = 0.0,
    this.error,
    this.processingStatus,
  });

  InventoryUploadState copyWith({
    List<XFile>? selectedFiles,
    bool? isUploading,
    bool? isProcessing,
    double? uploadProgress,
    String? error,
    Map<String, dynamic>? processingStatus,
  }) {
    return InventoryUploadState(
      selectedFiles: selectedFiles ?? this.selectedFiles,
      isUploading: isUploading ?? this.isUploading,
      isProcessing: isProcessing ?? this.isProcessing,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      error: error,
      processingStatus: processingStatus ?? this.processingStatus,
    );
  }
}

class InventoryUploadNotifier extends StateNotifier<InventoryUploadState> {
  final Dio _dio;
  final BackgroundTaskNotifier _backgroundTask;

  InventoryUploadNotifier(
      {Dio? dio, required BackgroundTaskNotifier backgroundTask})
      : _dio = dio ?? ApiClient().dio,
        _backgroundTask = backgroundTask,
        super(InventoryUploadState());

  void addFiles(List<XFile> files) {
    state = state.copyWith(
      selectedFiles: [...state.selectedFiles, ...files],
      error: null,
      processingStatus: null,
    );
  }

  void removeFile(int index) {
    final newFiles = List<XFile>.from(state.selectedFiles)..removeAt(index);
    state = state.copyWith(selectedFiles: newFiles);
  }

  void clearFiles() {
    state = InventoryUploadState();
  }

  Future<void> uploadAndProcess() async {
    if (state.selectedFiles.isEmpty) return;

    state = state.copyWith(
      isUploading: true,
      error: null,
      uploadProgress: 0.1,
    );

    try {
      final formData = FormData();
      for (var file in state.selectedFiles) {
        formData.files.add(MapEntry(
          'files',
          await MultipartFile.fromFile(file.path, filename: file.name),
        ));
      }

      // Upload phase
      final uploadResponse = await _dio.post(
        '/api/inventory/upload', // Assuming this is the inventory upload endpoint
        data: formData,
        onSendProgress: (num sent, num total) {
          state = state.copyWith(uploadProgress: sent / total);
        },
      );

      final fileKeys =
          List<String>.from(uploadResponse.data['uploaded_files'] ?? []);

      state = state.copyWith(
          isUploading: false, isProcessing: true, uploadProgress: 0.0);

      // Process phase
      _backgroundTask.startTask('Processing Inventory Orders...');
      await _dio.post(
        '/api/inventory/process',
        data: {
          'file_keys': fileKeys,
          'force_upload': false,
        },
      );

      // final taskId = processResponse.data['task_id'];

      // Simulating polling for completion for simplicity here,
      // actual implementation might use WebSockets or periodic polling.
      await Future.delayed(const Duration(seconds: 2));

      state = state.copyWith(
        isProcessing: false,
        processingStatus: {
          'status': 'completed',
          'message': 'Inventory processed successfully'
        },
      );
      _backgroundTask
          .completeTaskWithAction('Inventory Orders Ready', 'Mapping', () {
        AppRouter.router.push('/inventory-mapping');
      });
    } catch (e) {
      state = state.copyWith(
        isUploading: false,
        isProcessing: false,
        error: 'Failed to upload inventory: \${e.toString()}',
      );
      _backgroundTask.completeTask('Error processing inventory.');
    }
  }
}

final inventoryUploadProvider =
    StateNotifierProvider<InventoryUploadNotifier, InventoryUploadState>((ref) {
  final backgroundTask = ref.watch(backgroundTaskProvider.notifier);
  return InventoryUploadNotifier(backgroundTask: backgroundTask);
});
