import 'dart:io';

import 'package:video_player/video_player.dart';

Future<Duration?> probeEditDuration(String? path) async {
  if (path == null || path.isEmpty) return null;
  final controller = VideoPlayerController.file(File(path));
  try {
    await controller.initialize();
    return controller.value.duration;
  } catch (_) {
    return null;
  } finally {
    await controller.dispose();
  }
}
