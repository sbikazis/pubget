import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_image_loader.dart';
import '../../../core/widgets/pubget_states.dart';
import '../../edits/l10n/edit_copy.dart';
import '../../edits/models/edit_models.dart';
import '../../edits/repositories/edits_repository.dart';
import '../../edits/widgets/reel_metadata.dart';
import '../../kirari/data/kirari_repository.dart';
import '../../../app/app_router.dart';
import '../../../core/links/pubget_links.dart';

/// Canonical `/hashtag/:tag` surface: tag name, Reel count and the Reels
/// already tagged with it (the `hashtags` field on the Reel document).
class HashtagPage extends StatefulWidget {
  const HashtagPage({required this.tag, super.key});

  static const routePath = '/hashtag';

  final String tag;

  @override
  State<HashtagPage> createState() => _HashtagPageState();
}

class _HashtagPageState extends State<HashtagPage> {
  List<Edit> _reels = const <Edit>[];
  List<KirariReel> _kirariReels = const <KirariReel>[];
  var _loading = true;

  String get _normalizedTag =>
      widget.tag.trim().replaceFirst(RegExp(r'^#+'), '');

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      context.read<EditsRepository>().getEditsByHashtag(_normalizedTag),
      context.read<KirariRepository>().getHashtagFeed(hashtag: _normalizedTag)
          .catchError((_) => const KirariFeedPageResult([], hasMore: false)),
    ]);
    final result = results[0] as dynamic;
    final kirari = results[1] as KirariFeedPageResult;
    if (!mounted) return;
    setState(() {
      _reels = result.valueOrNull ?? const <Edit>[];
      _kirariReels = kirari.items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final copy = EditCopy.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('#$_normalizedTag'),
        leading: AppBackButton.maybeOf(context),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: <Widget>[
                Text(
                  '#$_normalizedTag',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                ReelChip(
                  key: const Key('hashtag-usage'),
                  label: copy.usedInReels(_reels.length + _kirariReels.length),
                  icon: Icons.tag,
                  highlighted: true,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_reels.isEmpty && _kirariReels.isEmpty)
                  PubgetEmptyState(
                    title: copy.noHashtagReels,
                    message: copy.noHashtagReelsBody,
                    icon: Icons.tag,
                  )
                else
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      for (final reel in _reels) ReelThumbnailTile(edit: reel),
                    ],
                  ),
                if (_kirariReels.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.lg),
                  Text('Kirari videos', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  for (final reel in _kirariReels)
                    ListTile(
                      leading: reel.coverUrl.isEmpty ? const Icon(Icons.movie) : AppImageLoader(imageUrl: reel.coverUrl, width: 56, height: 76, fit: BoxFit.cover),
                      title: Text(reel.caption.isEmpty ? 'Kirari video' : reel.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text('@${reel.creatorId}'),
                      onTap: () => AppNavigation.go(context, PubgetLinks.reelPath(reel.id)),
                    ),
                ],
              ],
            ),
    );
  }
}
