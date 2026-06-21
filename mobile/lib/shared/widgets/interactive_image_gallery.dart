import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/shared/widgets/mobile_dialog.dart';
import 'package:mobile/shared/widgets/robust_receipt_image.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
// ignore: depend_on_referenced_packages
import 'package:vector_math/vector_math_64.dart' as vm;

class InteractiveImageGallery extends StatefulWidget {
  final List<String> imageUrls; // Can be paths or network URLs
  final int initialIndex;
  final Function(int)? onDelete;
  final bool isFileBased;
  final String? title;

  const InteractiveImageGallery({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    this.onDelete,
    this.isFileBased = false,
    this.title,
  });

  static Future<void> show(
    BuildContext context, {
    required List<String> imageUrls,
    int initialIndex = 0,
    String? title,
    Function(int)? onDelete,
    bool isFileBased = false,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.95),
        pageBuilder: (context, _, __) {
          return InteractiveImageGallery(
            imageUrls: imageUrls,
            initialIndex: initialIndex,
            title: title,
            onDelete: onDelete,
            isFileBased: isFileBased,
          );
        },
        transitionsBuilder: (context, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<InteractiveImageGallery> createState() =>
      _InteractiveImageGalleryState();
}

class _InteractiveImageGalleryState extends State<InteractiveImageGallery> {
  late PageController _pageController;
  late int _currentIndex;
  late List<String> _currentImages;
  late List<GlobalKey<_InteractiveImagePageState>> _pageKeys;
  bool _isZoomedIn = false;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _currentImages = List.from(widget.imageUrls);
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _initPageKeys();
  }

  void _initPageKeys() {
    _pageKeys = List.generate(
      _currentImages.length,
      (_) => GlobalKey<_InteractiveImagePageState>(),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleDelete() async {
    final shouldDelete = await MobileDialog.showConfirmation(
      context: context,
      title: 'Delete this image?',
      message:
          'Are you sure you want to remove this image? This action cannot be undone.',
      isDestructive: true,
      confirmText: 'Delete',
    );

    if (shouldDelete == true && mounted) {
      widget.onDelete?.call(_currentIndex);
      setState(() {
        _currentImages.removeAt(_currentIndex);
        _pageKeys.removeAt(_currentIndex);
        if (_currentImages.isEmpty) {
          Navigator.of(context).pop();
        } else {
          // Adjust index if we deleted the last item
          if (_currentIndex >= _currentImages.length) {
            _currentIndex = _currentImages.length - 1;
            _pageController.jumpToPage(_currentIndex);
          }
        }
      });
    }
  }

  Future<void> _handleShare() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final currentUrl = _currentImages[_currentIndex];
      if (widget.isFileBased) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(currentUrl)],
            text: widget.title ?? 'Invoice',
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preparing bill photo to share...'),
            duration: Duration(milliseconds: 800),
          ),
        );
        // Download file to temp directory for direct file sharing
        final tempDir = await getTemporaryDirectory();
        final fileName = 'bill_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final tempFilePath = '${tempDir.path}/$fileName';

        await Dio().download(currentUrl, tempFilePath);

        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(tempFilePath, mimeType: 'image/jpeg')],
            text: widget.title ?? 'Invoice',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  void _zoomIn() {
    if (_currentIndex < _pageKeys.length) {
      _pageKeys[_currentIndex].currentState?.zoomIn();
    }
  }

  void _zoomOut() {
    if (_currentIndex < _pageKeys.length) {
      _pageKeys[_currentIndex].currentState?.zoomOut();
    }
  }

  void _resetZoom() {
    if (_currentIndex < _pageKeys.length) {
      _pageKeys[_currentIndex].currentState?.resetZoom();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentImages.isEmpty) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Dismissible Background wrapper (only dismiss via vertical swipe when fully zoomed out)
          GestureDetector(
            onVerticalDragEnd: _isZoomedIn
                ? null
                : (details) {
                    if (details.primaryVelocity! > 200 ||
                        details.primaryVelocity! < -200) {
                      Navigator.of(context).pop();
                    }
                  },
            child: PageView.builder(
              controller: _pageController,
              itemCount: _currentImages.length,
              physics: _isZoomedIn
                  ? const NeverScrollableScrollPhysics() // Disable paging when zoomed to prevent swipe conflict
                  : const BouncingScrollPhysics(),
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                  _isZoomedIn = false;
                });
              },
              itemBuilder: (context, index) {
                return InteractiveImagePage(
                  key: _pageKeys[index],
                  imageUrl: _currentImages[index],
                  isFileBased: widget.isFileBased,
                  onScaleChanged: (scale) {
                    final zoomed = scale > 1.01;
                    if (zoomed != _isZoomedIn) {
                      setState(() {
                        _isZoomedIn = zoomed;
                      });
                    }
                  },
                );
              },
            ),
          ),

          // Top Overlay UI (Header Bar)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back/Close Button
                    IconButton(
                      icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                        padding: const EdgeInsets.all(10),
                      ),
                    ),

                    // Title
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.title ?? 'Bill Photo',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                letterSpacing: -0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_currentImages.length > 1) ...[
                              const SizedBox(height: 2),
                              Text(
                                '${_currentIndex + 1} of ${_currentImages.length}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Actions
                    Row(
                      children: [
                        IconButton(
                          icon: _isSharing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(LucideIcons.share2, color: Colors.white),
                          onPressed: _handleShare,
                          tooltip: 'Share Bill',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black45,
                            padding: const EdgeInsets.all(10),
                          ),
                        ),
                        if (widget.onDelete != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(LucideIcons.trash2,
                                color: Colors.redAccent),
                            onPressed: _handleDelete,
                            tooltip: 'Delete Photo',
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black45,
                              padding: const EdgeInsets.all(10),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Floating Zoom Pill
          Positioned(
            bottom: 40 + MediaQuery.of(context).padding.bottom,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white12, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Zoom Out
                    IconButton(
                      icon: const Icon(LucideIcons.minus, color: Colors.white, size: 20),
                      onPressed: _zoomOut,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 16),
                    // Reset indicator / action
                    InkWell(
                      onTap: _resetZoom,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isZoomedIn
                              ? AppTheme.primary.withValues(alpha: 0.3)
                              : Colors.white12,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isZoomedIn
                                ? AppTheme.primary.withValues(alpha: 0.5)
                                : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _isZoomedIn ? 'RESET' : '1.0x',
                          style: TextStyle(
                            color: _isZoomedIn ? Colors.white : Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Zoom In
                    IconButton(
                      icon: const Icon(LucideIcons.plus, color: Colors.white, size: 20),
                      onPressed: _zoomIn,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class InteractiveImagePage extends StatefulWidget {
  final String imageUrl;
  final bool isFileBased;
  final ValueChanged<double> onScaleChanged;

  const InteractiveImagePage({
    super.key,
    required this.imageUrl,
    required this.isFileBased,
    required this.onScaleChanged,
  });

  @override
  State<InteractiveImagePage> createState() => _InteractiveImagePageState();
}

class _InteractiveImagePageState extends State<InteractiveImagePage>
    with SingleTickerProviderStateMixin {
  late TransformationController _transformationController;
  late AnimationController _animationController;
  Animation<Matrix4>? _matrixAnimation;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _animationController.addListener(() {
      if (_matrixAnimation != null) {
        _transformationController.value = _matrixAnimation!.value;
      }
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _animateToMatrix(Matrix4 targetMatrix) {
    _matrixAnimation = Matrix4Tween(
      begin: _transformationController.value,
      end: targetMatrix,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward(from: 0.0);
  }

  void zoomIn() {
    final currentMatrix = _transformationController.value;
    final currentScale = currentMatrix.storage[0];
    if (currentScale >= 4.0) return;

    final nextScale = (currentScale + 0.75).clamp(1.0, 4.0);
    final size = context.size ?? const Size(400, 600);
    final center = Offset(size.width / 2, size.height / 2);

    final targetMatrix = Matrix4.identity()
      ..translateByVector3(vm.Vector3(-center.dx * (nextScale - 1), -center.dy * (nextScale - 1), 0.0))
      ..scaleByVector3(vm.Vector3(nextScale, nextScale, 1.0));
    _animateToMatrix(targetMatrix);
    widget.onScaleChanged(nextScale);
  }

  void zoomOut() {
    final currentMatrix = _transformationController.value;
    final currentScale = currentMatrix.storage[0];
    if (currentScale <= 1.0) return;

    final nextScale = (currentScale - 0.75).clamp(1.0, 4.0);
    if (nextScale == 1.0) {
      resetZoom();
    } else {
      final size = context.size ?? const Size(400, 600);
      final center = Offset(size.width / 2, size.height / 2);

      final targetMatrix = Matrix4.identity()
        ..translateByVector3(vm.Vector3(-center.dx * (nextScale - 1), -center.dy * (nextScale - 1), 0.0))
        ..scaleByVector3(vm.Vector3(nextScale, nextScale, 1.0));
      _animateToMatrix(targetMatrix);
      widget.onScaleChanged(nextScale);
    }
  }

  void resetZoom() {
    _animateToMatrix(Matrix4.identity());
    widget.onScaleChanged(1.0);
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    final currentMatrix = _transformationController.value;
    final currentScale = currentMatrix.storage[0];

    if (currentScale > 1.01) {
      resetZoom();
    } else {
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      // Target scale 3.0x, centered around tap position
      final targetMatrix = Matrix4.identity()
        ..translateByVector3(vm.Vector3(-position.dx * 2.0, -position.dy * 2.0, 0.0))
        ..scaleByVector3(vm.Vector3(3.0, 3.0, 1.0));
      _animateToMatrix(targetMatrix);
      widget.onScaleChanged(3.0);
    }
  }

  Widget _buildImageProvider(String url) {
    if (widget.isFileBased) {
      return Image.file(
        File(url),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.imageOff, color: Colors.white54, size: 48),
              SizedBox(height: 16),
              Text('Failed to load image',
                  style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      );
    } else {
      return RobustReceiptImageFullScreen(
        imageUrl: url,
        maxRetries: 3,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: _handleDoubleTapDown,
      onDoubleTap: _handleDoubleTap,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return InteractiveViewer(
            transformationController: _transformationController,
            minScale: 0.8,
            maxScale: 5.0,
            onInteractionUpdate: (details) {
              final scale = _transformationController.value.storage[0];
              widget.onScaleChanged(scale);
            },
            onInteractionEnd: (details) {
              final scale = _transformationController.value.storage[0];
              if (scale < 1.0) {
                resetZoom();
              }
            },
            child: Center(
              child: _buildImageProvider(widget.imageUrl),
            ),
          );
        },
      ),
    );
  }
}
