// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_player/video_player.dart';

Future<VideoPlayerController> createStorageVideoController(
  String storagePath,
) async {
  final bytes = await FirebaseStorage.instance
      .ref(storagePath)
      .getData(100 * 1024 * 1024);
  if (bytes == null) throw StateError('Video data is unavailable.');
  final blob = html.Blob(<Object>[bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  return VideoPlayerController.networkUrl(Uri.parse(url));
}
