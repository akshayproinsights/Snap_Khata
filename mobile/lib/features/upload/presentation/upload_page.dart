import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/widgets/brand_wordmark.dart';
import 'package:mobile/features/upload/domain/models/upload_models.dart';
import 'package:mobile/features/upload/presentation/providers/upload_provider.dart';
import 'package:mobile/features/upload/presentation/providers/camera_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile/shared/widgets/universal_image.dart';

class UploadPage extends ConsumerStatefulWidget {
  const UploadPage({super.key});

  @override
  ConsumerState<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends ConsumerState<UploadPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _flashOn = false;
  final ImagePicker _picker = ImagePicker();

  /// ── LOCAL guard: true until we've confirmed with the backend that
  ///    no task is active. The camera page CANNOT render while this is true.
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

    // ── APPROACH 1 (Provider): re-attach overlay via state management
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(uploadProvider.notifier).resumeIfActive();
    });

    // ── APPROACH 2 (Direct): ask the backend directly — bulletproof
    _checkBackendForActiveTask();
  }

  /// Called whenever the app lifecycle changes (foreground/background).
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    switch (lifecycle) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // App is going to background — suspend all polling immediately.
        // Zero requests will hit the server until we return to foreground.
        ref.read(uploadProvider.notifier).pausePolling();
        break;
      case AppLifecycleState.resumed:
        // App returned to foreground — do an immediate sync then resume backoff.
        ref.read(uploadProvider.notifier).resumePolling();
        // Also run the full resumeIfActive() to handle cold-launch recovery.
        ref.read(uploadProvider.notifier).resumeIfActive();
        if (mounted) setState(() => _isCheckingBackend = true);
        _checkBackendForActiveTask();
        break;
      default:
        break;
    }
  }

  /// ── APPROACH 2: Direct backend API call ──────────────────────────
  /// Calls getRecentTask() to ask the server if there is any active
  /// processing/queued/uploading task. If yes, forces the provider into
  /// the processing state so the overlay shows. If no, clears the guard.
  /// This is completely independent of SharedPreferences or in-memory state.
  Future<void> _checkBackendForActiveTask() async {
    try {
      final repo = ref.read(uploadRepositoryProvider);
      final recentTask = await repo.getRecentTask();

      if (!mounted) return;

      final taskStatus = recentTask['status'] as String? ?? '';
      final taskId = recentTask['task_id'] as String? ?? '';

      if (taskId.isNotEmpty &&
          (taskStatus == 'processing' ||
              taskStatus == 'queued' ||
              taskStatus == 'uploading')) {
        // ✅ Backend says there IS an active task — force the provider
        //    into processing mode so the loading overlay shows.
        final progress = recentTask['progress'] as Map<String, dynamic>? ?? {};
        final total = progress['total'] as int? ?? 1;

        final notifier = ref.read(uploadProvider.notifier);
        // Only force-set if the provider doesn't already know
        final currentState = ref.read(uploadProvider);
        if (!currentState.isProcessing && !currentState.isUploading) {
          notifier.forceIntoProcessingState(taskId, total);
        }
      }
    } catch (_) {
      // Network error — can't reach backend. Fall through; the provider's
      // disk-based check is the fallback.
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
    final s = ref.read(uploadProvider);
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

      await ref.read(uploadProvider.notifier).addFiles([xFile]);
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
    // Block gallery while backend is processing
    final s = ref.read(uploadProvider);
    if (s.isActive || _isCheckingBackend) return;

    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        imageQuality: 80,
      );
      if (pickedFiles.isNotEmpty) {
        await ref.read(uploadProvider.notifier).addFiles(pickedFiles);
      }
    } catch (e) {
      if (mounted) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gallery error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(uploadProvider);

    // Auto-navigate to review when everything is done
    ref.listen(uploadProvider, (previous, next) async {
      if (next.allDone && (previous?.allDone != true)) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (!context.mounted) return;
        ref.read(uploadProvider.notifier).clearFiles();
        context.go('/review');
      }
    });

    // ── DUPLICATE DETECTED ────────────────────────────────────────────────
    if (state.hasDuplicate && state.currentDuplicate != null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: _buildBasicAppBar(),
        body: SafeArea(
          child: Center(
            child: _buildDuplicateReviewView(state, ref, context),
          ),
        ),
      );
    }

    // ── Actual upload error (not duplicate) ───────────────────────────────
    if (state.failedCount > 0 && state.pendingCount == 0) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: _buildBasicAppBar(),
        body: SafeArea(child: Center(child: _buildErrorView(state))),
      );
    }

    if (state.allDone) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: _buildBasicAppBar(),
        body: SafeArea(child: Center(child: _buildSuccessView())),
      );
    }

    if (state.isUploading || state.isProcessing) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: _LoadingOverlay(fileItems: state.fileItems),
      );
    }

    // Prevent brief camera flash while resumeIfActive() resolves:
    // If any file is stuck in 'uploading' status but flags say idle,
    // it means the upload was interrupted and recovery is in-flight.
    // Show the overlay until the async check completes.
    final hasStuckFiles =
        state.fileItems.any((f) => f.status == UploadFileStatus.uploading);
    if (hasStuckFiles) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: _LoadingOverlay(fileItems: state.fileItems),
      );
    }

    // ── LOCAL guard (Approach 2): while the direct backend API call
    //    is still in-flight, show a loading screen. This is independent
    //    of the provider and covers the async gap from initState/resume.
    // ── PROVIDER guard (Approach 1): while restoring state from disk,
    //    show a loading screen so the user NEVER sees the camera page
    //    when backend processing is active.
    if (_isCheckingBackend || state.isRestoringState) {
      return const Scaffold(
        backgroundColor: Colors.black,
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
                'Checking for active orders…',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Camera View
    return Scaffold(
      backgroundColor: Colors.black,
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
                        color: Colors.white),
                    onPressed: () {
                      // Only allow back-nav when no active upload/processing
                      final s = ref.read(uploadProvider);
                      if (s.isActive) return;
                      ref.read(uploadProvider.notifier).clearFiles();
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/');
                      }
                    },
                  ),
                  const Spacer(),
                  const Text(
                    'UPLOAD INVOICES',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5),
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
      title: const Text(
        'UPLOAD INVOICES',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
      ),
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(LucideIcons.arrowLeft),
        onPressed: () {
          // Use forceReset here — this AppBar is shown on error/duplicate screens
          // where we always want to allow going back regardless of active state
          ref.read(uploadProvider.notifier).forceReset();
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
    final state = ref.watch(uploadProvider);

    return camAsync.when(
      loading: () => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF0066FF)),
            SizedBox(height: 16),
            Text('Starting camera...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('Camera unavailable: $e',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center),
        ),
      ),
      data: (controller) => Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(controller),
          _ScanOverlay(pulseAnimation: _pulseAnimation),
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

  void _showImagePreview(BuildContext context, String path, int index) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _ImagePreviewDialog(initialIndex: index),
    );
  }

  Widget _buildSelectedFilesHeader(UploadState state) {
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

  Widget _buildThumbnailsList(UploadState state) {
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
                // Tappable thumbnail — opens enlarged preview
                GestureDetector(
                  onTap: () => _showImagePreview(context, fileItem.path, index),
                  child: UniversalImage(
                    path: fileItem.path,
                    width: 70,
                    height: 90,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                // Small ✕ delete button (quick remove without preview)
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
                      ref.read(uploadProvider.notifier).removeFile(index);
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

  Widget _buildBottomControls(CameraController controller, UploadState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
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
                iconColor: _flashOn ? Colors.yellow : Colors.white,
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
                // Disabled when upload/processing is already active (prevents double-tap)
                onPressed: state.isActive
                    ? null
                    : () {
                        HapticFeedback.mediumImpact();
                        ref.read(uploadProvider.notifier).uploadAndProcess();
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
                    : const Icon(Icons.check_circle_outline,
                        color: Colors.white),
                label: Text(
                  state.isActive
                      ? 'Processing…'
                      : 'Upload ${state.fileItems.length} Order${state.fileItems.length > 1 ? 's' : ''}',
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

  Widget _buildErrorView(UploadState state) {
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
          const Text(
            'There was an issue processing your invoices.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ref.read(uploadProvider.notifier).forceReset();
                    if (context.canPop()) context.pop();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: AppTheme.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Cancel Request'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    ref.read(uploadProvider.notifier).retryFailed();
                  },
                  icon: const Icon(LucideIcons.refreshCw, size: 18),
                  label: const Text('Retry Data'),
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

  Widget _buildSuccessView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Celebration icon ──
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

          // ── Headline ──
          const Text(
            '✅  Your order is ready!',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppTheme.success,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),

          const SizedBox(height: 12),

          // ── Subtext ──
          const Text(
            'Great job! You can now move around freely.\nLet\'s go check your order.',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 350.ms),

          const SizedBox(height: 40),

          // ── CTA Button ──
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton.icon(
              onPressed: () {
                ref.read(uploadProvider.notifier).clearFiles();
                context.go('/review');
              },
              icon: const Icon(Icons.checklist_rounded,
                  color: Colors.white, size: 22),
              label: const Text(
                'Review My Order  →',
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

          // ── Small note ──
          const Text(
            'Taking you to review automatically...',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ).animate().fadeIn(delay: 700.ms),
        ],
      ),
    );
  }

  // ── DUPLICATE REVIEW SCREEN ────────────────────────────────────────────
  Widget _buildDuplicateReviewView(UploadState state, WidgetRef ref, BuildContext context) {
    final duplicate = state.currentDuplicate as Map<String, dynamic>? ?? {};
    final existingInvoice = duplicate['existing_invoice'] as Map<String, dynamic>? ?? {};
    final index = state.currentDuplicateIndex + 1;
    final total = state.duplicateQueue.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Icon(LucideIcons.alertTriangle,
                    size: 48, color: Colors.orange),
                const SizedBox(height: 12),
                const Text(
                  'Duplicate Invoice Detected',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Duplicate $index of $total',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Comparison Details ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📋 Existing Invoice',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.success,
                  ),
                ),
                const SizedBox(height: 12),
                _buildDetailRow('Invoice #', existingInvoice['receipt_number']?.toString() ?? 'N/A'),
                _buildDetailRow('Date', existingInvoice['date']?.toString() ?? 'N/A'),
                if (existingInvoice['customer'] != null && (existingInvoice['customer'] as String).isNotEmpty)
                  _buildDetailRow('Customer', existingInvoice['customer']?.toString() ?? 'N/A'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Action Buttons ──
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ref.read(uploadProvider.notifier).skipCurrentDuplicate();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: AppTheme.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Skip This File'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    ref.read(uploadProvider.notifier).replaceCurrentDuplicate();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Replace Old Record'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Progress indicator ──
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: index / total,
              minHeight: 6,
              backgroundColor: AppTheme.border.withValues(alpha: 0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// _DuplicateReviewScreen and helper widgets removed

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
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor ?? Colors.white, size: 26),
        ),
      ),
    );
  }
}

class _ScanOverlay extends StatelessWidget {
  final Animation<double> pulseAnimation;

  const _ScanOverlay({required this.pulseAnimation});

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
          alignment:
              const Alignment(0, 0.70), // Lower down because frame is taller
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0066FF).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Text(
              'Place the order inside the frame',
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
    const cl = 36.0; // corner length
    const sw = 3.5; // stroke width
    const frameColor = Color(0xFF0066FF);

    // Adjusted for Indian SMBs: Almost full screen height
    final fw = size.width * 0.90 * scale;
    final fh = size.height * 0.80 * scale;

    // Position slightly higher to account for bottom buttons
    final l = (size.width - fw) / 2;
    final t = (size.height - fh) / 2 - 40;
    final r = l + fw;
    final b = t + fh;

    // Dim overlay outside frame
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

    // TL
    canvas.drawLine(Offset(l, t + cl), Offset(l, t), p);
    canvas.drawLine(Offset(l, t), Offset(l + cl, t), p);
    // TR
    canvas.drawLine(Offset(r - cl, t), Offset(r, t), p);
    canvas.drawLine(Offset(r, t), Offset(r, t + cl), p);
    // BL
    canvas.drawLine(Offset(l, b - cl), Offset(l, b), p);
    canvas.drawLine(Offset(l, b), Offset(l + cl, b), p);
    // BR
    canvas.drawLine(Offset(r - cl, b), Offset(r, b), p);
    canvas.drawLine(Offset(r, b), Offset(r, b - cl), p);
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.scale != scale;
}

// ─────────────────────────────────────────────────────────────────
// Two-phase premium loading overlay
// Phase 1: Uploading (real progress from state.uploadProgress)
// Phase 2: Smart Reading (animated steps from processingStatus poll)
// ─────────────────────────────────────────────────────────────────
class _LoadingOverlay extends ConsumerStatefulWidget {
  final List<UploadFileItem> fileItems;
  const _LoadingOverlay({required this.fileItems});

  @override
  ConsumerState<_LoadingOverlay> createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends ConsumerState<_LoadingOverlay>
    with TickerProviderStateMixin {
  // ── Processing steps (simple SMB English, no AI/OCR jargon) ──
  static const _processingSteps = [
    (
      icon: '📋',
      title: 'Reading the order',
      sub: 'Finding customer name and date'
    ),
    (
      icon: '🛍️',
      title: 'Picking up items',
      sub: 'Noting down each product on the order'
    ),
    (
      icon: '💰',
      title: 'Checking prices',
      sub: 'Matching rates and quantities'
    ),
    (
      icon: '🧮',
      title: 'Calculating total',
      sub: 'Adding up amounts and any discounts'
    ),
    (
      icon: '💳',
      title: 'Checking payment',
      sub: 'Figuring out if it was paid or pending'
    ),
    (
      icon: '✅',
      title: 'Almost done!',
      sub: 'Your order is getting ready to review'
    ),
  ];

  static const _uploadTips = [
    '⚠️  Keep the app open — closing it will cancel your upload',
    '📶 Make sure your internet is on during upload',
    '🖼️  Clear, well-lit photos upload faster',
  ];

  static const _processingTips = [
    '💡 You can freely use other tabs while we read the order',
    '💡 Tip: Upload multiple orders at the same time to save time',
    '💡 Tip: Clear photos give faster, more accurate results',
    '💡 Tip: You can tap any order to edit details before saving',
  ];

  /// Tracks the highest step we've shown — never goes backwards.
  int _highWaterStep = 0;
  int _tipIndex = 0;
  bool _wasUploading = true; // track phase transition for haptic

  /// When processing animation started — used for time-based minimum step
  /// so the UI always makes progress even before the first poll arrives.
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
          // Use the larger list length so index never overflows either list
          final maxLen = _processingTips.length > _uploadTips.length
              ? _processingTips.length
              : _uploadTips.length;
          _tipIndex = (_tipIndex + 1) % maxLen;
        });
      }
    });

    // ── Auto-start processing animation when overlay is created already
    //    in processing state (e.g. resumed from background / backend check).
    //    Without this, the step animation and progress bar never start.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final st = ref.read(uploadProvider);
      if (st.isProcessing && !st.isUploading) {
        _wasUploading = false; // skip the upload→processing transition
        _startProcessingAnimation();
      }
    });
  }

  void _startProcessingAnimation() {
    _processingStartTime = DateTime.now();
    _processingBarController.forward();
  }

  /// Step index is driven purely by time so the 6 UI sub-steps advance
  /// smoothly and realistically. The backend only reports *files* done
  /// (0 → N), not the internal sub-steps (read header, items, quantities,
  /// prices, totals, save) — so using the server ratio here would cause
  /// an instant jump to Step 6 the moment one file finishes.
  int _computeStepIndex() {
    if (_processingStartTime == null) return _highWaterStep;
    final elapsed =
        DateTime.now().difference(_processingStartTime!).inMilliseconds;
    // Advance one step every ~10 seconds (max 5 so step 6 is indeterminate
    // until backend confirms completion).
    final maxAutoStep = _processingSteps.length - 2; // stop at step 5 (index 4)
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
    final uploadState = ref.watch(uploadProvider);
    final isUploading = uploadState.isUploading;
    final isProcessing = uploadState.isProcessing;
    final uploadProgress = uploadState.uploadProgress;

    // Detect phase switch: uploading → processing
    if (_wasUploading && isProcessing && !isUploading) {
      _wasUploading = false;
      HapticFeedback.mediumImpact();
      _phaseTransitionController.forward(from: 0);
      _startProcessingAnimation();
    }

    // ── Step index driven purely by time, not server ratio ──
    final stepIndex = _computeStepIndex();
    final currentStep = _processingSteps[stepIndex];
    final procStepProgress = (stepIndex + 1) / _processingSteps.length;

    // Indeterminate bar on step 6: we've animated through all 5 timed steps
    // and are now waiting for the backend to confirm completion.
    final isLastStep = !isUploading &&
        (stepIndex >= _processingSteps.length - 1) &&
        isProcessing;

    // Pick the right tips list
    final tips = isUploading ? _uploadTips : _processingTips;
    final safeTipIndex = _tipIndex % tips.length;

    // Phase-specific text and progress values
    final mainTitle = isUploading ? 'Uploading order' : isLastStep ? _processingSteps.last.title : currentStep.title;
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
                                : const Icon(Icons.description_outlined,
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

// ── Phase row indicator (used inside progress card) ──
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
            // Since it's active we can make it look prominent
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

class _ImagePreviewDialog extends ConsumerStatefulWidget {
  final int initialIndex;

  const _ImagePreviewDialog({required this.initialIndex});

  @override
  ConsumerState<_ImagePreviewDialog> createState() =>
      _ImagePreviewDialogState();
}

class _ImagePreviewDialogState extends ConsumerState<_ImagePreviewDialog> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(uploadProvider);
    final fileItems = state.fileItems;

    if (fileItems.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return const SizedBox();
    }

    if (_currentIndex >= fileItems.length) {
      _currentIndex = fileItems.length - 1;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemCount: fileItems.length,
              itemBuilder: (context, index) {
                return Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: UniversalImage(
                      path: fileItems[index].path,
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${fileItems.length}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    ref.read(uploadProvider.notifier).removeFile(_currentIndex);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline,
                            color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text('Remove this photo',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
