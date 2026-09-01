import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_player/video_player.dart';

Future<VideoPlayerController> createStorageVideoController(
  String storagePath,
) async {
  final url = await FirebaseStorage.instance.ref(storagePath).getDownloadURL();
  return VideoPlayerController.networkUrl(Uri.parse(url));
}
