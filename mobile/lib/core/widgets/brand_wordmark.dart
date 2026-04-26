import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_theme.dart';

class BrandWordmark extends StatelessWidget {
  final double fontSize;
  final FontWeight fontWeight;
  final Color? snapColor;
  final bool useHero;

  const BrandWordmark({
    super.key,
    this.fontSize = 24,
    this.fontWeight = FontWeight.w900,
    this.snapColor,
    this.useHero = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary = snapColor ?? (Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.primary);
    
    final text = RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: -0.5,
          fontFamily: 'Inter',
        ),
        children: [
          TextSpan(
            text: 'Snap',
            style: TextStyle(color: primary),
          ),
          const TextSpan(
            text: 'Khata',
            style: TextStyle(color: AppTheme.neonGreen),
          ),
        ],
      ),
    );

    if (useHero) {
      return Hero(
        tag: 'brand_wordmark',
        child: Material(
          color: Colors.transparent,
          child: text,
        ),
      );
    }

    return text;
  }
}
