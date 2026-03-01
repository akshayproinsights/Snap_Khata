import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:mobile/core/theme/app_theme.dart';

class ShimmerPlaceholder extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerPlaceholder({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.border.withOpacity(0.5),
      highlightColor: AppTheme.surface,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class MetricCardShimmer extends StatelessWidget {
  const MetricCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border.withOpacity(0.5)),
      ),
      child: const Row(
        children: [
          ShimmerPlaceholder(width: 44, height: 44, borderRadius: 8),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShimmerPlaceholder(width: 80, height: 12),
                SizedBox(height: 6),
                ShimmerPlaceholder(width: 120, height: 24),
                SizedBox(height: 6),
                ShimmerPlaceholder(width: 40, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChartShimmer extends StatelessWidget {
  const ChartShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border.withOpacity(0.5)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerPlaceholder(width: 100, height: 20),
          SizedBox(height: 24),
          Expanded(
            child: ShimmerPlaceholder(
              width: double.infinity,
              height: double.infinity,
              borderRadius: 12,
            ),
          ),
        ],
      ),
    );
  }
}
