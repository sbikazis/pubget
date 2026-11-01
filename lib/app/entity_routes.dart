import 'package:flutter/material.dart';

import '../features/audio/screens/audio_page.dart';
import '../features/hashtags/screens/hashtag_page.dart';
import '../features/reels/screens/reel_details_page.dart';
import '../features/kirari/screens/kirari_reel_details_page.dart';
import '../features/kirari/screens/kirari_moderation_page.dart';
import '../features/edits/repositories/edits_repository.dart';
import 'package:provider/provider.dart';
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
  static const moderation = '/admin/kirari-moderation';

  static Map<String, ParameterizedPageBuilder> pages() =>
      <String, ParameterizedPageBuilder>{
        reel: (parameters) => _ReelEntityPage(reelId: parameters['reelId'] ?? ''),
        audio: (parameters) => AudioPage(audioId: parameters['audioId'] ?? ''),
        hashtag: (parameters) => HashtagPage(tag: parameters['tag'] ?? ''),
        moderation: (_) => const KirariModerationPage(),
      };
}

class _ReelEntityPage extends StatelessWidget {
  const _ReelEntityPage({required this.reelId});
  final String reelId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
      future: context.read<EditsRepository>().getEdit(reelId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final edit = snapshot.data?.valueOrNull;
        return edit != null
            ? ReelDetailsPage(reelId: reelId)
            : KirariReelDetailsPage(reelId: reelId);
      },
    );
  }
}
