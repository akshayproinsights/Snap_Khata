import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';

class BBox {
  final double x;
  final double y;
  final double width;
  final double height;

  const BBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

class ReceiptCard extends StatelessWidget {
  final String imageUrl;
  final Map<String, BBox?> bboxes;
  final List<String> highlightFields;
  final double width;
  final VoidCallback? onTap;

  static const Map<String, Color> _fieldColors = {
    'date': Color(0xFF10B981), // Green
    'receipt_number': Color(0xFF3B82F6), // Blue
    'description': Color(0xFF8B5CF6), // Purple
    'quantity': Color(0xFFF59E0B), // Amber
    'rate': Color(0xFFEF4444), // Red
    'amount': Color(0xFFEC4899), // Pink
  };

  const ReceiptCard({
    super.key,
    required this.imageUrl,
    this.bboxes = const {},
    this.highlightFields = const [],
    this.width = 200,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return Container(
        width: width,
        height: width * 1.4,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        alignment: Alignment.center,
        child: const Text(
          'No image',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: 1 / 1.4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Network Image with CachedNetworkImage
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primary,
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: const Color(0xFFFEF2F2),
                    alignment: Alignment.center,
                    child: const Text(
                      '⚠️ Error',
                      style: TextStyle(color: AppTheme.error, fontSize: 12),
                    ),
                  ),
                ),

                // Bounding Boxes Overlay
                if (highlightFields.isNotEmpty)
                  CustomPaint(
                    painter: _BBoxPainter(
                      bboxes: bboxes,
                      highlightFields: highlightFields,
                      colors: _fieldColors,
                    ),
                  ),

                // Map Legend Dots
                if (highlightFields.isNotEmpty)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: highlightFields.map((field) {
                        final color = _fieldColors[field] ?? Colors.grey;
                        return Container(
                          margin: const EdgeInsets.only(right: 4),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                // Tap Hint Overlay
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onTap,
                      splashColor: Colors.black.withOpacity(0.1),
                      highlightColor: Colors.black.withOpacity(0.05),
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

class _BBoxPainter extends CustomPainter {
  final Map<String, BBox?> bboxes;
  final List<String> highlightFields;
  final Map<String, Color> colors;

  _BBoxPainter({
    required this.bboxes,
    required this.highlightFields,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final field in highlightFields) {
      final bbox = bboxes[field] ?? bboxes['${field}_bbox'];
      if (bbox == null) continue;

      final color = colors[field] ?? Colors.grey;

      // Calculate absolute positions based on normalized (0-1) coordinates
      final rect = Rect.fromLTWH(
        bbox.x * size.width,
        bbox.y * size.height,
        bbox.width * size.width,
        bbox.height * size.height,
      );

      // Fill
      final fillPaint = Paint()
        ..color = color.withOpacity(0.15)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        fillPaint,
      );

      // Stroke
      final strokePaint = Paint()
        ..color = color.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        strokePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BBoxPainter oldDelegate) {
    return oldDelegate.bboxes != bboxes ||
        oldDelegate.highlightFields != highlightFields;
  }
}
