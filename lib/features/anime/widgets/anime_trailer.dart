import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/pubget_snackbars.dart';
import '../../../core/theme/app_spacing.dart';
import '../l10n/anime_copy.dart';
import '../theme/anime_hub_colors.dart';

/// Opens the trailer in a full-screen in-app player.
///
/// Trailers arrive as YouTube watch URLs from both Jikan and AniList, so this
/// pulls the video id out of whatever shape the provider used and plays it
/// without leaving the app.
Future<void> showAnimeTrailerPlayer(
  BuildContext context, {
  required String trailerUrl,
}) {
  final videoId = youtubeVideoIdFrom(trailerUrl);
  if (videoId == null) {
    // Nothing playable: say so instead of opening a player that cannot load.
    PubgetSnackbars.showInfo(context, AnimeCopy.of(context).trailerUnavailable);
    return Future<void>.value();
  }
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _AnimeTrailerPlayer(videoId: videoId),
    ),
  );
}

/// Extracts the eleven character YouTube id from a watch, embed or short link.
String? youtubeVideoIdFrom(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  final host = uri.host.toLowerCase();
  if (host == 'youtu.be' || host == 'www.youtu.be') {
    final segment = uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    return segment == null || segment.isEmpty ? null : segment;
  }
  // An exact allowlist, not a suffix check: `notyoutube.com` ends with
  // `youtube.com` and would otherwise hand its id to the player.
  const hosts = <String>{
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
    'youtube-nocookie.com',
    'www.youtube-nocookie.com',
  };
  if (!hosts.contains(host)) return null;
  final fromQuery = uri.queryParameters['v'];
  if (fromQuery != null && fromQuery.isNotEmpty) return fromQuery;
  // /embed/<id> and /shorts/<id> carry the id in the path.
  if (uri.pathSegments.length >= 2) return uri.pathSegments[1];
  return null;
}

class _AnimeTrailerPlayer extends StatelessWidget {
  const _AnimeTrailerPlayer({required this.videoId});

  final String videoId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          AnimeCopy.of(context).trailer,
          style: theme.textTheme.titleMedium,
        ),
      ),
      body: Center(
        child: YoutubePlayer(
          controller: YoutubePlayerController(
            initialVideoId: videoId,
            flags: const YoutubePlayerFlags(autoPlay: true),
          ),
        ),
      ),
    );
  }
}

/// The 16:9 trailer tile with a play badge, shown in place of the plain
/// "Trailer" button so it reads as media rather than as a link.
class AnimeTrailerTile extends StatelessWidget {
  const AnimeTrailerTile({required this.trailerUrl, super.key});

  final String trailerUrl;

  @override
  Widget build(BuildContext context) {
    final copy = AnimeCopy.of(context);
    final hub = AnimeHubColors.of(context);
    final theme = Theme.of(context);
    final playable = youtubeVideoIdFrom(trailerUrl) != null;
    return InkWell(
      key: const Key('anime-trailer'),
      onTap: playable
          ? () => showAnimeTrailerPlayer(context, trailerUrl: trailerUrl)
          : null,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[hub.gradient.first, hub.gradient.last],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.lg,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 30,
                  color: playable ? hub.gold : theme.disabledColor,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  playable ? copy.trailer : copy.trailerUnavailable,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(
                Icons.open_in_new,
                size: 18,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
