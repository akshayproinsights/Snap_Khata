import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final cameraControllerProvider =
    FutureProvider.autoDispose<CameraController>((ref) async {
  try {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw Exception('No cameras available on this device');
    }

    // Find the first back camera
    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      camera,
      ResolutionPreset.veryHigh,
      enableAudio: false,
    );

    try {
      await controller.initialize();
    } catch (e) {
      controller.dispose();
      if (e is CameraException) {
        // Handle specific camera hardware errors
        if (e.code == 'CameraNotReadable' || e.code == 'cameraNotReadable') {
          throw Exception(
            'Camera hardware error: ${e.description}\n\n'
            'Try:\n'
            '1. Restart your device\n'
            '2. Check if another app is using the camera\n'
            '3. Use gallery upload instead'
          );
        }
        throw Exception('Camera error: ${e.description}');
      }
      rethrow;
    }

    ref.onDispose(() {
      controller.dispose();
    });

    return controller;
  } catch (e, stackTrace) {
    // Log detailed error for debugging
    debugPrint('Camera initialization error: $e');
    debugPrint('Stack trace: $stackTrace');
    rethrow;
  }
});
