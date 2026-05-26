// lib/services/deep_link_service.dart
import 'package:app_links/app_links.dart';
import 'package:android_play_install_referrer/android_play_install_referrer.dart';
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
    // تعمل فقط على أجهزة الأندرويد الحقيقية وتتجاهل الويب والمحاكيات لتجنب الأخطاء
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;

    try {
      ReferrerDetails details = await AndroidPlayInstallReferrer.installReferrer;
      String? referrerUrl = details.installReferrer;
      
      if (referrerUrl != null && referrerUrl.contains('referrer_id=')) {
        final uri = Uri.parse('https://dummy.com?$referrerUrl');
        return uri.queryParameters['referrer_id'];
      }
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