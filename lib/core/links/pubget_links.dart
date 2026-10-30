import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../analytics/analytics.dart';
import '../widgets/pubget_snackbars.dart';

/// Single canonical host for shareable Pubget URLs.
abstract final class PubgetLinks {
  static const host = 'pubget-aaf27.web.app';
  static const copiedMessage = 'Link copied';

  static Analytics? analytics;

  @visibleForTesting
  static Future<void> Function(String text, String? subject)? debugNativeShare;

  static String canonical(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty || trimmed == '/') return '';
    final normalized = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return 'https://$host$normalized';
  }

  static String? _encodedPath(String prefix, String id) {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return null;
    return '$prefix/${Uri.encodeComponent(trimmed)}';
  }

  static String eventPath(String eventId) =>
      _encodedPath('/event', eventId) ?? '';

  static String event(String eventId) => canonical(eventPath(eventId));

  static String fanWorkPath(String workId) =>
      _encodedPath('/fan-work', workId) ?? '';

  static String fanWork(String workId) => canonical(fanWorkPath(workId));

  /// Canonical Reel entity link — `/reel/:reelId`.
  static String reelPath(String reelId) => _encodedPath('/reel', reelId) ?? '';

  static String reel(String reelId) => canonical(reelPath(reelId));

  /// Canonical audio entity link — `/audio/:audioId`.
  static String audioPath(String audioId) =>
      _encodedPath('/audio', audioId) ?? '';

  static String audio(String audioId) => canonical(audioPath(audioId));

  /// Canonical hashtag entity link — `/hashtag/:tag`.
  static String hashtagPath(String tag) {
    final normalized = tag.trim().replaceFirst(RegExp(r'^#+'), '');
    return _encodedPath('/hashtag', normalized) ?? '';
  }

  static String hashtag(String tag) => canonical(hashtagPath(tag));

  /// Legacy feed-highlight link, kept for stored links and older clients.
  /// New links use [reelPath].
  static String editHighlightPath(String editId) {
    final trimmed = editId.trim();
    if (trimmed.isEmpty) return '/edits';
    return '/edits?highlight=${Uri.encodeQueryComponent(trimmed)}';
  }

  static String editHighlight(String editId) =>
      canonical(editHighlightPath(editId));

  /// Legacy feed-highlight link for the `/reels` feed. New links use
  /// [reelPath].
  static String reelHighlightPath(String reelId) {
    final trimmed = reelId.trim();
    if (trimmed.isEmpty) return '/reels';
    return '/reels?highlight=${Uri.encodeQueryComponent(trimmed)}';
  }

  static String reelHighlight(String reelId) =>
      canonical(reelHighlightPath(reelId));

  static String gamePath(String gameId) => _encodedPath('/game', gameId) ?? '';

  static String game(String gameId) => canonical(gamePath(gameId));

  static String mafiaPath(String gameId) =>
      _encodedPath('/mafia', gameId) ?? '';

  static String mafia(String gameId) => canonical(mafiaPath(gameId));

  static String animePath(String animeId) =>
      _encodedPath('/anime', animeId) ?? '';

  static String anime(String animeId) => canonical(animePath(animeId));

  static String groupPath(String groupId) =>
      _encodedPath('/group', groupId) ?? '';

  static String group(String groupId) => canonical(groupPath(groupId));

  static String profilePath(String userId) =>
      _encodedPath('/profile', userId) ?? '';

  static String profile(String userId) => canonical(profilePath(userId));

  static Future<void> copy(
    BuildContext context,
    String url, {
    String type = 'link',
    String message = copiedMessage,
  }) async {
    if (url.trim().isEmpty) return;
    analytics?.logEvent('copy_link', parameters: {'type': type});
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    PubgetSnackbars.showInfo(context, message);
  }

  static Future<void> share(
    BuildContext context, {
    required String url,
    String? title,
    String type = 'link',
  }) async {
    if (url.trim().isEmpty) return;
    analytics?.logEvent('share_started', parameters: {'type': type});
    try {
      if (debugNativeShare != null) {
        await debugNativeShare!(url, title);
        analytics?.logEvent('share_completed', parameters: {'type': type});
        return;
      }
      await SharePlus.instance.share(
        ShareParams(text: url, title: title, subject: title),
      );
      analytics?.logEvent('share_completed', parameters: {'type': type});
    } catch (_) {
      if (!context.mounted) return;
      await copy(context, url, type: type);
    }
  }
}
