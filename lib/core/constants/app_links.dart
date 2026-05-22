// lib/core/constants/app_links.dart

class PubgetLinks {
  PubgetLinks._();

  static const String host = 'pubget.app';
  static const String scheme = 'https';

  static String groupLink(String groupId) =>
      '$scheme://$host/group/$groupId';

  static String? extractGroupId(Uri uri) {
    if (uri.host != host) return null;
    final segments = uri.pathSegments;
    if (segments.length >= 2 && segments[0] == 'group') {
      return segments[1];
    }
    return null;
  }
}