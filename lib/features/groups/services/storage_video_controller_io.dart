import 'package:video_player/video_player.dart';

import '../../../core/media/media_reference.dart';

Future<VideoPlayerController> createStorageVideoController(
  String storagePathOrUrl,
) async {
  final url = await resolveMediaDownloadUrl(storagePathOrUrl);
  if (url == null) {
    throw StateError('This video is unavailable or you do not have access.');
  }
  return VideoPlayerController.networkUrl(Uri.parse(url));
}
