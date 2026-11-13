/// Media references in Firestore come in two shapes and a renderer must never
/// assume either one:
///
/// * a full `https://…` download URL (legacy records, events, avatars), and
/// * a bare Firebase Storage object path (chat media, edits/reels), which the
///   server-side pipelines write directly.
///
/// Feeding a bare path to `Image.network`/`Uri.parse` throws
/// `No host specified in URI`, and handing an `https://…` value to
/// `FirebaseStorage.ref` throws because it is not an object path. These helpers
/// normalize both shapes so every caller resolves the same way.
library;

import 'package:firebase_storage/firebase_storage.dart';

/// True when [reference] is a directly fetchable network URL.
bool isRemoteMediaUrl(String reference) {
  final value = reference.trim();
  return value.startsWith('http://') || value.startsWith('https://');
}

/// True for values that carry a scheme we cannot fetch, e.g. the `pubget://`
/// preset avatar/background identifiers. These are identifiers, not media, so a
/// caller should render its fallback instead of attempting a Storage download.
bool isOpaqueMediaReference(String reference) {
  final value = reference.trim();
  return !isRemoteMediaUrl(value) && value.contains('://');
}

/// Upgrades a legacy cleartext media URL to TLS.
///
/// The release manifest sets `android:usesCleartextTraffic="false"`, so old
/// records written before that hardening (including CDN/R2-era `http://`
/// links) would fail with a cleartext error instead of rendering an image.
/// Every media host in use serves TLS. If a particular host does not, the
/// caller's error widget renders — exactly what would have happened anyway.
/// Web CORS behaviour is unchanged: the scheme upgrade only removes the
/// mixed-content/cleartext rejection on the platforms that enforce it.
String secureMediaUrl(String url) {
  final value = url.trim();
  if (value.startsWith('http://')) return 'https://${value.substring(7)}';
  return value;
}

/// Resolves [reference] to a fetchable URL, or null when it is empty, an opaque
/// identifier, or a Storage lookup that fails. Never throws.
Future<String?> resolveMediaDownloadUrl(String reference) async {
  final value = reference.trim();
  if (value.isEmpty || isOpaqueMediaReference(value)) return null;
  if (isRemoteMediaUrl(value)) return secureMediaUrl(value);
  try {
    final url = await FirebaseStorage.instance.ref(value).getDownloadURL();
    return secureMediaUrl(url);
  } on Object {
    return null;
  }
}

/// The Storage metadata content type for a picked video.
///
/// The gallery picker hands back the raw file name (e.g. an iOS `.MOV`), and
/// `'video/${extension}'` produced types such as `video/mov` that the Storage
/// rules reject (`isVideo()` accepts only `video/mp4`, `video/webm` and
/// `video/quicktime`), so the upload failed with permission-denied. Map known
/// containers to a rule-accepted type; the player and the ffmpeg pipeline both
/// read the container from the bytes, so an mp4 fallback for the long tail
/// (m4v/3gp/avi/mkv) is safe.
String videoContentTypeFor(String fileName) {
  final dot = fileName.lastIndexOf('.');
  final ext = dot >= 0 && dot < fileName.length - 1
      ? fileName.substring(dot + 1).toLowerCase()
      : '';
  switch (ext) {
    case 'webm':
      return 'video/webm';
    case 'mov':
    case 'qt':
      return 'video/quicktime';
    case 'mp4':
    case 'm4v':
    default:
      return 'video/mp4';
  }
}
