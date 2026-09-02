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

  static String gamePath(String gameId) =>
      _encodedPath('/game', gameId) ?? '';

  static String game(String gameId) => canonical(gamePath(gameId));

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
