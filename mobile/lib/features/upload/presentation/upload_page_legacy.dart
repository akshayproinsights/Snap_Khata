/*
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/upload/domain/models/upload_models.dart';
import 'package:mobile/features/upload/presentation/providers/upload_provider.dart';
import 'package:mobile/features/shared/presentation/widgets/recent_tasks_list.dart';
import 'package:mobile/shared/widgets/app_toast.dart';
import 'package:flutter_animate/flutter_animate.dart';

class UploadPage extends ConsumerStatefulWidget {
  const UploadPage({super.key});

  @override
  ConsumerState<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends ConsumerState<UploadPage> {
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(uploadProvider.notifier).loadHistory();
    });
  }

  Future<void> _pickCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 60,
        maxWidth: 1536,
        maxHeight: 1536,
      );
      if (photo != null && mounted) {
        await ref.read(uploadProvider.notifier).addFiles([photo]);
      }
    } catch (e) {
      if (mounted) AppToast.showError(context, 'Camera error: $e');
    }
  }

  Future<void> _pickGallery() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 60,
        maxWidth: 1536,
        maxHeight: 1536,
      );
      if (images.isNotEmpty && mounted) {
        await ref.read(uploadProvider.notifier).addFiles(images);
      }
    } catch (e) {
      if (mounted) AppToast.showError(context, 'Gallery error: $e');
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (result != null && result.files.isNotEmpty && mounted) {
        final xFiles = result.files
            .where((f) => f.path != null)
            .map((f) => XFile(f.path!, name: f.name))
            .toList();
        await ref.read(uploadProvider.notifier).addFiles(xFiles);
      }
    } catch (e) {
      if (mounted) AppToast.showError(context, 'File picker error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(uploadProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Upload Invoices',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            Text('Scan, photo, or select files',
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          if (state.hasFiles && !state.isUploading && !state.isProcessing)
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(uploadProvider.notifier).clearFiles();
              },
              child:
                  const Text('Clear', style: TextStyle(color: AppTheme.error)),
            ),
        ],
      ),
      body: SafeArea(
        child:
            state.hasFiles ? _buildFilesView(state) : _buildEmptyState(state),
      ),
    );
  }

  // ── Empty State ─────────────────────────────────────────────────────────────

  Widget _buildEmptyState(UploadState state) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.06),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.uploadCloud,
                      size: 60, color: AppTheme.primary),
                ),
                const SizedBox(height: 24),
                const Text('Ready to Upload',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                const Text(
                    'Snap a photo, pick from gallery,\nor import a PDF invoice.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                const SizedBox(height: 32),
                // Unified Action Button
                ElevatedButton.icon(
                  onPressed: () => _showPickerBottomSheet(context),
                  icon: const Icon(LucideIcons.scan, size: 20),
                  label: const Text('Scan Invoice'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                    elevation: 0,
                  ),
                ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
              ],
            )
                .animate()
                .fadeIn(duration: 500.ms)
                .slideY(begin: 0.08, duration: 500.ms, curve: Curves.easeOut),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: RecentTasksList(
            title: 'Recent Uploads',
            historyData: state.historyData,
            isLoading: state.isLoadingHistory,
            error: state.historyError,
          ),
        ),
      ],
    );
  }

  void _showPickerBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Add Document',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _QuickPickButton(
                    icon: LucideIcons.camera,
                    label: 'Camera',
                    onTap: () {
                      Navigator.pop(context);
                      _pickCamera();
                    },
                  ),
                  _QuickPickButton(
                    icon: LucideIcons.image,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(context);
                      _pickGallery();
                    },
                  ),
                  _QuickPickButton(
                    icon: LucideIcons.fileText,
                    label: 'PDF/File',
                    onTap: () {
                      Navigator.pop(context);
                      _pickFiles();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── Files View (list + action area) ─────────────────────────────────────────

  Widget _buildFilesView(UploadState state) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${state.fileItems.length} file(s) selected',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              if (!state.isUploading && !state.isProcessing)
                IconButton(
                  onPressed: () => _showPickerBottomSheet(context),
                  icon: const Icon(LucideIcons.plusCircle,
                      color: AppTheme.primary, size: 28),
                  tooltip: 'Add more files',
                ),
            ],
          ),
          const SizedBox(height: 12),

          // File cards list
          Expanded(
            child: ListView.builder(
              itemCount: state.fileItems.length,
              itemBuilder: (ctx, i) {
                final item = state.fileItems[i];
                return _FileCard(
                  key: ValueKey(item.path),
                  item: item,
                  index: i,
                  showRemove: !state.isUploading && !state.isProcessing,
                ).animate().fadeIn(duration: 250.ms, delay: (i * 40).ms);
              },
            ),
          ),

          const SizedBox(height: 12),

          // Action area
          _buildActionArea(state),
        ],
      ),
    );
  }

  Widget _buildActionArea(UploadState state) {
    // ── PROCESSING PROGRESS ────────────────────────────────────────────────
    if (state.isUploading || state.isProcessing) {
      final processed = state.processingStatus?.processed ?? 0;
      final total = state.processingStatus?.total ?? 0;
      final msg = state.isProcessing
          ? 'OCR Processing... ($processed/$total)'
          : 'Uploading... ${(state.uploadProgress * 100).toStringAsFixed(0)}%';

      return Container(
        padding: const EdgeInsets.all(16),
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
                Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primary,
                    value: state.isUploading ? state.uploadProgress : null,
                  ),
                ),
              ],
            ),
            if (state.processingStatus?.message.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text(state.processingStatus!.message,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
            ],
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: state.isUploading ? state.uploadProgress : null,
              backgroundColor: AppTheme.border,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
              borderRadius: BorderRadius.circular(4),
              minHeight: 6,
            ),
          ],
        ),
      );
    }

    // ── DUPLICATE DETECTED ─────────────────────────────────────────────────
    if (state.hasDuplicate) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.warning.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(LucideIcons.copyX, color: AppTheme.warning, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Duplicate invoice detected. These may have been uploaded before.',
                    style: TextStyle(fontSize: 13, color: AppTheme.warning),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      ref.read(uploadProvider.notifier).clearFiles(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppTheme.border),
                  ),
                  child: const Text('Discard'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    ref.read(uploadProvider.notifier).forceUpload();
                  },
                  icon: const Icon(LucideIcons.refreshCw, size: 16),
                  label: const Text('Force Upload'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: AppTheme.warning,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // ── ALL DONE ───────────────────────────────────────────────────────────
    if (state.allDone) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.success.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.success.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(LucideIcons.checkCircle,
                    color: AppTheme.success, size: 20),
                SizedBox(width: 10),
                Text('All files processed!',
                    style: TextStyle(
                        color: AppTheme.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  ref.read(uploadProvider.notifier).clearFiles();
                  context.push('/review');
                },
                icon: const Icon(LucideIcons.clipboardCheck, size: 18),
                label: const Text('Continue to Review',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── FAILED → SHOW RETRY ────────────────────────────────────────────────
    if (state.failedCount > 0 && state.pendingCount == 0) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.error.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.error.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.alertCircle,
                    color: AppTheme.error, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${state.failedCount} file(s) failed to upload.',
                    style: const TextStyle(color: AppTheme.error, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                ref.read(uploadProvider.notifier).retryFailed();
              },
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: Text('Retry ${state.failedCount} Failed File(s)',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      );
    }

    // ── DEFAULT UPLOAD BUTTON ──────────────────────────────────────────────
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: state.pendingCount == 0
            ? null
            : () {
                HapticFeedback.mediumImpact();
                ref.read(uploadProvider.notifier).uploadAndProcess();
              },
        icon: const Icon(LucideIcons.uploadCloud, size: 20),
        label: Text(
          'Upload & Process (${state.pendingCount} file${state.pendingCount == 1 ? '' : 's'})',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

// ── File Card ─────────────────────────────────────────────────────────────────

class _FileCard extends ConsumerWidget {
  final UploadFileItem item;
  final int index;
  final bool showRemove;
  const _FileCard(
      {super.key,
      required this.item,
      required this.index,
      required this.showRemove});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = _statusColor(item.status);
    final statusIcon = _statusIcon(item.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.status == UploadFileStatus.failed
              ? AppTheme.error.withOpacity(0.4)
              : item.status == UploadFileStatus.done
                  ? AppTheme.success.withOpacity(0.4)
                  : AppTheme.border,
        ),
      ),
      child: Row(
        children: [
          // Thumbnail or icon
          ClipRRect(
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(14)),
            child: item.isImage
                ? Image.file(File(item.path),
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _pdfIcon())
                : _pdfIcon(),
          ),
          const SizedBox(width: 12),
          // File info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  if (item.sizeLabel.isNotEmpty)
                    Text(item.sizeLabel,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  // Status badge + progress
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 10, color: statusColor),
                            const SizedBox(width: 4),
                            Text(_statusLabel(item.status),
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: statusColor)),
                          ],
                        ),
                      ),
                      if (item.status == UploadFileStatus.uploading ||
                          item.status == UploadFileStatus.processing) ...[
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: AppTheme.primary),
                        ),
                      ],
                    ],
                  ),
                  if (item.errorMessage != null) ...[
                    const SizedBox(height: 3),
                    Text(item.errorMessage!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 10, color: AppTheme.error)),
                  ],
                ],
              ),
            ),
          ),

          // Remove button
          if (showRemove && item.status == UploadFileStatus.idle)
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                ref.read(uploadProvider.notifier).removeFile(index);
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(LucideIcons.x,
                    size: 18, color: AppTheme.textSecondary),
              ),
            )
          else
            const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _pdfIcon() {
    return Container(
      width: 72,
      height: 72,
      color: const Color(0xFFFFF1F0),
      child: const Center(
        child: Icon(LucideIcons.fileText, color: Color(0xFFFF4D4F), size: 28),
      ),
    );
  }

  Color _statusColor(UploadFileStatus s) {
    switch (s) {
      case UploadFileStatus.done:
        return AppTheme.success;
      case UploadFileStatus.failed:
        return AppTheme.error;
      case UploadFileStatus.duplicate:
        return AppTheme.warning;
      case UploadFileStatus.uploading:
      case UploadFileStatus.processing:
        return AppTheme.primary;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData _statusIcon(UploadFileStatus s) {
    switch (s) {
      case UploadFileStatus.done:
        return LucideIcons.checkCircle;
      case UploadFileStatus.failed:
        return LucideIcons.xCircle;
      case UploadFileStatus.duplicate:
        return LucideIcons.copyX;
      case UploadFileStatus.uploading:
        return LucideIcons.uploadCloud;
      case UploadFileStatus.processing:
        return LucideIcons.cpu;
      default:
        return LucideIcons.clock;
    }
  }

  String _statusLabel(UploadFileStatus s) {
    switch (s) {
      case UploadFileStatus.done:
        return 'Done';
      case UploadFileStatus.failed:
        return 'Failed';
      case UploadFileStatus.duplicate:
        return 'Duplicate';
      case UploadFileStatus.uploading:
        return 'Uploading';
      case UploadFileStatus.processing:
        return 'Processing OCR';
      default:
        return 'Ready';
    }
  }
}

// ── Quick Pick + Add More Buttons ─────────────────────────────────────────────

class _QuickPickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickPickButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primary, size: 24),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

*/
