import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// A widget that handles image rendering across Mobile and Web.
/// 
/// On Mobile, it uses [CachedNetworkImage] for URLs and [Image.file] for local paths.
/// On Web, it uses [Image.network] for Blob URLs.
class UniversalImage extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Alignment alignment;
  final BorderRadius? borderRadius;
  final Widget? errorBuilder;

  const UniversalImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.borderRadius,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    Widget image;

    if (path.isEmpty) {
      return errorBuilder ?? _buildDefaultError();
    }

    if (kIsWeb) {
      // On web, XFile.path is a Blob URL (blob:http://...)
      // Image.file is not supported, so we use Image.network
      image = Image.network(
        path,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        errorBuilder: (context, error, stackTrace) {
          return errorBuilder ?? _buildDefaultError();
        },
      );
    } else {
      if (path.startsWith('http')) {
        image = CachedNetworkImage(
          imageUrl: path,
          width: width,
          height: height,
          fit: fit,
          alignment: alignment,
          placeholder: (context, url) => Container(
            width: width,
            height: height,
            color: Colors.grey[100],
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorWidget: (context, url, error) => errorBuilder ?? _buildDefaultError(),
        );
      } else if (path.startsWith('r2://')) {
        // Backend internal protocol - cannot be rendered directly
        image = errorBuilder ?? _buildDefaultError(message: 'Remote Storage');
      } else {
        // Assume local file path
        try {
          final file = File(path);
          if (!file.existsSync()) {
             return errorBuilder ?? _buildDefaultError();
          }
          image = Image.file(
            file,
            width: width,
            height: height,
            fit: fit,
            alignment: alignment,
            errorBuilder: (context, error, stackTrace) {
              return errorBuilder ?? _buildDefaultError();
            },
          );
        } catch (e) {
          return errorBuilder ?? _buildDefaultError();
        }
      }
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }

  Widget _buildDefaultError({String? message}) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broken_image, color: Colors.grey),
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                message,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
