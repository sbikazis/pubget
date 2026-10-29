import 'package:flutter/foundation.dart';

/// Spec §2.3 — the canonical shapes a Pubget link may arrive in.
///
/// This parser is deliberately **total and side-effect free**: it classifies a
/// URI and normalises it to an internal app route. It never calls the network
/// and never throws, so a malformed link degrades to [DeepLinkKind.unknown]
/// instead of crashing the pre-first-frame path.
///
/// It accepts both the canonical forms and the legacy forms that were already
/// shared into the wild (`/fan-work/{id}`, `/hashtag?tag=`, `/profile?uid=`).
/// A shared link cannot be recalled, so old shapes have to keep resolving
/// forever — but new ones are built canonically.
enum DeepLinkKind {
  profile,
  reel,
  work,
  hashtag,
  audio,
  group,
  event,
  anime,
  character,
  store,
  unknown,
}

@immutable
final class DeepLinkTarget {
  const DeepLinkTarget({
    required this.kind,
    required this.id,
    this.extra = const <String, String>{},
    this.legacy = false,
  });

  final DeepLinkKind kind;
  final String id;
  final Map<String, String> extra;

  /// True when the URI used a shape Pubget no longer emits. Kept so analytics
  /// can measure how much legacy traffic is still in circulation before anyone
  /// considers dropping support.
  final bool legacy;

  bool get isResolvable => kind != DeepLinkKind.unknown && id.trim().isNotEmpty;

  /// The internal route this link should open.
  ///
  /// Only routes the app actually registers are produced. Notably `/reel/{id}`
  /// resolves to the Reels feed with a highlight parameter rather than a
  /// `/reel/{id}` route, because that is the path home_shell and the Reels
  /// screen already understand — inventing a second route would produce a
  /// dead end that looks like it works.
  String get appRoute => switch (kind) {
    DeepLinkKind.reel => '/reels?highlight=${Uri.encodeQueryComponent(id)}',
    DeepLinkKind.work => '/fan-work/$id',
    DeepLinkKind.hashtag => '/hashtag?tag=${Uri.encodeQueryComponent(id)}',
    DeepLinkKind.audio => '/audio/$id',
    DeepLinkKind.group => '/group/$id',
    DeepLinkKind.event => '/event/$id',
    DeepLinkKind.anime => '/anime/$id',
    DeepLinkKind.character => '/anime/character/$id',
    // The Store screen is addressed by `/store/item?itemId=`, not `/store/{id}`.
    DeepLinkKind.store => '/store/item?itemId=${Uri.encodeQueryComponent(id)}',
    DeepLinkKind.profile => '/profile?uid=$id',
    DeepLinkKind.unknown => '/unknown',
  };

  /// True when [id] is a handle that still needs resolving to a uid.
  ///
  /// `/profile/{username}` is the canonical human-readable shape, but the
  /// profile screen is addressed by uid. The parser reports that honestly
  /// rather than pretending the handle *is* the uid and opening a blank
  /// profile.
  bool get needsUsernameResolution => kind == DeepLinkKind.profile;

  static DeepLinkTarget? parseString(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    return parse(uri);
  }

  static DeepLinkTarget? parse(Uri uri) {
    final segments = <String>[
      for (final segment in uri.pathSegments)
        if (segment.isNotEmpty) segment,
    ];
    final query = uri.queryParameters;

    DeepLinkTarget make(
      DeepLinkKind kind,
      String id, {
      Map<String, String> extra = const <String, String>{},
      bool legacy = false,
    }) {
      final cleaned = _clean(kind, id);
      if (cleaned.isEmpty) {
        return const DeepLinkTarget(kind: DeepLinkKind.unknown, id: '');
      }
      return DeepLinkTarget(
        kind: kind,
        id: cleaned,
        extra: extra,
        legacy: legacy,
      );
    }

    if (segments.isEmpty) {
      return const DeepLinkTarget(kind: DeepLinkKind.unknown, id: '');
    }

    final head = segments.first.toLowerCase();
    final second = segments.length > 1 ? segments[1] : null;

    switch (head) {
      case 'profile':
      case 'u':
        if (second != null) {
          return make(DeepLinkKind.profile, second, legacy: head == 'u');
        }
        // Legacy: /profile?uid=abc
        final uid = query['uid'] ?? query['id'];
        if (uid != null) return make(DeepLinkKind.profile, uid, legacy: true);
        return const DeepLinkTarget(kind: DeepLinkKind.unknown, id: '');

      case 'reel':
      case 'reels':
        if (second != null && head == 'reel') {
          return make(DeepLinkKind.reel, second);
        }
        final highlight = query['highlight'] ?? query['id'];
        if (highlight != null) {
          return make(DeepLinkKind.reel, highlight, legacy: head == 'reels');
        }
        return const DeepLinkTarget(kind: DeepLinkKind.unknown, id: '');

      case 'work':
        if (second != null) return make(DeepLinkKind.work, second);
        return const DeepLinkTarget(kind: DeepLinkKind.unknown, id: '');

      case 'fan-work':
      case 'fanwork':
      case 'fanworks':
        if (second != null) {
          return make(DeepLinkKind.work, second, legacy: true);
        }
        return const DeepLinkTarget(kind: DeepLinkKind.unknown, id: '');

      case 'hashtag':
      case 'hashtags':
        if (second != null) return make(DeepLinkKind.hashtag, second);
        final tag = query['tag'] ?? query['q'];
        if (tag != null) return make(DeepLinkKind.hashtag, tag, legacy: true);
        return const DeepLinkTarget(kind: DeepLinkKind.unknown, id: '');

      case 'audio':
        if (second != null && second.toLowerCase() != 'library') {
          return make(DeepLinkKind.audio, second);
        }
        return const DeepLinkTarget(kind: DeepLinkKind.unknown, id: '');

      case 'group':
      case 'g':
        if (second != null) {
          return make(DeepLinkKind.group, second, legacy: head == 'g');
        }
        return const DeepLinkTarget(kind: DeepLinkKind.unknown, id: '');

      case 'event':
        if (second != null) return make(DeepLinkKind.event, second);
        return const DeepLinkTarget(kind: DeepLinkKind.unknown, id: '');

      case 'store':
        if (second != null && second.toLowerCase() != 'item') {
          return make(DeepLinkKind.store, second);
        }
        // `/store/item?itemId=x` is the internal route; accept it as input too.
        final itemId = query['itemId'] ?? query['id'];
        if (itemId != null) {
          return make(DeepLinkKind.store, itemId, legacy: true);
        }
        return const DeepLinkTarget(kind: DeepLinkKind.unknown, id: '');

      case 'anime':
        if (second == null) {
          return const DeepLinkTarget(kind: DeepLinkKind.unknown, id: '');
        }
        if (second.toLowerCase() == 'character' && segments.length >= 3) {
          return make(DeepLinkKind.character, segments[2]);
        }
        // Reserved sub-trees carry no single entity, so they are not links.
        if (const {
          'ratings',
          'characters',
          'lists',
        }.contains(second.toLowerCase())) {
          return const DeepLinkTarget(kind: DeepLinkKind.unknown, id: '');
        }
        return make(DeepLinkKind.anime, second);

      default:
        return const DeepLinkTarget(kind: DeepLinkKind.unknown, id: '');
    }
  }

  static String _clean(DeepLinkKind kind, String raw) {
    var value = raw.trim();
    switch (kind) {
      case DeepLinkKind.hashtag:
        value = value.replaceAll('#', '').toLowerCase();
      case DeepLinkKind.profile:
        value = value.replaceAll('@', '');
      default:
        break;
    }
    return value;
  }
}
