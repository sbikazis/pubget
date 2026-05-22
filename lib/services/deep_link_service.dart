// lib/services/deep_link_service.dart

import 'package:app_links/app_links.dart';
import '../core/constants/app_links.dart';

class DeepLinkService {
  final AppLinks _appLinks = AppLinks();

  Future<Uri?> getInitialLink() async {
    try {
      return await _appLinks.getInitialLink();
    } catch (_) {
      return null;
    }
  }

  Stream<Uri> get linkStream => _appLinks.uriLinkStream;

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

enum DeepLinkType { group }

class DeepLinkResult {
  final DeepLinkType type;
  final String id;

  const DeepLinkResult({
    required this.type,
    required this.id,
  });
}