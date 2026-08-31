// lib/core/constants/app_links.dart

class PubgetLinks {
  PubgetLinks._();

  static const String host = 'pubget-aaf27.web.app';
  static const String scheme = 'https';
  static const String oldHost = 'pubget.app';

  // معرف الحزمة الخاص بتطبيقك على متجر قوقل بلاي
  static const String packageName = 'com.sbikazis.pubget'; 

  /// 🐉 توليد رابط الدعوة الأسطوري الموجه لمتجر جوجل بلاي مباشرة
  /// هذا الرابط يضمن نقل كود الدعوة للمستخدم غير المحمل للتطبيق عبر الـ Play Store Referrer
  static String referralStoreLink(String referrerId) {
    return 'https://play.google.com/store/apps/details?id=$packageName&referrer=utm_source%3Dpubget%26utm_medium%3Dreferral%26utm_campaign%3Dinvite_%26referrer_id%3D$referrerId';
  }

  /// ينشئ رابط مشاركة المجموعة
  static String groupLink(String groupId) => '$scheme://$host/g/$groupId';

  /// يقرأ الـ ID من أي رابط (جديد أو قديم)
  static String? extractGroupId(Uri uri) {
    if (uri.host == host) {
      final segments = uri.pathSegments;
      if (segments.length >= 2 && segments[0] == 'g') {
        return segments[1];
      }
      if (segments.isNotEmpty && segments[0] == 'open') {
        return uri.queryParameters['id'];
      }
    }

    if (uri.host == oldHost) {
      final segments = uri.pathSegments;
      if (segments.length >= 2 && segments[0] == 'group') {
        return segments[1];
      }
    }

    if (uri.scheme == 'pubget' && uri.host == 'group') {
      return uri.queryParameters['id'];
    }

    return null;
  }
}