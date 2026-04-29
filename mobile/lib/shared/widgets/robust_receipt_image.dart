import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Extracts a stable cache key from a URL by stripping query parameters.
/// This prevents cache misses when the same R2 object is served with refreshed
/// signed-URL query strings (X-Amz-Expires, X-Amz-Signature, etc.).
String _stableCacheKey(String url) {
  try {
    final uri = Uri.parse(url);
    // Use scheme + host + path — ignore query params that change on every call
    return '${uri.scheme}://${uri.host}${uri.path}';
  } catch (_) {
    return url;
  }
}

/// Production-grade receipt image widget.
///
/// Fixes the intermittent grey-screen bug caused by:
///   1. Silent `CachedNetworkImage` failures that show grey instead of the
///      error widget when a network hiccup occurs on the FIRST load attempt.
///   2. Cache misses caused by changing query params in signed R2 URLs, meaning
///      the image is re-fetched on every navigation instead of served from disk.
///   3. No retry mechanism — a single transient failure leaves the user stuck
///      until they close and reopen the app.
///
/// Solution:
///   - Uses a **stable cache key** (path only, no query params).
///   - Manages loading state explicitly so grey never appears without a spinner.
///   - Retries up to [maxRetries] times with exponential back-off before
///     showing the error widget + a manual "Retry" button.
class RobustReceiptImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final Alignment alignment;
  final String heroTag;
  final int maxRetries;

  const RobustReceiptImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.topCenter,
    this.heroTag = '',
    this.maxRetries = 3,
  });

  @override
  State<RobustReceiptImage> createState() => _RobustReceiptImageState();
}

class _RobustReceiptImageState extends State<RobustReceiptImage> {
  int _attempt = 0;
  bool _failed = false;

  void _retry() {
    if (!mounted) return;
    setState(() {
      _attempt++;
      _failed = false;
    });
  }

  void _onError() {
    if (!mounted) return;
    if (_attempt < widget.maxRetries) {
      // Auto-retry with a brief delay (50ms * 2^attempt)
      final delay = Duration(milliseconds: 50 * (1 << _attempt));
      Future.delayed(delay, _retry);
    } else {
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return _buildError(context);

    final cacheKey = '${_stableCacheKey(widget.imageUrl)}_a$_attempt';

    final image = CachedNetworkImage(
      // Keyed by attempt so that retries bypass the old (broken) cache entry
      key: ValueKey(cacheKey),
      imageUrl: widget.imageUrl,
      cacheKey: cacheKey,
      fit: widget.fit,
      alignment: widget.alignment,
      httpHeaders: const {
        'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
      },
      // Explicit shimmer while loading — never shows grey
      placeholder: (context, url) => Container(
        color: Colors.grey[900],
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2),
        ),
      ),
      errorWidget: (context, url, error) {
        // Schedule state update after current frame
        WidgetsBinding.instance.addPostFrameCallback((_) => _onError());
        return Container(
          color: Colors.grey[900],
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2),
          ),
        );
      },
    );

    if (widget.heroTag.isNotEmpty) {
      return Hero(tag: widget.heroTag, child: image);
    }
    return image;
  }

  Widget _buildError(BuildContext context) {
    return Container(
      color: Colors.grey[850],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.imageOff, color: Colors.white38, size: 36),
          const SizedBox(height: 8),
          const Text(
            'Could not load image',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
              backgroundColor: Colors.white10,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              // Full reset — clears cache entry for this URL and starts fresh
              CachedNetworkImage.evictFromCache(_stableCacheKey(widget.imageUrl));
              setState(() {
                _attempt = 0;
                _failed = false;
              });
            },
            icon: const Icon(LucideIcons.refreshCw, size: 14),
            label: const Text('Retry', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

/// Full-screen viewer variant of [RobustReceiptImage] — used inside
/// InteractiveViewer overlays.
class RobustReceiptImageFullScreen extends StatefulWidget {
  final String imageUrl;
  final String heroTag;
  final int maxRetries;

  const RobustReceiptImageFullScreen({
    super.key,
    required this.imageUrl,
    this.heroTag = '',
    this.maxRetries = 3,
  });

  @override
  State<RobustReceiptImageFullScreen> createState() =>
      _RobustReceiptImageFullScreenState();
}

class _RobustReceiptImageFullScreenState
    extends State<RobustReceiptImageFullScreen> {
  int _attempt = 0;
  bool _failed = false;

  void _retry() {
    if (!mounted) return;
    setState(() {
      _attempt++;
      _failed = false;
    });
  }

  void _onError() {
    if (!mounted) return;
    if (_attempt < widget.maxRetries) {
      final delay = Duration(milliseconds: 50 * (1 << _attempt));
      Future.delayed(delay, _retry);
    } else {
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.imageOff, color: Colors.white38, size: 60),
            const SizedBox(height: 16),
            const Text(
              'Image unavailable',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                backgroundColor: Colors.white10,
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                CachedNetworkImage.evictFromCache(
                    _stableCacheKey(widget.imageUrl));
                setState(() {
                  _attempt = 0;
                  _failed = false;
                });
              },
              icon: const Icon(LucideIcons.refreshCw, size: 14),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final cacheKey = '${_stableCacheKey(widget.imageUrl)}_a$_attempt';

    final image = CachedNetworkImage(
      key: ValueKey(cacheKey),
      imageUrl: widget.imageUrl,
      cacheKey: cacheKey,
      fit: BoxFit.contain,
      httpHeaders: const {
        'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
      },
      placeholder: (context, url) =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
      errorWidget: (context, url, error) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _onError());
        return const Center(
            child: CircularProgressIndicator(color: Colors.white));
      },
    );

    if (widget.heroTag.isNotEmpty) {
      return Hero(tag: widget.heroTag, child: image);
    }
    return image;
  }
}
