import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/upload/domain/models/upload_models.dart';
import 'package:mobile/features/upload/presentation/providers/upload_provider.dart';
import 'package:mobile/features/upload/presentation/providers/camera_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

class UploadPage extends ConsumerStatefulWidget {
  const UploadPage({super.key});

  @override
  ConsumerState<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends ConsumerState<UploadPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _flashOn = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Re-attach overlay if processing is still running, or navigate to
    // review if it completed while the user was away.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(uploadProvider.notifier).resumeIfActive();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _capture(CameraController cam) async {
    try {
      HapticFeedback.mediumImpact();
      final xFile = await cam.takePicture();
      await ref.read(uploadProvider.notifier).addFiles([xFile]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture failed: $e')),
        );
      }
    }
  }

  Future<void> _pickGallery() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        imageQuality: 80,
      );
      if (pickedFiles.isNotEmpty) {
        await ref.read(uploadProvider.notifier).addFiles(pickedFiles);
      }
    } catch (e) {
      if (mounted) {
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
    ref.listen(uploadProvider, (previous, next) {
      if (next.allDone && (previous?.allDone != true)) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            ref.read(uploadProvider.notifier).clearFiles();
            context.go('/review');
          }
        });
      }
    });

    if (state.hasDuplicate ||
        (state.failedCount > 0 && state.pendingCount == 0)) {
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
                        context.go('/dashboard');
                      }
                    },
                  ),
                  const Spacer(),
                  const Text(
                    '📄  Snap Orders',
                    style: TextStyle(
                        color: Colors.white,
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
      title: const Text('New Order',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
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
            context.go('/dashboard');
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
                if (state.fileItems.isNotEmpty) _buildThumbnailsList(state),
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(fileItem.path),
                      width: 70,
                      height: 90,
                      fit: BoxFit.cover,
                    ),
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
          colors: [Colors.black.withOpacity(0.85), Colors.transparent],
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
                        color: const Color(0xFF0066FF).withOpacity(0.45),
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
                      ? AppTheme.primary.withOpacity(0.55)
                      : AppTheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                  shadowColor: AppTheme.primary.withOpacity(0.5),
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
              color: AppTheme.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.alertTriangle,
                size: 56, color: AppTheme.error),
          ),
          const SizedBox(height: 24),
          Text(
            state.hasDuplicate ? 'Duplicate Invoice(s)' : 'Upload Failed',
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 12),
          Text(
            state.hasDuplicate
                ? 'Some invoices seem to have already been uploaded previously.'
                : 'There was an issue processing your invoices.',
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
                    if (state.hasDuplicate) {
                      ref.read(uploadProvider.notifier).forceUpload();
                    } else {
                      ref.read(uploadProvider.notifier).retryFailed();
                    }
                  },
                  icon: const Icon(LucideIcons.refreshCw, size: 18),
                  label:
                      Text(state.hasDuplicate ? 'Force Upload' : 'Retry Data'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: state.hasDuplicate
                        ? AppTheme.warning
                        : AppTheme.primary,
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppTheme.success.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(LucideIcons.checkCircle2,
              size: 64, color: AppTheme.success),
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 24),
        const Text(
          'Processing Complete',
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.success),
        ),
        const SizedBox(height: 12),
        const Text(
          'Navigating to review screen...',
          style: TextStyle(fontSize: 15, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 32),
        const CircularProgressIndicator(color: AppTheme.success),
      ],
    ).animate().fadeIn();
  }
}

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
            color: Colors.white.withOpacity(0.15),
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
              color: const Color(0xFF0066FF).withOpacity(0.85),
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
    final dim = Paint()..color = Colors.black.withOpacity(0.42);
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

  static const _tips = [
    '💡 Tip: You can upload multiple orders at the same time',
    '💡 Tip: Clear photos give faster, more accurate results',
    '💡 Tip: All your orders will be ready to review after this',
    '💡 Tip: You can tap any order to edit details before saving',
  ];

  int _stepIndex = 0;
  int _tipIndex = 0;
  bool _wasUploading = true; // track phase transition for haptic

  late final AnimationController _processingBarController;
  late final AnimationController _phaseTransitionController;
  late final Animation<double> _phaseTransitionAnim;

  StreamSubscription<dynamic>? _stepSub;
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
    _phaseTransitionAnim = CurvedAnimation(
      parent: _phaseTransitionController,
      curve: Curves.easeOutCubic,
    );

    // Tip ticker — rotate every 4 seconds
    _tipSub = Stream.periodic(const Duration(seconds: 4)).listen((_) {
      if (mounted) {
        setState(() {
          _tipIndex = (_tipIndex + 1) % _tips.length;
        });
      }
    });
  }

  void _startProcessingAnimation() {
    _processingBarController.forward();
    _stepSub = Stream.periodic(const Duration(milliseconds: 2400)).listen((_) {
      if (mounted) {
        setState(() {
          if (_stepIndex < _processingSteps.length - 1) {
            _stepIndex++;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _stepSub?.cancel();
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
    final processingStatus = uploadState.processingStatus;

    // Detect phase switch: uploading → processing
    if (_wasUploading && isProcessing && !isUploading) {
      _wasUploading = false;
      HapticFeedback.mediumImpact();
      _phaseTransitionController.forward(from: 0);
      _startProcessingAnimation();
    }

    // ── Processing bar blended progress ──
    final procStepProgress = (_stepIndex + 1) / _processingSteps.length;
    // Also use actual poll data if available
    double procServerProgress = 0;
    if (processingStatus != null && processingStatus.total > 0) {
      procServerProgress =
          (processingStatus.processed / processingStatus.total).clamp(0.0, 1.0);
    }

    final currentStep = _processingSteps[_stepIndex];
    final fileCount = widget.fileItems.length;

    return Container(
      decoration: const BoxDecoration(color: Colors.black),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 32),

                // ── Phase pill indicator ──
                _PhasePill(isUploading: isUploading),

                const SizedBox(height: 40),

                // ── Thumbnail strip of uploaded orders ──
                if (widget.fileItems.isNotEmpty)
                  _ThumbnailStrip(fileItems: widget.fileItems),

                const SizedBox(height: 40),

                // ── Main animated icon / ring ──
                _PhaseIcon(
                  isUploading: isUploading,
                  uploadProgress: uploadProgress,
                  phaseAnim: _phaseTransitionAnim,
                ),

                const SizedBox(height: 36),

                // ── Title ──
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: Text(
                    isUploading
                        ? 'Sending your order${fileCount > 1 ? 's' : ''}'
                        : currentStep.title,
                    key: ValueKey(
                        isUploading ? 'upload_title' : 'step_$_stepIndex'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 10),

                // ── Subtitle ──
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.12),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Text(
                    isUploading
                        ? 'Please keep the app open — this will only take a moment'
                        : currentStep.sub,
                    key: ValueKey(
                        isUploading ? 'upload_sub' : 'sub_$_stepIndex'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                  ),
                ),

                const SizedBox(height: 36),

                // ── Progress bar ──
                _ProgressBar(
                  isUploading: isUploading,
                  uploadProgress: uploadProgress,
                  procStepProgress: procStepProgress,
                  procServerProgress: procServerProgress,
                  processingBarAnim: _processingBarController,
                ),

                const SizedBox(height: 14),

                // ── Percentage label ──
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    isUploading
                        ? '${(uploadProgress * 100).toInt()}% uploaded'
                        : 'Step ${_stepIndex + 1} of ${_processingSteps.length}',
                    key: ValueKey(isUploading
                        ? 'pct_${(uploadProgress * 100).toInt()}'
                        : 'step_lbl_$_stepIndex'),
                    style: TextStyle(
                      color: const Color(0xFF0066FF).withOpacity(0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),

                const Spacer(),

                // ── Rotating tips ticker ──
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  child: Container(
                    key: ValueKey('tip_$_tipIndex'),
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.08), width: 1),
                    ),
                    child: Text(
                      _tips[_tipIndex],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Phase pill: shows Upload phase and Smart Reading phase ──
class _PhasePill extends StatelessWidget {
  final bool isUploading;
  const _PhasePill({required this.isUploading});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PillChip(
            label: '📤  Uploading',
            active: isUploading,
          ),
          const SizedBox(width: 4),
          _PillChip(
            label: '📝  Reading Order',
            active: !isUploading,
          ),
        ],
      ),
    );
  }
}

class _PillChip extends StatelessWidget {
  final String label;
  final bool active;
  const _PillChip({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF0066FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.white : Colors.white.withOpacity(0.35),
          fontSize: 13,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

// ── Thumbnail strip of captured order photos ──
class _ThumbnailStrip extends StatelessWidget {
  final List<UploadFileItem> fileItems;
  const _ThumbnailStrip({required this.fileItems});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        itemCount: fileItems.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = fileItems[index];
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                Image.file(
                  File(item.path),
                  width: 54,
                  height: 72,
                  fit: BoxFit.cover,
                ),
                // Subtle darkening overlay so thumbnails don't distract
                Container(
                  width: 54,
                  height: 72,
                  color: Colors.black.withOpacity(0.25),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Animated center icon: upload arrow ↔ reading checkmark ──
class _PhaseIcon extends StatelessWidget {
  final bool isUploading;
  final double uploadProgress;
  final Animation<double> phaseAnim;

  const _PhaseIcon({
    required this.isUploading,
    required this.uploadProgress,
    required this.phaseAnim,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      transitionBuilder: (child, anim) => ScaleTransition(
        scale: anim,
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: Container(
        key: ValueKey(isUploading ? 'upload_icon' : 'reading_icon'),
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF0066FF).withOpacity(0.12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0066FF).withOpacity(0.25),
              blurRadius: 32,
              spreadRadius: 6,
            ),
          ],
          border: Border.all(
              color: const Color(0xFF0066FF).withOpacity(0.3), width: 2),
        ),
        child: isUploading
            ? Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      value: uploadProgress > 0 ? uploadProgress : null,
                      color: const Color(0xFF0066FF),
                      strokeWidth: 4,
                      strokeCap: StrokeCap.round,
                      backgroundColor: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  Icon(
                    Icons.cloud_upload_outlined,
                    color: const Color(0xFF0066FF).withOpacity(0.9),
                    size: 28,
                  ),
                ],
              )
            : const Icon(
                Icons.document_scanner_outlined,
                color: Color(0xFF0066FF),
                size: 38,
              ),
      ),
    );
  }
}

// ── Unified progress bar: upload (real) or reading (blended) ──
class _ProgressBar extends StatelessWidget {
  final bool isUploading;
  final double uploadProgress;
  final double procStepProgress;
  final double procServerProgress;
  final AnimationController processingBarAnim;

  const _ProgressBar({
    required this.isUploading,
    required this.uploadProgress,
    required this.procStepProgress,
    required this.procServerProgress,
    required this.processingBarAnim,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: isUploading
          // Phase 1: real upload progress — AnimatedContainer for smooth fill
          ? TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: uploadProgress),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              builder: (_, value, __) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF0066FF)),
              ),
            )
          // Phase 2: blended step + time progress
          : AnimatedBuilder(
              animation: processingBarAnim,
              builder: (_, __) {
                // Weight: server data > step index > time animation
                final timeP = processingBarAnim.value;
                final blended = procServerProgress > 0
                    ? (procServerProgress * 0.7 +
                            procStepProgress * 0.2 +
                            timeP * 0.1)
                        .clamp(0.0, 0.98)
                    : (procStepProgress * 0.7 + timeP * 0.3).clamp(0.0, 0.98);
                return LinearProgressIndicator(
                  value: blended,
                  minHeight: 8,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Color(0xFF0066FF)),
                );
              },
            ),
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
                    child: Image.file(
                      File(fileItems[index].path),
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
