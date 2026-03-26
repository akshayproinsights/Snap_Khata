import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/shared/widgets/mobile_dialog.dart';
import 'package:cached_network_image/cached_network_image.dart';

class InteractiveImageGallery extends StatefulWidget {
  final List<String> imageUrls; // Can be paths or network URLs
  final int initialIndex;
  final Function(int)? onDelete;
  final bool isFileBased;

  const InteractiveImageGallery({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    this.onDelete,
    this.isFileBased = false,
  });

  static Future<void> show(
    BuildContext context, {
    required List<String> imageUrls,
    int initialIndex = 0,
    Function(int)? onDelete,
    bool isFileBased = false,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.9),
        pageBuilder: (context, _, __) {
          return InteractiveImageGallery(
            imageUrls: imageUrls,
            initialIndex: initialIndex,
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

  @override
  void initState() {
    super.initState();
    _currentImages = List.from(widget.imageUrls);
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
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

  Widget _buildImageProvider(String url) {
    if (widget.isFileBased) {
      return Image.file(
        File(url),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.white54, size: 48),
              SizedBox(height: 16),
              Text('Failed to load image',
                  style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      );
    } else {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
        errorWidget: (context, url, error) => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image, color: Colors.white54, size: 48),
              SizedBox(height: 16),
              Text('Image not found', style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      );
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
          // Dismissible Background (allows dragging down to close on mobile)
          GestureDetector(
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity! > 300 ||
                  details.primaryVelocity! < -300) {
                Navigator.of(context).pop();
              }
            },
            child: PageView.builder(
              controller: _pageController,
              itemCount: _currentImages.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: _buildImageProvider(_currentImages[index]),
                );
              },
            ),
          ),

          // Top Overlay UI
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
                    colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Counter
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / ${_currentImages.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),

                    // Actions
                    Row(
                      children: [
                        if (widget.onDelete != null)
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.white),
                            onPressed: () {
                              _handleDelete();
                            },
                            tooltip: 'Delete',
                            style: IconButton.styleFrom(
                                backgroundColor: Colors.black45),
                          ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: 'Close',
                          style: IconButton.styleFrom(
                              backgroundColor: Colors.black45),
                        ),
                      ],
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
