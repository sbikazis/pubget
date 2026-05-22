// lib/services/deep_link_service.dart

import 'package:app_links/app_links.dart';
import '../core/constants/app_links.dart';

class DeepLinkService {
  final AppLinks _appLinks = AppLinks();

  // ══════════════════════════════════════════════
  // ── الرابط الأولي (التطبيق مغلق)
  // ══════════════════════════════════════════════

  /// يجلب الرابط الذي فتح التطبيق من حالة مغلقة
  Future<Uri?> getInitialLink() async {
    try {
      return await _appLinks.getInitialLink();
    } catch (_) {
      return null;
    }
  }

  // ══════════════════════════════════════════════
  // ── الروابط اللاحقة (التطبيق مفتوح في الخلفية)
  // ══════════════════════════════════════════════

  /// Stream يستمع للروابط الواردة بينما التطبيق شغّال
  Stream<Uri> get linkStream => _appLinks.uriLinkStream;

  // ══════════════════════════════════════════════
  // ── تحليل الرابط
  // ══════════════════════════════════════════════

  /// يحلل الرابط ويستخرج نوعه والـ ID المرتبط به
  DeepLinkResult? parseLink(Uri uri) {
    // رابط مجموعة
    final groupId = AppLinks.extractGroupId(uri);
    if (groupId != null && groupId.isNotEmpty) {
      return DeepLinkResult(
        type: DeepLinkType.group,
        id: groupId,
      );
    }
    return null;
  }
}

// ══════════════════════════════════════════════
// ── موديل نتيجة تحليل الرابط
// ══════════════════════════════════════════════

enum DeepLinkType { group }

class DeepLinkResult {
  final DeepLinkType type;
  final String id;

  const DeepLinkResult({
    required this.type,
    required this.id,
  });
}