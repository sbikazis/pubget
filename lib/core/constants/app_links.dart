// lib/core/constants/app_links.dart

class PubgetLinks {
  PubgetLinks._();

  // الجديد - Firebase Hosting
  static const String host = 'pubget-aaf27.web.app';
  static const String scheme = 'https';

  // للتوافق مع الروابط القديمة
  static const String oldHost = 'pubget.app';

  /// ينشئ رابط مشاركة المجموعة
  static String groupLink(String groupId) =>
      '$scheme://$host/g/$groupId';

  /// يقرأ الـ ID من أي رابط (جديد أو قديم)
  static String? extractGroupId(Uri uri) {
    // 1. الجديد: https://pubget-aaf27.web.app/g/ABC123
    if (uri.host == host) {
      final segments = uri.pathSegments;
      if (segments.length >= 2 && segments[0] == 'g') {
        return segments[1];
      }
      // دعم /open?id=ABC
      if (segments.isNotEmpty && segments[0] == 'open') {
        return uri.queryParameters['id'];
      }
    }

    // 2. القديم: https://pubget.app/group/ABC123
    if (uri.host == oldHost) {
      final segments = uri.pathSegments;
      if (segments.length >= 2 && segments[0] == 'group') {
        return segments[1];
      }
    }

    // 3. القديم جداً: pubget://group?id=ABC
    if (uri.scheme == 'pubget' && uri.host == 'group') {
      return uri.queryParameters['id'];
    }

    return null;
  }
}