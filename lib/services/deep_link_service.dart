import 'package:app_links/app_links.dart';
import '../core/constants/app_links.dart';

class DeepLinkService {
  final AppLinks _appLinks = AppLinks();

  // في app_links 6.x ما فيه getInitialAppLink
  // الرابط الأول يجي عبر الـ stream مباشرة
  Future<Uri?> getInitialLink() async {
    return null; // نخليه null، الـ stream يكفي
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
