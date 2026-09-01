import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_player/video_player.dart';

Future<VideoPlayerController> createStorageVideoController(
  String storagePath,
) async {
  final bytes = await FirebaseStorage.instance
      .ref(storagePath)
      .getData(100 * 1024 * 1024);
  if (bytes == null) throw StateError('Video data is unavailable.');
  final file = File(
    '${Directory.systemTemp.path}/pubget_${storagePath.hashCode}.video',
  );
  await file.writeAsBytes(bytes, flush: true);
  return VideoPlayerController.file(file);
}
