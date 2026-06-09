import 'dart:io';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/app_links.dart';

enum DeepLinkType { group, referral }

class DeepLinkResult {
  final DeepLinkType type;
  final String id;

  const DeepLinkResult({
    required this.type,
    required this.id,
  });
}

class DeepLinkService {
  final AppLinks _appLinks = AppLinks();

  Stream<Uri> get linkStream => _appLinks.uriLinkStream;

  /// 🔍 دالة فحص وتتبع التثبيت المؤجل القادم من متجر جوجل بلاي (مستخدمين جدد)
  Future<String?> getDeferredReferrerId() async {
    // تعمل فقط على أندرويد
    if (kIsWeb || !Platform.isAndroid) return null;

    try {
      // android_play_install_referrer أُزيل من pubspec
      // هذه الدالة معطلة مؤقتاً للتوافق مع iOS
      debugPrint('ℹ️ getDeferredReferrerId: غير متاح حالياً');
    } catch (e) {
      debugPrint('❌ فشل قراءة الإحالة من متجر قوقل: $e');
    }
    return null;
  }

  DeepLinkResult? parseLink(Uri uri) {
    final groupId = PubgetLinks.extractGroupId(uri);
    if (groupId != null && groupId.isNotEmpty) {
      return DeepLinkResult(
        type: DeepLinkType.group,
        id: groupId,
      );
    }
    return null;
  }
}