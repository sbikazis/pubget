// lib/core/constants/app_links.dart

class AppLinks {
  AppLinks._();

  /// الدومين الرسمي للتطبيق
  static const String host = 'pubget.app';

  /// البروتوكول
  static const String scheme = 'https';

  /// رابط مجموعة
  /// https://pubget.app/group/GROUP_ID
  static String groupLink(String groupId) =>
      '$scheme://$host/group/$groupId';

  /// استخراج groupId من الرابط
  /// يعود بـ null إذا لم يكن رابط مجموعة
  static String? extractGroupId(Uri uri) {
    if (uri.host != host) return null;
    final segments = uri.pathSegments;
    if (segments.length >= 2 && segments[0] == 'group') {
      return segments[1];
    }
    return null;
  }
}