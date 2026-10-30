import 'pubget_links.dart';

/// Resolves a stored notification `destination` into a canonical app route.
///
/// Two shapes are accepted so old notification records keep working without a
/// data migration:
///
/// * canonical entity links — `/reel/:id`, `/audio/:id`, `/hashtag/:tag`
/// * legacy feed-highlight links — `/edits?highlight=:id`, `/reels?highlight=:id`
///
/// Legacy links are rewritten to `/reel/:id`, while the recovered id is kept in
/// [legacyHighlightId] so the feed can still focus the clip when it mounts.
final class PubgetDeepLink {
  const PubgetDeepLink._({
    required this.path,
    this.legacyHighlightId,
    this.isLegacy = false,
  });

  /// In-app path accepted by `AppNavigation.go` and the app router.
  final String path;

  /// Reel id carried by a legacy feed-highlight link, if any.
  final String? legacyHighlightId;

  /// Whether [path] was rewritten from a legacy feed-highlight link.
  final bool isLegacy;

  static const _legacyFeedSegments = <String>{'edits', 'reels'};

  static PubgetDeepLink? parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(
      trimmed.startsWith('/') ? 'https://local$trimmed' : trimmed,
    );
    if (uri == null) return null;
    final segments = <String>[
      for (final segment in uri.pathSegments)
        if (segment.isNotEmpty) segment,
    ];
    if (segments.isEmpty) return null;

    if (segments.length == 2 && segments.first == 'reel') {
      final id = segments[1].trim();
      if (id.isEmpty) return null;
      return PubgetDeepLink._(path: PubgetLinks.reelPath(id));
    }

    if (segments.length == 1 && _legacyFeedSegments.contains(segments.first)) {
      final highlight = uri.queryParameters['highlight']?.trim() ?? '';
      if (highlight.isNotEmpty) {
        return PubgetDeepLink._(
          path: PubgetLinks.reelPath(highlight),
          legacyHighlightId: highlight,
          isLegacy: true,
        );
      }
    }

    return PubgetDeepLink._(path: trimmed);
  }
}
