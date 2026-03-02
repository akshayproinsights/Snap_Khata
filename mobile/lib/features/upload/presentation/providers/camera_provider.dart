import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final cameraControllerProvider =
    FutureProvider.autoDispose<CameraController>((ref) async {
  final cameras = await availableCameras();
  if (cameras.isEmpty) {
    throw Exception('No cameras available');
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

  await controller.initialize();

  ref.onDispose(() {
    controller.dispose();
  });

  return controller;
});
