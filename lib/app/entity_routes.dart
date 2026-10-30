import '../features/audio/screens/audio_page.dart';
import '../features/hashtags/screens/hashtag_page.dart';
import '../features/reels/screens/reel_details_page.dart';
import 'app_router.dart';

/// Canonical entity routes (Phase 2 entity navigation).
///
/// These are additive: the legacy `/edits`, `/reels` feed routes stay
/// registered, and the router rewrites legacy `?highlight=` links onto
/// `/reel/:reelId`.
abstract final class EntityRoutes {
  static const reel = '/reel';
  static const audio = '/audio';
  static const hashtag = '/hashtag';

  static Map<String, ParameterizedPageBuilder> pages() =>
      <String, ParameterizedPageBuilder>{
        reel: (parameters) =>
            ReelDetailsPage(reelId: parameters['reelId'] ?? ''),
        audio: (parameters) => AudioPage(audioId: parameters['audioId'] ?? ''),
        hashtag: (parameters) => HashtagPage(tag: parameters['tag'] ?? ''),
      };
}
