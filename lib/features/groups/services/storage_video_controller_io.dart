import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_player/video_player.dart';

import '../../../core/media/media_reference.dart';

Future<VideoPlayerController> createStorageVideoController(
  String storagePath,
) async {
  final reference = storagePath.trim();
  // Chat media and edits store a bare Storage path, while legacy chat records
  // stored a full download URL. Accept both instead of assuming one shape.
  final url = isRemoteMediaUrl(reference)
      ? reference
      : await FirebaseStorage.instance.ref(reference).getDownloadURL();
  return VideoPlayerController.networkUrl(Uri.parse(url));
}
