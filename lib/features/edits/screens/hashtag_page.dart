import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/links/pubget_links.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../l10n/edit_copy.dart';
import '../models/edit_models.dart';
import '../repositories/edits_repository.dart';

/// Hashtag landing page — title, usage count, best reels, related hashtags and
/// related anime. "Browse" opens the same unified scoped viewer used by every
/// other Reels entry point.
final class HashtagPage extends StatefulWidget {
  const HashtagPage({super.key, required this.tag});

  final String tag;

  @override
  State<HashtagPage> createState() => _HashtagPageState();
}

class _HashtagPageState extends State<HashtagPage> {
  HashtagInfo? _info;
  LoadingState _state = LoadingState.loading;
  HashtagRepository? _repository;

  String get _tag => widget.tag.trim();

  @override
  void initState() {
    super.initState();
    _repository = _hashtagRepository(context);
    _load();
  }

  @override
  void didUpdateWidget(HashtagPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tag != widget.tag) _load();
  }

  HashtagRepository? _hashtagRepository(BuildContext context) {
    try {
      final repository = Provider.of<EditsRepository>(context, listen: false);
      if (repository is HashtagRepository)
        return repository as HashtagRepository;
      return null;
    } on ProviderNotFoundException {
      return null;
    }
  }

  Future<void> _load() async {
    final repository = _repository;
    if (repository == null) {
      setState(() {
        _info = null;
        _state = LoadingState.error;
      });
      return;
    }
    setState(() => _state = LoadingState.loading);
    final result = await repository.getHashtagInfo(_tag, limit: 6);
    if (!mounted) return;
    setState(() {
      result.fold(
        onSuccess: (info) {
          _info = info;
          _state = LoadingState.loaded;
        },
        onFailure: (_) {
          _info = null;
          _state = LoadingState.error;
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final copy = EditCopy.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('#$_tag'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => AppNavigation.popLayer(context),
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(PhosphorIconsRegular.shareNetwork),
            tooltip: copy.dismiss,
            onPressed: _tag.isEmpty
                ? null
                : () => PubgetLinks.share(
                    context,
                    url: PubgetLinks.hashtag(_tag),
                    type: 'hashtag',
                  ),
          ),
        ],
      ),
      body: switch (_state) {
        LoadingState.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        LoadingState.error => _ErrorView(onRetry: _load),
        _ => _HashtagContent(
          tag: _tag,
          info: _info,
          onBrowse: () =>
              AppNavigation.go(context, PubgetLinks.hashtagReelsPath(_tag)),
        ),
      },
    );
  }
}

class _HashtagContent extends StatelessWidget {
  const _HashtagContent({
    required this.tag,
    required this.info,
    required this.onBrowse,
  });

  final String tag;
  final HashtagInfo? info;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final copy = EditCopy.of(context);
    final info = this.info;
    final hasItems = info != null && info.items.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.royalPurple.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '#$tag',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Spacer(),
            if (info != null && info.usageCount > 0)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    '${info.usageCount}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    copy.hashtagUsage,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (hasItems) ...<Widget>[
          Text(copy.bestReels, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          _BestReelsGrid(items: info.items),
          const SizedBox(height: AppSpacing.md),
        ],
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onBrowse,
            icon: const Icon(PhosphorIconsRegular.playCircle),
            label: Text(copy.browseHashtag),
          ),
        ),
        if (info != null && info.relatedTags.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          Text(
            copy.relatedHashtags,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: info.relatedTags
                .map(
                  (ref) => ActionChip(
                    label: Text('#${ref.tag}'),
                    onPressed: () => AppNavigation.go(
                      context,
                      PubgetLinks.hashtagPath(ref.tag),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
        if (info != null && info.animeTags.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          Text(
            copy.relatedAnime,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: info.animeTags
                .map(
                  (animeTag) => ActionChip(
                    label: Text(animeTag),
                    onPressed: () => AppNavigation.go(
                      context,
                      PubgetLinks.animePath(animeTag),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
        if (info == null ||
            (info.items.isEmpty &&
                info.relatedTags.isEmpty &&
                info.animeTags.isEmpty))
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.lg),
            child: Text(copy.noHashtagResults),
          ),
      ],
    );
  }
}

class _BestReelsGrid extends StatelessWidget {
  const _BestReelsGrid({required this.items});

  final List<Edit> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 9 / 16,
      ),
      itemBuilder: (context, index) {
        final edit = items[index];
        final imageUrl = edit.thumbnailUrl.trim().isNotEmpty
            ? edit.thumbnailUrl
            : edit.videoUrl;
        return GestureDetector(
          onTap: () =>
              AppNavigation.go(context, PubgetLinks.reelHighlightPath(edit.id)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: imageUrl.isEmpty
                ? Container(color: AppColors.royalPurple.withValues(alpha: 0.2))
                : Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) {
                      return Container(
                        color: AppColors.royalPurple.withValues(alpha: 0.2),
                        child: const Center(
                          child: Icon(
                            PhosphorIconsRegular.videoCamera,
                            color: Colors.white70,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(PhosphorIconsRegular.warning, size: 40),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
