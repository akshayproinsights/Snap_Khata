import 'dart:async';
import 'package:camera/camera.dart';
import 'package:mobile/core/widgets/brand_wordmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/inventory/presentation/providers/inventory_upload_provider.dart';
import 'package:mobile/features/upload/domain/models/upload_models.dart';
import 'package:mobile/features/upload/presentation/providers/camera_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile/shared/widgets/universal_image.dart';

class InventoryUploadPage extends ConsumerStatefulWidget {
  const InventoryUploadPage({super.key});

  @override
  ConsumerState<InventoryUploadPage> createState() =>
      _InventoryUploadPageState();
}

class _InventoryUploadPageState extends ConsumerState<InventoryUploadPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _flashOn = false;
  final ImagePicker _picker = ImagePicker();

  /// LOCAL guard: true until backend confirms no task is active.
  /// Camera CANNOT render while this is true.
  bool _isCheckingBackend = true;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Resume state on first build and every time the route becomes active again
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(inventoryUploadProvider.notifier).resumeIfActive();
    });

    // APPROACH 2 (Direct): ask the backend directly — bulletproof
    _checkBackendForActiveTask();
  }

  /// Called when dependencies change — this fires when the user navigates
  /// BACK to this tab inside the app (unlike didChangeAppLifecycleState which
  /// only fires when the app is backgrounded/foregrounded at the OS level).
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-check active state so tab-switch always shows processing overlay
    // instead of the camera page.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(inventoryUploadProvider.notifier).resumeIfActive();
    });
  }

  /// Called whenever the app lifecycle changes.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    switch (lifecycle) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // App going to background — suspend all polling immediately.
        ref.read(inventoryUploadProvider.notifier).pausePolling();
        break;
      case AppLifecycleState.resumed:
        // App returned to foreground — immediate sync then resume backoff.
        ref.read(inventoryUploadProvider.notifier).resumePolling();
        ref.read(inventoryUploadProvider.notifier).resumeIfActive();
        if (mounted) setState(() => _isCheckingBackend = true);
        _checkBackendForActiveTask();
        break;
      default:
        break;
    }
  }

  /// APPROACH 2: Direct backend API call
  Future<void> _checkBackendForActiveTask() async {
    try {
      final repo = ref.read(inventoryUploadRepositoryProvider);
      final recentTask = await repo.getRecentTask();

      if (!mounted) return;

      final taskStatus = recentTask['status'] as String? ?? '';
      final taskId = recentTask['task_id'] as String? ?? '';

      if (taskId.isNotEmpty &&
          (taskStatus == 'processing' ||
              taskStatus == 'queued' ||
              taskStatus == 'uploading')) {
        final progress = recentTask['progress'] as Map<String, dynamic>? ?? {};
        final total = progress['total'] as int? ?? 1;

        final notifier = ref.read(inventoryUploadProvider.notifier);
        final currentState = ref.read(inventoryUploadProvider);
        if (!currentState.isProcessing && !currentState.isUploading) {
          notifier.forceIntoProcessingState(taskId, total);
        }
      }
    } catch (_) {
      // Network error — provider's disk check is the fallback
    }

    if (mounted) {
      setState(() => _isCheckingBackend = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _capture(CameraController cam) async {
    if (_isCapturing || _isCheckingBackend) return;
    final s = ref.read(inventoryUploadProvider);
    if (s.isActive) return;

    setState(() => _isCapturing = true);
    try {
      HapticFeedback.mediumImpact();
      final xFile = await cam.takePicture();

      // ✅ RESUME PREVIEW: The camera package often freezes the preview after takePicture().
      // This is the CRITICAL fix to allow taking multiple photos sequentially.
      try {
        await cam.resumePreview();
      } catch (e) {
        debugPrint('Resume preview failed: $e');
      }

      await ref.read(inventoryUploadProvider.notifier).addFiles([xFile]);
    } catch (e) {
      if (mounted) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  Future<void> _pickGallery() async {
    final s = ref.read(inventoryUploadProvider);
    if (s.isActive || _isCheckingBackend) return;

    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        imageQuality: 80,
      );
      if (pickedFiles.isNotEmpty) {
        await ref.read(inventoryUploadProvider.notifier).addFiles(pickedFiles);
      }
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking images: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryUploadProvider);

    // Auto-navigate to inventory-review when done.
    // Suppressed if lastCompletedStatus has skipped or failed items — we show
    // the results summary first and let the user tap "Go to Review".
    ref.listen(inventoryUploadProvider, (previous, next) async {
      final wasAlreadyDone = previous?.allDone == true;
      if (next.allDone && !wasAlreadyDone) {
        final last = next.lastCompletedStatus;
        final hasDetails = last != null &&
            (last.skipped > 0 || last.failed > 0 || last.processed == 0);
        if (hasDetails) return; // Let the summary screen handle navigation
        await Future.delayed(const Duration(milliseconds: 600));
        if (!context.mounted) return;
        context.go('/inventory-review');
        ref.read(inventoryUploadProvider.notifier).clearFiles();
      }
    });

    // ── Error view (only if we don't have a final summary status) ──────────
    if (state.failedCount > 0 && state.pendingCount == 0 && state.lastCompletedStatus == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: _buildBasicAppBar(),
        body: SafeArea(child: Center(child: _buildErrorView(state))),
      );
    }

    // ── Duplicate review view (when duplicates need user action) ───────────
    if (state.hasDuplicate && state.currentDuplicate != null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: _buildBasicAppBar(),
        body: SafeArea(
          child: _buildDuplicateReviewView(state),
        ),
      );
    }

    // ── Results summary (has skipped/failed detail to show) ───────────────
    final completedStatus = state.lastCompletedStatus;
    if (state.allDone && completedStatus != null &&
        (completedStatus.skipped > 0 || completedStatus.failed > 0 ||
            completedStatus.processed == 0)) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: _buildBasicAppBar(),
        body: SafeArea(
          child: _buildResultsSummaryView(completedStatus),
        ),
      );
    }

    // ── Pure-success view (all processed, nothing skipped/failed) ─────────
    if (state.allDone) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: _buildBasicAppBar(),
        body: SafeArea(child: Center(child: _buildSuccessView())),
      );
    }

    // ── Loading overlay ───────────────────────────────────────────────────
    if (state.isUploading || state.isProcessing) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: _InventoryLoadingOverlay(fileItems: state.fileItems),
      );
    }

    // Stuck files
    final hasStuckFiles =
        state.fileItems.any((f) => f.status == UploadFileStatus.uploading);
    if (hasStuckFiles) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: _InventoryLoadingOverlay(fileItems: state.fileItems),
      );
    }

    // Restoring / checking backend guard
    if (_isCheckingBackend || state.isRestoringState) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  color: Color(0xFF0066FF),
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Checking for active uploads…',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Camera view ───────────────────────────────────────────────────────
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          _buildCameraBody(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: AppTheme.textPrimary),
                    onPressed: () {
                      final s = ref.read(inventoryUploadProvider);
                      if (s.isActive) return;
                      ref.read(inventoryUploadProvider.notifier).clearFiles();
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/');
                      }
                    },
                  ),
                  const Spacer(),
                  const Text(
                    '📦  Add Inventory',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildBasicAppBar() {
    return AppBar(
      title: const Text('Add Inventory',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(LucideIcons.arrowLeft),
        onPressed: () {
          ref.read(inventoryUploadProvider.notifier).forceReset();
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/');
          }
        },
      ),
    );
  }

  Widget _buildCameraBody() {
    final camAsync = ref.watch(cameraControllerProvider);
    final state = ref.watch(inventoryUploadProvider);

    return camAsync.when(
      loading: () => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF0066FF)),
            SizedBox(height: 16),
            Text('Starting camera...', style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      ),
      error: (e, _) => Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.camera_alt_off_rounded,
                    size: 48, color: Colors.red[300]),
                SizedBox(height: 16),
                Text('Camera Unavailable',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center),
                SizedBox(height: 12),
                Text('$e',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                    textAlign: TextAlign.center),
                SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _pickGallery,
                    icon: const Icon(Icons.image),
                    label: const Text('Use Gallery Instead'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0066FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => ref.refresh(cameraControllerProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(color: Colors.white30),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (controller) => Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(controller),
          _InvoiceScanOverlay(pulseAnimation: _pulseAnimation),
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state.fileItems.isNotEmpty) ...[
                  _buildSelectedFilesHeader(state),
                  _buildThumbnailsList(state),
                ],
                _buildBottomControls(controller, state),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedFilesHeader(InventoryUploadState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${state.fileItems.length} PAGE${state.fileItems.length > 1 ? 'S' : ''}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'SELECTED',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
          const Spacer(),
          if (state.fileItems.length >= 2)
            const Text(
              'Scroll to see all →',
              style: TextStyle(
                color: Colors.white30,
                fontSize: 10,
              ),
            ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.2);
  }

  Widget _buildThumbnailsList(InventoryUploadState state) {
    return Container(
      height: 90,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: state.fileItems.length,
        itemBuilder: (context, index) {
          final fileItem = state.fileItems[index];
          return Container(
            margin: const EdgeInsets.only(right: 12),
            width: 70,
            child: Stack(
              children: [
                UniversalImage(
                  path: fileItem.path,
                  width: 70,
                  height: 90,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(12),
                ).animate(key: ValueKey(fileItem.path))
                  .scale(duration: 300.ms, curve: Curves.easeOutBack)
                  .fadeIn(),
                Positioned(
                  top: -4,
                  right: -4,
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 14),
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      ref
                          .read(inventoryUploadProvider.notifier)
                          .removeFile(index);
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
              ],
            ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack),
          );
        },
      ),
    );
  }

  Widget _buildBottomControls(
      CameraController controller, InventoryUploadState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [AppTheme.background.withValues(alpha: 0.95), AppTheme.background.withValues(alpha: 0)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Gallery
              _CircleBtn(
                icon: Icons.photo_library_outlined,
                iconColor: AppTheme.textPrimary,
                onTap: _pickGallery,
                tooltip: 'Gallery',
              ),

              // Capture button
              GestureDetector(
                onTap: () => _capture(controller),
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border:
                        Border.all(color: const Color(0xFF0066FF), width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0066FF).withValues(alpha: 0.45),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: Color(0xFF0066FF), size: 34),
                ),
              ),

              // Flash toggle
              _CircleBtn(
                icon:
                    _flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                iconColor: _flashOn ? Colors.yellow.shade700 : AppTheme.textPrimary,
                onTap: () async {
                  final mode = _flashOn ? FlashMode.off : FlashMode.torch;
                  await controller.setFlashMode(mode);
                  setState(() => _flashOn = !_flashOn);
                },
                tooltip: 'Flash',
              ),
            ],
          ),
          if (state.fileItems.isNotEmpty) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: state.isActive
                    ? null
                    : () {
                        HapticFeedback.mediumImpact();
                        ref
                            .read(inventoryUploadProvider.notifier)
                            .uploadAndProcess();
                      },
                icon: state.isActive
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Icon(Icons.cloud_upload_outlined,
                        color: Colors.white),
                label: Text(
                  state.isActive
                      ? 'Processing…'
                      : 'Upload ${state.fileItems.length} Invoice${state.fileItems.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: state.isActive
                      ? AppTheme.primary.withValues(alpha: 0.55)
                      : AppTheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                  shadowColor: AppTheme.primary.withValues(alpha: 0.5),
                ),
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.5),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildErrorView(InventoryUploadState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.alertTriangle,
                size: 56, color: AppTheme.error),
          ),
          const SizedBox(height: 24),
          const Text(
            'Upload Failed',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 12),
          Text(
            state.error ?? 'There was an issue processing your vendor invoices.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ref.read(inventoryUploadProvider.notifier).forceReset();
                    if (context.canPop()) context.pop();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: AppTheme.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    ref.read(inventoryUploadProvider.notifier).retryFailed();
                  },
                  icon: const Icon(LucideIcons.refreshCw, size: 18),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ).animate().fadeIn().slideY(begin: 0.1),
    );
  }

  /// Rich results summary — shown whenever there are skipped duplicates or failures.
  Widget _buildResultsSummaryView(UploadTaskStatus status) {
    final processed = status.processed;
    final skipped = status.skipped;
    final failed = status.failed;
    final skippedDetails = status.skippedDetails;


    final allDuplicates = processed == 0 && failed == 0 && skipped > 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header icon + title
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: allDuplicates
                        ? const Color(0xFFFFF3E0)
                        : (failed > 0
                            ? AppTheme.error.withValues(alpha: 0.10)
                            : AppTheme.success.withValues(alpha: 0.12)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    allDuplicates
                        ? LucideIcons.copy
                        : (failed > 0
                            ? LucideIcons.alertTriangle
                            : LucideIcons.clipboardCheck),
                    size: 52,
                    color: allDuplicates
                        ? const Color(0xFFE65100)
                        : (failed > 0 ? AppTheme.error : AppTheme.success),
                  ),
                ).animate().scale(
                    duration: 400.ms, curve: Curves.easeOutBack,
                    begin: const Offset(0.6, 0.6)),
                const SizedBox(height: 16),
                Text(
                  allDuplicates
                      ? 'Already Uploaded'
                      : 'Upload Summary',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: allDuplicates
                        ? const Color(0xFFE65100)
                        : AppTheme.textPrimary,
                  ),
                ).animate().fadeIn(delay: 150.ms),
                if (allDuplicates) ...
                  [
                    const SizedBox(height: 6),
                    const Text(
                      'These invoices were already in your system.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                    ).animate().fadeIn(delay: 200.ms),
                  ],
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── Stats row ────────────────────────────────────────────────────
          Row(
            children: [
              if (processed > 0)
                Expanded(
                  child: _StatChip(
                    icon: LucideIcons.checkCircle2,
                    color: AppTheme.success,
                    count: processed,
                    label: 'Added',
                  ),
                ),
              if (processed > 0 && (skipped > 0 || failed > 0))
                const SizedBox(width: 10),
              if (skipped > 0)
                Expanded(
                  child: _StatChip(
                    icon: LucideIcons.copy,
                    color: const Color(0xFFE65100),
                    count: skipped,
                    label: 'Duplicate${skipped == 1 ? '' : 's'}',
                  ),
                ),
              if (skipped > 0 && failed > 0) const SizedBox(width: 10),
              if (failed > 0)
                Expanded(
                  child: _StatChip(
                    icon: LucideIcons.xCircle,
                    color: AppTheme.error,
                    count: failed,
                    label: 'Failed',
                  ),
                ),
            ],
          ).animate().fadeIn(delay: 250.ms),

          // ── Duplicate details ─────────────────────────────────────────────
          if (skippedDetails.isNotEmpty) ...
            [
              const SizedBox(height: 24),
              const Text(
                '⏭️  Skipped — Already Uploaded',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 10),
              ...skippedDetails.map((dup) {
                final inv = dup['invoice_number'] as String? ?? '';
                final date = dup['invoice_date'] as String? ?? '';
                final msg = dup['message'] as String? ?? 'Already uploaded previously';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8F5),
                    border: Border.all(color: const Color(0xFFFFCCBC)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.copy,
                          size: 18, color: Color(0xFFE65100)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              inv.isNotEmpty ? 'Invoice #$inv' : 'Invoice (no number)',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            if (date.isNotEmpty)
                              Text(
                                date,
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            Text(
                              msg,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFE65100),
                                  fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.1);
              }),
            ],

          // ── Failed details ─────────────────────────────────────────────────
          if (failed > 0) ...
            [
              const SizedBox(height: 20),
              const Text(
                '❌  Failed to Read',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.06),
                  border: Border.all(color: AppTheme.error.withValues(alpha: 0.25)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(LucideIcons.camera,
                            size: 18, color: AppTheme.error.withValues(alpha: 0.8)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$failed invoice${failed == 1 ? '' : 's'} could not be processed.',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '💡 Tip: Retake the photo with better lighting and make sure the invoice is flat and fully visible inside the frame.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 350.ms),
            ],

          const SizedBox(height: 32),

          // ── CTA buttons ────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: () {
                ref.read(inventoryUploadProvider.notifier).clearFiles();
                context.go('/inventory-review');
              },
              icon: const Icon(LucideIcons.packageCheck,
                  color: Colors.white, size: 20),
              label: Text(
                processed > 0 ? 'Go to Pending Review  →' : 'Back to Inventory  →',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    processed > 0 ? AppTheme.success : AppTheme.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 6,
              ),
            ),
          ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.3),

          if (failed > 0) ...
            [
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ref.read(inventoryUploadProvider.notifier).forceReset();
                  },
                  icon: const Icon(LucideIcons.camera, size: 18),
                  label: const Text('Retake Failed Photos'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ).animate().fadeIn(delay: 500.ms),
            ],

          const SizedBox(height: 16),
          Center(
            child: Text(
              'Redirecting automatically in a few seconds…',
              style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary.withValues(alpha: 0.6)),
            ),
          ).animate().fadeIn(delay: 600.ms),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.success.withValues(alpha: 0.12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.success.withValues(alpha: 0.35),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: const Icon(LucideIcons.checkCircle2,
                size: 72, color: AppTheme.success),
          )
              .animate()
              .scale(
                  duration: 500.ms,
                  curve: Curves.easeOutBack,
                  begin: const Offset(0.5, 0.5))
              .then()
              .shimmer(duration: 800.ms, color: AppTheme.success),
          const SizedBox(height: 28),
          const Text(
            '✅  Inventory is ready!',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppTheme.success,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
          const SizedBox(height: 12),
          const Text(
            'Your vendor invoices have been read.\nLet\'s check the stock levels.',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 350.ms),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton.icon(
              onPressed: () {
                ref.read(inventoryUploadProvider.notifier).clearFiles();
                context.go('/inventory-review');
              },
              icon: const Icon(LucideIcons.packageCheck,
                  color: Colors.white, size: 22),
              label: const Text(
                'Review Inventory  →',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 10,
                shadowColor: AppTheme.success.withValues(alpha: 0.5),
              ),
            ),
          ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.3, end: 0),
          const SizedBox(height: 16),
          const Text(
            'Taking you to inventory review automatically...',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ).animate().fadeIn(delay: 700.ms),
        ],
      ),
    );
  }

  /// Duplicate review view — shown when duplicates need user action
  Widget _buildDuplicateReviewView(InventoryUploadState state) {
    final current = state.currentDuplicate;
    if (current == null) {
      return const Center(child: Text('No duplicate to review'));
    }

    final invoiceNumber = current['invoice_number'] as String? ?? '';
    final invoiceDate = current['invoice_date'] as String? ?? '';
    final message = current['message'] as String? ?? 'Already uploaded previously';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.copy,
                    size: 52,
                    color: Color(0xFFE65100),
                  ),
                ).animate().scale(
                    duration: 400.ms, curve: Curves.easeOutBack,
                    begin: const Offset(0.6, 0.6)),
                const SizedBox(height: 16),
                Text(
                  'Duplicate Invoice Detected',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFE65100),
                  ),
                ).animate().fadeIn(delay: 150.ms),
                const SizedBox(height: 6),
                Text(
                  'This invoice was already uploaded to your inventory.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                ).animate().fadeIn(delay: 200.ms),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Duplicate details card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8F5),
              border: Border.all(color: const Color(0xFFFFCCBC)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (invoiceNumber.isNotEmpty) ...[
                  const Text(
                    'Invoice Number',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    invoiceNumber,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (invoiceDate.isNotEmpty) ...[
                  const Text(
                    'Invoice Date',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    invoiceDate,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text(
                  'Message',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFFE65100),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 250.ms),

          const SizedBox(height: 24),

          // Progress indicator
          Center(
            child: Text(
              'Duplicate ${state.currentDuplicateIndex + 1} of ${state.duplicateQueue.length}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ref.read(inventoryUploadProvider.notifier).skipDuplicate();
                  },
                  icon: const Icon(LucideIcons.skipForward, size: 18),
                  label: const Text('Skip This File'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    foregroundColor: AppTheme.textPrimary,
                    side: BorderSide(color: AppTheme.border),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    ref.read(inventoryUploadProvider.notifier).replaceDuplicate();
                  },
                  icon: const Icon(LucideIcons.refreshCw, size: 18),
                  label: const Text('Replace Old'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: const Color(0xFFE65100),
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.1),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onTap;
  final String tooltip;

  const _CircleBtn({
    required this.icon,
    this.iconColor,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor ?? AppTheme.textPrimary, size: 26),
        ),
      ),
    );
  }
}

class _InvoiceScanOverlay extends StatelessWidget {
  final Animation<double> pulseAnimation;
  const _InvoiceScanOverlay({required this.pulseAnimation});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AnimatedBuilder(
          animation: pulseAnimation,
          builder: (_, __) => CustomPaint(
            painter: _FramePainter(scale: pulseAnimation.value),
            size: Size.infinite,
          ),
        ),
        Align(
          alignment: const Alignment(0, 0.70),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0066FF).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Text(
              'Place the vendor invoice inside the frame',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}

class _FramePainter extends CustomPainter {
  final double scale;
  _FramePainter({required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    const cl = 36.0;
    const sw = 3.5;
    const frameColor = Color(0xFF0066FF);

    final fw = size.width * 0.90 * scale;
    final fh = size.height * 0.80 * scale;
    final l = (size.width - fw) / 2;
    final t = (size.height - fh) / 2 - 40;
    final r = l + fw;
    final b = t + fh;

    final dim = Paint()..color = Colors.black.withValues(alpha: 0.42);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, t), dim);
    canvas.drawRect(Rect.fromLTWH(0, b, size.width, size.height - b), dim);
    canvas.drawRect(Rect.fromLTWH(0, t, l, fh), dim);
    canvas.drawRect(Rect.fromLTWH(r, t, size.width - r, fh), dim);

    final p = Paint()
      ..color = frameColor
      ..strokeWidth = sw
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(l, t + cl), Offset(l, t), p);
    canvas.drawLine(Offset(l, t), Offset(l + cl, t), p);
    canvas.drawLine(Offset(r - cl, t), Offset(r, t), p);
    canvas.drawLine(Offset(r, t), Offset(r, t + cl), p);
    canvas.drawLine(Offset(l, b - cl), Offset(l, b), p);
    canvas.drawLine(Offset(l, b), Offset(l + cl, b), p);
    canvas.drawLine(Offset(r - cl, b), Offset(r, b), p);
    canvas.drawLine(Offset(r, b), Offset(r, b - cl), p);
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.scale != scale;
}

// ─────────────────────────────────────────────────────────────────────────────
// Two-phase premium loading overlay — Inventory edition
// Phase 1: Uploading (real progress from state.uploadProgress)
// Phase 2: Reading Invoice (6 animated steps, inventory-specific copy)
// ─────────────────────────────────────────────────────────────────────────────
class _InventoryLoadingOverlay extends ConsumerStatefulWidget {
  final List<UploadFileItem> fileItems;
  const _InventoryLoadingOverlay({required this.fileItems});

  @override
  ConsumerState<_InventoryLoadingOverlay> createState() =>
      _InventoryLoadingOverlayState();
}

class _InventoryLoadingOverlayState
    extends ConsumerState<_InventoryLoadingOverlay>
    with TickerProviderStateMixin {
  // ── Processing steps (inventory-specific, SMB English) ──
  static const _processingSteps = [
    (
      icon: '📦',
      title: 'Reading the invoice',
      sub: 'Finding vendor name and invoice date'
    ),
    (
      icon: '🏷️',
      title: 'Reading item names',
      sub: 'Noting each product from the vendor'
    ),
    (
      icon: '📐',
      title: 'Checking quantities',
      sub: 'Counting units received per item'
    ),
    (
      icon: '💰',
      title: 'Reading prices',
      sub: 'Matching rates per unit from invoice'
    ),
    (
      icon: '🧮',
      title: 'Calculating total',
      sub: 'Adding up amounts and matching totals'
    ),
    (icon: '✅', title: 'Almost done!', sub: 'Saving your inventory data'),
  ];

  static const _uploadTips = [
    '📦 You can freely use other tabs while your invoices upload!',
    '📶 A good internet connection speeds up the upload',
    '🖼️  Clear, well-lit photos give faster and more accurate results',
  ];

  static const _processingTips = [
    '💡 You can freely use other tabs while we read the invoice',
    '💡 Tip: Upload multiple invoices at the same time to save time',
    '💡 Tip: Clear photos give faster, more accurate results',
    '💡 Tip: You can check and fix quantities after processing',
  ];

  int _highWaterStep = 0;
  int _tipIndex = 0;
  bool _wasUploading = true;
  DateTime? _processingStartTime;

  late final AnimationController _processingBarController;
  late final AnimationController _phaseTransitionController;
  StreamSubscription<dynamic>? _tipSub;

  @override
  void initState() {
    super.initState();

    _processingBarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 14000),
    );

    _phaseTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Tip ticker — rotate every 4 seconds
    _tipSub = Stream.periodic(const Duration(seconds: 4)).listen((_) {
      if (mounted) {
        setState(() {
          final maxLen = _processingTips.length > _uploadTips.length
              ? _processingTips.length
              : _uploadTips.length;
          _tipIndex = (_tipIndex + 1) % maxLen;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final st = ref.read(inventoryUploadProvider);
      if (st.isProcessing && !st.isUploading) {
        _wasUploading = false;
        _startProcessingAnimation();
      }
    });
  }

  void _startProcessingAnimation() {
    _processingStartTime = DateTime.now();
    _processingBarController.forward();
  }

  int _computeStepIndex() {
    if (_processingStartTime == null) return _highWaterStep;
    final elapsed =
        DateTime.now().difference(_processingStartTime!).inMilliseconds;
    final maxAutoStep = _processingSteps.length - 2;
    final timeStep = (elapsed ~/ 10000).clamp(0, maxAutoStep);
    if (timeStep > _highWaterStep) _highWaterStep = timeStep;
    return _highWaterStep;
  }

  @override
  void dispose() {
    _tipSub?.cancel();
    _processingBarController.dispose();
    _phaseTransitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(inventoryUploadProvider);
    final isUploading = uploadState.isUploading;
    final isProcessing = uploadState.isProcessing;
    final uploadProgress = uploadState.uploadProgress;

    if (_wasUploading && isProcessing && !isUploading) {
      _wasUploading = false;
      HapticFeedback.mediumImpact();
      _phaseTransitionController.forward(from: 0);
      _startProcessingAnimation();
    }

    final stepIndex = _computeStepIndex();
    final currentStep = _processingSteps[stepIndex];
    final procStepProgress = (stepIndex + 1) / _processingSteps.length;

    final isLastStep = !isUploading &&
        (stepIndex >= _processingSteps.length - 1) &&
        isProcessing;

    final tips = isUploading ? _uploadTips : _processingTips;
    final safeTipIndex = _tipIndex % tips.length;

    final mainTitle = isUploading ? 'Uploading invoice' : isLastStep ? _processingSteps.last.title : currentStep.title;
    final mainSub = isUploading
        ? 'Please wait while we send your document'
        : isLastStep ? _processingSteps.last.sub : currentStep.sub;

    final stepLabel = isUploading
        ? 'Step 1 of 2'
        : isLastStep ? 'Finalizing…' : 'Step 2: ${stepIndex + 1} of ${_processingSteps.length}';

    final barValue = isUploading ? uploadProgress : procStepProgress;
    final percent = (barValue * 100).toInt();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // ── App Bar ──
            Container(
              color: const Color(0xFFF8F9FA),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: Color(0xFF0058BE), size: 22),
                    onPressed: isUploading
                        ? null
                        : () {
                            if (context.mounted) context.go('/');
                          },
                  ),
                  const Expanded(
                    child: BrandWordmark(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // ── Body ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  children: [
                    // ── Animated icon with rotating rings ──
                    SizedBox(
                      width: 176,
                      height: 176,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          RotationTransition(
                            turns: Tween(begin: 0.0, end: 1.0).animate(
                                CurvedAnimation(
                                    parent: _processingBarController,
                                    curve: Curves.linear)),
                            child: Container(
                              width: 176,
                              height: 176,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF0058BE)
                                      .withValues(alpha: 0.18),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          RotationTransition(
                            turns: Tween(begin: 0.0, end: -1.0).animate(
                                CurvedAnimation(
                                    parent: _processingBarController,
                                    curve: Curves.linear)),
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF0058BE)
                                      .withValues(alpha: 0.38),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF0058BE),
                                  Color(0xFF2170E4)
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0058BE)
                                      .withValues(alpha: 0.25),
                                  blurRadius: 32,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: isUploading
                                ? Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      SizedBox(
                                        width: 64,
                                        height: 64,
                                        child: CircularProgressIndicator(
                                          value: uploadProgress > 0
                                              ? uploadProgress
                                              : null,
                                          color: Colors.white,
                                          strokeWidth: 3,
                                          backgroundColor: Colors.white
                                              .withValues(alpha: 0.2),
                                        ),
                                      ),
                                      const Icon(Icons.cloud_upload_outlined,
                                          color: Colors.white, size: 32),
                                    ],
                                  )
                                : const Icon(Icons.receipt_long_outlined,
                                    color: Colors.white, size: 40),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Status text ──
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: Text(
                        mainTitle,
                        key: ValueKey(mainTitle),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF191C1D),
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: Text(
                        mainSub,
                        key: ValueKey(mainSub),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF424754),
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Progress card ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE1E3E4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                stepLabel.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF424754),
                                  letterSpacing: 1.0,
                                ),
                              ),
                              Text(
                                '$percent%',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0058BE),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: barValue),
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeOut,
                              builder: (_, v, __) =>
                                  LinearProgressIndicator(
                                value: isLastStep ? null : v,
                                minHeight: 8,
                                backgroundColor: const Color(0xFFEDEEEF),
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(
                                        Color(0xFF0058BE)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _PhaseRow(
                            label: 'Uploading document',
                            isDone: !isUploading,
                            isActive: isUploading,
                            doneColor: const Color(0xFF006C49),
                            activeColor: const Color(0xFF0058BE),
                          ),
                          const SizedBox(height: 16),
                          _PhaseRow(
                            label: 'Reading details & prices',
                            isDone: false,
                            isActive: !isUploading,
                            doneColor: const Color(0xFF006C49),
                            activeColor: const Color(0xFF0058BE),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Upload warning ──
                    if (isUploading)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: const Color(0xFFFDE68A)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Color(0xFFD97706), size: 18),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Keep the app open — closing will cancel your upload',
                                style: TextStyle(
                                  color: Color(0xFF92400E),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // ── Go to Home card ──
                    GestureDetector(
                      onTap: () {
                        if (context.mounted) context.go('/');
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.home_outlined,
                                  color: Color(0xFF0058BE), size: 20),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Go to Home',
                                    style: TextStyle(
                                      color: Color(0xFF191C1D),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Keep working while we process',
                                    style: TextStyle(
                                      color: Color(0xFF424754),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                color: Color(0xFF424754), size: 20),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Rotating tip card ──
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 600),
                      child: Container(
                        key: ValueKey(
                            'tip_${isUploading}_$safeTipIndex'),
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDEEEF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.lightbulb_outline,
                                  color: Color(0xFF825100), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Quick Tip',
                                    style: TextStyle(
                                      color: Color(0xFF191C1D),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    tips[safeTipIndex],
                                    style: const TextStyle(
                                      color: Color(0xFF424754),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhaseRow extends StatelessWidget {
  final String label;
  final bool isDone;
  final bool isActive;
  final Color doneColor;
  final Color activeColor;

  const _PhaseRow({
    required this.label,
    required this.isDone,
    required this.isActive,
    required this.doneColor,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isDone
                    ? doneColor
                    : (isActive
                        ? activeColor.withValues(alpha: 0.1)
                        : Colors.transparent),
                shape: BoxShape.circle,
                border: isActive || isDone
                    ? null
                    : Border.all(color: const Color(0xFFE1E3E4)),
              ),
              child: isDone
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : (isActive
                      ? Center(
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: activeColor,
                            ),
                          ),
                        )
                      : null),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isActive || isDone
                    ? const Color(0xFF191C1D)
                    : const Color(0xFF727785),
                fontSize: 14,
                fontWeight:
                    isActive || isDone ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
        if (isDone)
          Text(
            'DONE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: doneColor,
              letterSpacing: 1.0,
            ),
          )
        else if (isActive)
          Opacity(
            opacity: 1.0,
            child: Text(
              'READING',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: activeColor,
                letterSpacing: 1.0,
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatChip: small summary tile showing count + icon + label
// Used in the results summary view
// ─────────────────────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int count;
  final String label;

  const _StatChip({
    required this.icon,
    required this.color,
    required this.count,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
