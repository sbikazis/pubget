import 'package:video_player/video_player.dart';

import 'storage_video_controller_stub.dart'
    if (dart.library.io) 'storage_video_controller_io.dart'
    if (dart.library.html) 'storage_video_controller_web.dart'
    as platform;

Future<VideoPlayerController> createStorageVideoController(
  String storagePath,
) => platform.createStorageVideoController(storagePath);
