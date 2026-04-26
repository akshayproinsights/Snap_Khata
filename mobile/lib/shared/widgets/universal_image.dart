import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A widget that handles image rendering across Mobile and Web.
/// 
/// On Mobile, it uses [Image.file].
/// On Web, it uses [Image.network] for Blob URLs.
class UniversalImage extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final BorderRadius? borderRadius;
  final Widget? errorBuilder;

  const UniversalImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit,
    this.borderRadius,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    Widget image;

    if (kIsWeb) {
      // On web, XFile.path is a Blob URL (blob:http://...)
      // Image.file is not supported, so we use Image.network
      image = Image.network(
        path,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return errorBuilder ?? _buildDefaultError();
        },
      );
    } else {
      image = Image.file(
        File(path),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return errorBuilder ?? _buildDefaultError();
        },
      );
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }

  Widget _buildDefaultError() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Icon(Icons.broken_image, color: Colors.grey),
    );
  }
}
