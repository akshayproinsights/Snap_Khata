// image_compress_service.dart
// Compresses images on the device BEFORE upload.
//
// Strategy:
//   • Target: ≤ 600 KB, max 1500 px wide/tall, JPEG quality 72
//   • If the image is already within limits → return original bytes (fast-path)
//   • Camera captures (usually 3–8 MB HEIC/PNG/JPEG) → compressed to ~150–400 KB
//   • This alone reduces upload time by 5–10× on typical 4G connections.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImageCompressService {
  // ── Tuning knobs ────────────────────────────────────────────────────────────
  static const int _targetMaxDimension = 1500; // px (Gemini needs ≥ 800 px)
  static const int _targetQuality = 72; // JPEG quality (1–100)
  static const int _targetMaxSizeKb = 600; // Skip if already under this

  /// Compress [sourceFile] and return the resulting [XFile] pointing to the
  /// compressed temp file. If the source is already small enough it is
  /// returned unchanged.
  static Future<XFile> compressFile(XFile sourceFile) async {
    if (kIsWeb) {
      return sourceFile;
    }

    final bytes = await sourceFile.readAsBytes();
    final sizeKb = bytes.length / 1024;

    // ── Fast-path: already small enough ──────────────────────────────────────
    if (sizeKb <= _targetMaxSizeKb) {
      return sourceFile;
    }

    // ── Compress into a temp file ─────────────────────────────────────────────
    // uniqueId prevents parallel compressions of same-named images (e.g.
    // IMG_1234.jpg picked twice) from overwriting each other's temp file.
    final tmpDir = await getTemporaryDirectory();
    final uniqueId =
        '${DateTime.now().millisecondsSinceEpoch}_${sourceFile.hashCode}';
    final outName =
        '${p.basenameWithoutExtension(sourceFile.name)}_${uniqueId}_compressed.jpg';
    final outPath = p.join(tmpDir.path, outName);

    // Always output JPEG for maximum compatibility with the backend optimizer.
    // Note: in flutter_image_compress, minWidth/minHeight are upper-bound
    // dimension limits (image won't exceed these values).
    final Uint8List? result = await FlutterImageCompress.compressWithFile(
      sourceFile.path,
      minWidth: _targetMaxDimension,
      minHeight: _targetMaxDimension,
      quality: _targetQuality,
      format: CompressFormat.jpeg,
      keepExif: false, // strip GPS/EXIF metadata → smaller file
    );

    if (result == null || result.isEmpty) {
      // Compression failed — return original
      return sourceFile;
    }

    // Write compressed bytes to temp file
    await File(outPath).writeAsBytes(result);

    return XFile(outPath, name: outName);
  }

  /// Compress a list of files in parallel (using Future.wait).
  /// Returns a list of compressed [XFile] objects in the same order.
  static Future<List<XFile>> compressFiles(List<XFile> files) async {
    return Future.wait(files.map(compressFile));
  }
}
