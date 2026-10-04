import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../edits/l10n/edit_copy.dart';
import '../../edits/providers/edits_provider.dart';
import '../../edits/repositories/edits_repository.dart';
import '../../edits/screens/edit_feed_page.dart';

/// Reels is the product surface for Axis 15. The vertical playback experience
/// lives in [EditFeedPage]; this widget only decides *which* feed is shown.
///
/// Unscoped (the main Reels tab) it reads the app-wide [EditsProvider], so the
/// tab keeps the feed the user last selected. Scoped (hashtag, anime,
/// character, creator, audio) it builds a dedicated provider so opening a
/// deep link never mutates the global feed.
final class ReelsFeedPage extends StatelessWidget {
  const ReelsFeedPage({
    super.key,
    this.audioId,
    this.animeId,
    this.characterId,
    this.hashtag,
    this.creatorId,
    this.title,
    this.embedded = false,
  });

  final String? audioId;
  final String? animeId;
  final String? characterId;
  final String? hashtag;
  final String? creatorId;

  /// Optional scoped title, e.g. `#one_piece`. Falls back to the product name.
  final String? title;

  /// Host screen supplies its own chrome. See [EditFeedPage.embedded].
  final bool embedded;

  bool get _isScoped =>
      audioId != null ||
      animeId != null ||
      characterId != null ||
      (hashtag != null && hashtag!.isNotEmpty) ||
      creatorId != null;

  @override
  Widget build(BuildContext context) {
    if (!_isScoped) return EditFeedPage(embedded: embedded);
    return ChangeNotifierProvider<EditsProvider>(
      create: (context) => EditsProvider(
        repository: context.read<EditsRepository>(),
        audioId: audioId,
        animeId: animeId,
        characterId: characterId,
        hashtag: hashtag,
        creatorId: creatorId,
      ),
      // EditFeedPage.initState owns loading, so nothing is pre-fetched here.
      child: _ScopedReelsChrome(title: title, embedded: embedded),
    );
  }
}

/// Chrome for a scoped feed: a back affordance and a scoped title, while the
/// playback body stays the proven [EditFeedPage].
class _ScopedReelsChrome extends StatelessWidget {
  const _ScopedReelsChrome({required this.title, required this.embedded});

  final String? title;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final copy = EditCopy.of(context);
    final resolved = title ?? copy.feedTitle;
    return EditFeedPage(
      title: resolved,
      embedded: embedded,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: () => AppNavigation.popLayer(context),
      ),
    );
  }
}
