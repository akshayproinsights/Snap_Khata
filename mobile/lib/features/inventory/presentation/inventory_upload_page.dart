import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/inventory/presentation/providers/inventory_upload_provider.dart';
import 'package:mobile/features/shared/presentation/widgets/recent_tasks_list.dart';
import 'package:path/path.dart' as p;

class InventoryUploadPage extends ConsumerStatefulWidget {
  const InventoryUploadPage({super.key});

  @override
  ConsumerState<InventoryUploadPage> createState() =>
      _InventoryUploadPageState();
}

class _InventoryUploadPageState extends ConsumerState<InventoryUploadPage> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        final XFile? photo = await _picker.pickImage(
          source: source,
          imageQuality: 60,
          maxWidth: 1536,
          maxHeight: 1536,
        );
        if (photo != null) {
          ref.read(inventoryUploadProvider.notifier).addFiles([photo]);
        }
      } else {
        final List<XFile> images = await _picker.pickMultiImage(
          imageQuality: 60,
          maxWidth: 1536,
          maxHeight: 1536,
        );
        if (images.isNotEmpty) {
          ref.read(inventoryUploadProvider.notifier).addFiles(images);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick images: $e')),
        );
      }
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'pdf', 'xlsx', 'xls'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final newFiles = result.files
            .where((f) => f.path != null)
            .map((f) => XFile(f.path!))
            .toList();
        ref.read(inventoryUploadProvider.notifier).addFiles(newFiles);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick files: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(inventoryUploadProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Upload Inventory',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (uploadState.selectedFiles.isNotEmpty)
            TextButton(
              onPressed: () =>
                  ref.read(inventoryUploadProvider.notifier).clearFiles(),
              child:
                  const Text('Clear', style: TextStyle(color: AppTheme.error)),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Picker Area
              if (uploadState.selectedFiles.isEmpty) _buildEmptyState(),

              // Selected Images Preview
              if (uploadState.selectedFiles.isNotEmpty)
                Expanded(
                    child: _buildImagePreviewGrid(uploadState.selectedFiles)),

              // Upload Progress / Actions
              if (uploadState.selectedFiles.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildActionArea(uploadState),
              ],
              if (uploadState.selectedFiles.isEmpty) ...[
                const SizedBox(height: 24),
                const RecentTasksList(title: 'Recent Uploads'),
              ],
            ],
          ),
        ),
      ),
      // Floating Action Buttons for quick picks when empty
      floatingActionButton: uploadState.selectedFiles.isEmpty
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: 'inv_camera_btn',
                  onPressed: () => _pickImage(ImageSource.camera),
                  backgroundColor: AppTheme.primary,
                  child: const Icon(LucideIcons.camera, color: Colors.white),
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: 'inv_gallery_btn',
                  onPressed: () => _pickImage(ImageSource.gallery),
                  backgroundColor: AppTheme.surface,
                  child: const Icon(LucideIcons.image, color: AppTheme.primary),
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: 'inv_file_btn',
                  onPressed: _pickDocument,
                  backgroundColor: AppTheme.surface,
                  child:
                      const Icon(LucideIcons.fileText, color: AppTheme.primary),
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.packagePlus,
                  size: 64, color: AppTheme.primary),
            ),
            const SizedBox(height: 24),
            const Text(
              'Upload Vendor Bills or CSV',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Snap a photo, select from gallery,\nor upload a CSV/PDF bill.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreviewGrid(List<XFile> files) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Selected Bills (${files.length})',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              IconButton(
                icon:
                    const Icon(LucideIcons.plusCircle, color: AppTheme.primary),
                onPressed: () => _pickImage(ImageSource.gallery),
                tooltip: 'Add More',
              )
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: files.length,
              itemBuilder: (context, index) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildFileThumbnail(files[index]),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => ref
                            .read(inventoryUploadProvider.notifier)
                            .removeFile(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(LucideIcons.x,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileThumbnail(XFile file) {
    final ext = p.extension(file.path).toLowerCase();
    if (ext == '.csv' || ext == '.pdf' || ext == '.xlsx' || ext == '.xls') {
      return Container(
        color: AppTheme.primary.withOpacity(0.1),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              ext == '.csv' || ext == '.xlsx' || ext == '.xls'
                  ? LucideIcons.fileSpreadsheet
                  : LucideIcons.fileText,
              color: AppTheme.primary,
              size: 32,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                p.basename(file.path),
                style:
                    const TextStyle(fontSize: 10, color: AppTheme.textPrimary),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }
    return Image.file(
      File(file.path),
      fit: BoxFit.cover,
    );
  }

  Widget _buildActionArea(InventoryUploadState state) {
    if (state.isUploading || state.isProcessing) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  state.isProcessing
                      ? 'Processing Bills...'
                      : 'Uploading Bills...',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${(state.uploadProgress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                      color: AppTheme.primary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: state.isProcessing ? null : state.uploadProgress,
              backgroundColor: AppTheme.border,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
              borderRadius: BorderRadius.circular(4),
              minHeight: 8,
            ),
            if (state.processingStatus != null) ...[
              const SizedBox(height: 8),
              Text(
                state.processingStatus!['message'] ?? 'Processing...',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ]
          ],
        ),
      );
    }

    if (state.error != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.error.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.alertCircle, color: AppTheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                state.error!,
                style: const TextStyle(color: AppTheme.error, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    if (state.processingStatus?['status'] == 'completed') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(LucideIcons.checkCircle, color: Colors.green),
                SizedBox(width: 12),
                Text('Upload Successful!',
                    style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  ref.read(inventoryUploadProvider.notifier).clearFiles();
                  context.push('/inventory-mapping');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Continue to Mapping'),
              ),
            )
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: () =>
            ref.read(inventoryUploadProvider.notifier).uploadAndProcess(),
        icon: const Icon(LucideIcons.uploadCloud),
        label: const Text('Upload & Process',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
