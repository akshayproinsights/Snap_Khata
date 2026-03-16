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
import 'package:mobile/features/inventory/presentation/providers/inventory_upload_provider.dart';
import 'package:mobile/features/upload/domain/models/upload_models.dart';
import 'package:mobile/features/upload/presentation/providers/camera_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
    final s = ref.read(inventoryUploadProvider);
    if (s.isActive || _isCheckingBackend) return;

    try {
      HapticFeedback.mediumImpact();
      final xFile = await cam.takePicture();
      await ref.read(inventoryUploadProvider.notifier).addFiles([xFile]);
    } catch (e) {
      if (mounted) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture failed: $e')),
        );
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
    final state = ref.watch(inventoryUploadProvider);

    // Auto-navigate to inventory-review when done
    ref.listen(inventoryUploadProvider, (previous, next) async {
      if (next.allDone && previous!.allDone != true) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (!context.mounted) return;
        ref.read(inventoryUploadProvider.notifier).clearFiles();
        context.go('/inventory-review');
      }
    });

    // ── Error view ────────────────────────────────────────────────────────
    if (state.failedCount > 0 && state.pendingCount == 0) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: _buildBasicAppBar(),
        body: SafeArea(child: Center(child: _buildErrorView(state))),
      );
    }

    // ── Success view ──────────────────────────────────────────────────────
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
        backgroundColor: Colors.black,
        body: _InventoryLoadingOverlay(fileItems: state.fileItems),
      );
    }

    // Stuck files
    final hasStuckFiles =
        state.fileItems.any((f) => f.status == UploadFileStatus.uploading);
    if (hasStuckFiles) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: _InventoryLoadingOverlay(fileItems: state.fileItems),
      );
    }

    // Restoring / checking backend guard
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
                'Checking for active uploads…',
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

    // ── Camera view ───────────────────────────────────────────────────────
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
                      final s = ref.read(inventoryUploadProvider);
                      if (s.isActive) return;
                      ref.read(inventoryUploadProvider.notifier).clearFiles();
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/inventory');
                      }
                    },
                  ),
                  const Spacer(),
                  const Text(
                    '📦  Add Inventory',
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
            context.go('/inventory');
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
          _InvoiceScanOverlay(pulseAnimation: _pulseAnimation),
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(fileItem.path),
                    width: 70,
                    height: 90,
                    fit: BoxFit.cover,
                  ),
                ),
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
          const Text(
            'There was an issue processing your vendor invoices.',
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
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor ?? Colors.white, size: 26),
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
  late final Animation<double> _phaseTransitionAnim;

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
          final maxLen = _processingTips.length > _uploadTips.length
              ? _processingTips.length
              : _uploadTips.length;
          _tipIndex = (_tipIndex + 1) % maxLen;
        });
      }
    });

    // Auto-start processing animation if already in processing state
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

  int _computeStepIndex(double serverRatio) {
    final maxIdx = _processingSteps.length - 1;
    final serverStep = (serverRatio * maxIdx).floor().clamp(0, maxIdx);
    int timeStep = 0;
    if (_processingStartTime != null) {
      final elapsed =
          DateTime.now().difference(_processingStartTime!).inMilliseconds;
      timeStep = (elapsed / 3000).floor().clamp(0, 2);
    }
    final computed = serverStep > timeStep ? serverStep : timeStep;
    if (computed > _highWaterStep) _highWaterStep = computed;
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
    final processingStatus = uploadState.processingStatus;

    if (_wasUploading && isProcessing && !isUploading) {
      _wasUploading = false;
      HapticFeedback.mediumImpact();
      _phaseTransitionController.forward(from: 0);
      _startProcessingAnimation();
    }

    double procServerProgress = 0;
    if (processingStatus != null && processingStatus.total > 0) {
      procServerProgress =
          (processingStatus.processed / processingStatus.total).clamp(0.0, 1.0);
    }

    final stepIndex = _computeStepIndex(procServerProgress);
    final currentStep = _processingSteps[stepIndex];
    final procStepProgress = (stepIndex + 1) / _processingSteps.length;
    // True when we've reached the final step and are waiting for the backend
    // to confirm completion. The progress bar goes indeterminate here — honest
    // signalling that work is happening, not showing a fake "0% complete".
    final isLastStep = !isUploading &&
        stepIndex >= _processingSteps.length - 1 &&
        isProcessing;

    final fileCount = widget.fileItems.length;
    final hasRealFiles = widget.fileItems.any((f) => f.path.isNotEmpty);

    final tips = isUploading ? _uploadTips : _processingTips;
    final safeTipIndex = _tipIndex % tips.length;

    return Container(
      decoration: const BoxDecoration(color: Colors.black),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Column(
          children: [
            // TOP BANNER (no-op, handled by GlobalTaskBanner)
            const SizedBox.shrink(),

            Expanded(
              child: SafeArea(
                top: true,
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height -
                          MediaQuery.of(context).padding.top -
                          MediaQuery.of(context).padding.bottom,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 20),

                            // Phase pill
                            _PhasePill(isUploading: isUploading),

                            const SizedBox(height: 20),

                            // Thumbnail strip
                            if (hasRealFiles)
                              _ThumbnailStrip(fileItems: widget.fileItems),

                            const SizedBox(height: 20),

                            // Main animated icon
                            _PhaseIcon(
                              isUploading: isUploading,
                              uploadProgress: uploadProgress,
                              phaseAnim: _phaseTransitionAnim,
                            ),

                            const SizedBox(height: 24),

                            // Title
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 500),
                              child: Text(
                                isUploading
                                    ? 'Sending your invoice${fileCount > 1 ? 's' : ''}'
                                    : currentStep.title,
                                key: ValueKey(isUploading
                                    ? 'upload_title'
                                    : 'step_$stepIndex'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Subtitle
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 500),
                              transitionBuilder: (child, anim) =>
                                  FadeTransition(
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
                                    ? 'Photos are going directly to storage. You can switch tabs freely.'
                                    : currentStep.sub,
                                key: ValueKey(isUploading
                                    ? 'upload_sub'
                                    : 'sub_$stepIndex'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isUploading
                                      ? Colors.amber.shade300
                                      : Colors.white.withValues(alpha: 0.55),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Progress bar
                            _ProgressBar(
                              isUploading: isUploading,
                              isLastStep: isLastStep,
                              uploadProgress: uploadProgress,
                              procStepProgress: procStepProgress,
                              procServerProgress: procServerProgress,
                              processingBarAnim: _processingBarController,
                            ),

                            const SizedBox(height: 10),

                            // Percentage / step label
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Text(
                                isUploading
                                    ? '${(uploadProgress * 100).toInt()}% uploaded'
                                    : 'Step ${stepIndex + 1} of ${_processingSteps.length}',
                                key: ValueKey(isUploading
                                    ? 'pct_${(uploadProgress * 100).toInt()}'
                                    : 'step_lbl_$stepIndex'),
                                style: TextStyle(
                                  color: isUploading
                                      ? Colors.amber.shade400
                                      : const Color(0xFF0066FF)
                                          .withValues(alpha: 0.85),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),

                            // Upload warning box
                            if (isUploading) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade900
                                      .withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.red.shade600, width: 1),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.warning_amber_rounded,
                                        color: Colors.orangeAccent, size: 16),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Leaving now will cancel your upload',
                                        style: TextStyle(
                                          color: Colors.orangeAccent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // "Go to HOME" during processing
                            if (!isUploading) ...[
                              const SizedBox(height: 16),
                              TextButton.icon(
                                onPressed: () {
                                  if (context.mounted) {
                                    context.go('/dashboard');
                                  }
                                },
                                icon: const Icon(
                                  Icons.home_outlined,
                                  color: Colors.lightBlueAccent,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Go to HOME — we\'ll notify you when done',
                                  style: TextStyle(
                                    color: Colors.lightBlueAccent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],

                            const Spacer(),

                            // Rotating tips ticker
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 600),
                              child: Container(
                                key: ValueKey(
                                    'tip_${isUploading}_$safeTipIndex'),
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isUploading
                                      ? Colors.amber.shade900
                                          .withValues(alpha: 0.25)
                                      : Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isUploading
                                        ? Colors.amber.shade700
                                            .withValues(alpha: 0.5)
                                        : Colors.white.withValues(alpha: 0.08),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  tips[safeTipIndex],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isUploading
                                        ? Colors.amber.shade300
                                        : Colors.white.withValues(alpha: 0.45),
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Phase pill ──
class _PhasePill extends StatelessWidget {
  final bool isUploading;
  const _PhasePill({required this.isUploading});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(32),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PillChip(label: '📤  Uploading', active: isUploading),
          const SizedBox(width: 4),
          _PillChip(label: '📝  Reading Invoice', active: !isUploading),
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
          color: active ? Colors.white : Colors.white.withValues(alpha: 0.35),
          fontSize: 13,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

// ── Thumbnail strip ──
class _ThumbnailStrip extends StatelessWidget {
  final List<UploadFileItem> fileItems;
  const _ThumbnailStrip({required this.fileItems});

  @override
  Widget build(BuildContext context) {
    final validItems = fileItems.where((f) => f.path.isNotEmpty).toList();
    if (validItems.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        itemCount: validItems.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = validItems[index];
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                Image.file(
                  File(item.path),
                  width: 54,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 54,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.image_not_supported,
                        color: Colors.white38, size: 22),
                  ),
                ),
                Container(
                  width: 54,
                  height: 72,
                  color: Colors.black.withValues(alpha: 0.25),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Animated center icon: upload lock ↔ reading ──
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
    if (isUploading) {
      return _PulsingLockIcon(uploadProgress: uploadProgress);
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      transitionBuilder: (child, anim) => ScaleTransition(
        scale: anim,
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: Container(
        key: const ValueKey('inv_reading_icon'),
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF0066FF).withValues(alpha: 0.12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0066FF).withValues(alpha: 0.25),
              blurRadius: 32,
              spreadRadius: 6,
            ),
          ],
          border: Border.all(
              color: const Color(0xFF0066FF).withValues(alpha: 0.3), width: 2),
        ),
        child: const Icon(
          Icons.inventory_2_rounded,
          color: Color(0xFF0066FF),
          size: 38,
        ),
      ),
    );
  }
}

/// Amber pulsing lock ring — used during the upload phase.
class _PulsingLockIcon extends StatefulWidget {
  final double uploadProgress;
  const _PulsingLockIcon({required this.uploadProgress});

  @override
  State<_PulsingLockIcon> createState() => _PulsingLockIconState();
}

class _PulsingLockIconState extends State<_PulsingLockIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
    _opacity = Tween<double>(begin: 0.4, end: 0.9).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Stack(
        alignment: Alignment.center,
        children: [
          Transform.scale(
            scale: _scale.value,
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      Colors.amber.shade600.withValues(alpha: _opacity.value),
                  width: 3,
                ),
                color: Colors.amber.shade900.withValues(alpha: 0.08),
              ),
            ),
          ),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.amber.shade800.withValues(alpha: 0.18),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.shade600.withValues(alpha: 0.4),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
              border: Border.all(
                  color: Colors.amber.shade500.withValues(alpha: 0.6),
                  width: 2),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 62,
                  height: 62,
                  child: CircularProgressIndicator(
                    value: widget.uploadProgress > 0
                        ? widget.uploadProgress
                        : null,
                    color: Colors.amber.shade400,
                    strokeWidth: 4,
                    strokeCap: StrokeCap.round,
                    backgroundColor:
                        Colors.amber.shade900.withValues(alpha: 0.25),
                  ),
                ),
                Icon(
                  Icons.lock_rounded,
                  color: Colors.amber.shade300,
                  size: 28,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Unified progress bar ──
class _ProgressBar extends StatelessWidget {
  final bool isUploading;
  final bool isLastStep;
  final double uploadProgress;
  final double procStepProgress;
  final double procServerProgress;
  final AnimationController processingBarAnim;

  const _ProgressBar({
    required this.isUploading,
    required this.isLastStep,
    required this.uploadProgress,
    required this.procStepProgress,
    required this.procServerProgress,
    required this.processingBarAnim,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 6,
        child: isUploading
            ? LinearProgressIndicator(
                value: uploadProgress > 0 ? uploadProgress : null,
                backgroundColor: Colors.amber.shade900.withValues(alpha: 0.35),
                valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.amber.shade400),
              )
            // At the last step we don't know exactly when the backend will
            // finish — show an indeterminate pulsing bar instead of a frozen
            // percentage. This is honest: work is happening, not stuck.
            : isLastStep
                ? LinearProgressIndicator(
                    value: null, // indeterminate  → pulses
                    backgroundColor:
                        const Color(0xFF0066FF).withValues(alpha: 0.15),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFF0066FF)),
                  )
                : AnimatedBuilder(
                    animation: processingBarAnim,
                    builder: (_, __) {
                      final blended = procServerProgress > procStepProgress
                          ? procServerProgress
                          : procStepProgress;
                      final animated = processingBarAnim.value;
                      final display = blended > animated ? blended : animated;
                      return LinearProgressIndicator(
                        value: display.clamp(0.0, 1.0),
                        backgroundColor:
                            const Color(0xFF0066FF).withValues(alpha: 0.15),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF0066FF)),
                      );
                    },
                  ),
      ),
    );
  }
}
