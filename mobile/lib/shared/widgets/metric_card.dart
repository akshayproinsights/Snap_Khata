import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

enum MetricTheme { blue, amber, red, green, defaultTheme }

class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final MetricTheme theme;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isLinkAction;
  final double? trendValue;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.theme = MetricTheme.defaultTheme,
    this.actionLabel,
    this.onAction,
    this.isLinkAction = false,
    this.trendValue,
  });

  Color _getBorderColor() {
    switch (theme) {
      case MetricTheme.blue:
        return const Color(0xFFBFDBFE);
      case MetricTheme.amber:
        return const Color(0xFFFDE68A);
      case MetricTheme.red:
        return const Color(0xFFFECACA);
      case MetricTheme.green:
        return const Color(0xFFBBF7D0);
      case MetricTheme.defaultTheme:
        return AppTheme.border;
    }
  }

  Color _getIconBgColor() {
    switch (theme) {
      case MetricTheme.blue:
        return const Color(0xFFDBEAFE);
      case MetricTheme.amber:
        return const Color(0xFFFEF3C7);
      case MetricTheme.red:
        return const Color(0xFFFEE2E2);
      case MetricTheme.green:
        return const Color(0xFFDCFCE7);
      case MetricTheme.defaultTheme:
        return const Color(0xFFF3F4F6);
    }
  }

  Color _getAccentColor() {
    switch (theme) {
      case MetricTheme.blue:
        return const Color(0xFF2563EB);
      case MetricTheme.amber:
        return const Color(0xFFD97706);
      case MetricTheme.red:
        return const Color(0xFFDC2626);
      case MetricTheme.green:
        return const Color(0xFF16A34A);
      case MetricTheme.defaultTheme:
        return const Color(0xFF4B5563);
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _getBorderColor();
    final iconBgColor = _getIconBgColor();
    final accentColor = _getAccentColor();

    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onAction,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Icon Box
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: accentColor, size: 22),
                ),
                const SizedBox(width: 10),

                // Center Content (Title + Value + Trend)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                            height: 1.1,
                          ),
                        ),
                      ),
                      if (trendValue != null)
                        Text(
                          '${trendValue! >= 0 ? '▲' : '▼'} ${trendValue!.abs().toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: trendValue! >= 0
                                ? const Color(0xFF16A34A)
                                : AppTheme.error,
                          ),
                        ),
                    ],
                  ),
                ),

                // Action Button / Link
                if (actionLabel != null) ...[
                  const SizedBox(width: 4),
                  if (isLinkAction)
                    Flexible(
                      child: Text(
                        actionLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                    )
                  else
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: theme == MetricTheme.amber
                              ? const Color(0xFFF59E0B)
                              : accentColor,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            )
                          ],
                        ),
                        child: Text(
                          actionLabel!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: theme == MetricTheme.amber
                                ? const Color(0xFF111827)
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.1, duration: 400.ms, curve: Curves.easeOutQuad);
  }
}
