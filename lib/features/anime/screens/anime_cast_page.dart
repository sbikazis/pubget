import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../l10n/anime_copy.dart';
import '../models/anime_models.dart';
import '../providers/anime_cast_provider.dart';
import '../repositories/anime_repository.dart';
import '../widgets/anime_hub_widgets.dart';
import '../widgets/anime_widgets.dart';

/// Full-page browser for every character of one anime, with client-side
/// search across the already-fetched cast.
class AnimeCastPage extends StatefulWidget {
  const AnimeCastPage({required this.animeId, super.key});

  final String animeId;

  @override
  State<AnimeCastPage> createState() => _AnimeCastPageState();
}

class _AnimeCastPageState extends State<AnimeCastPage> {
  AnimeCastProvider? _provider;

  @override
  void initState() {
    super.initState();
    final provider = AnimeCastProvider(
      repository: context.read<AnimeRepository>(),
    );
    _provider = provider;
    Future<void>.microtask(() => provider.load(widget.animeId));
  }

  @override
  void dispose() {
    _provider?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;
    final copy = AnimeCopy.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(copy.charactersTitle),
      ),
      body: Column(
        children: <Widget>[
          if (provider != null) ...<Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: TextField(
                key: const Key('anime-cast-search'),
                decoration: InputDecoration(
                  hintText: copy.searchInCharacters,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: provider.search,
              ),
            ),
            Expanded(
              child: ChangeNotifierProvider<AnimeCastProvider>.value(
                value: provider,
                child: _CastBody(animeId: widget.animeId),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CastBody extends StatelessWidget {
  const _CastBody({required this.animeId});

  final String animeId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnimeCastProvider>();
    final copy = AnimeCopy.of(context);
    return PubgetLoadingStateView(
      state: provider.state,
      onRetry: provider.retry,
      empty: PubgetEmptyState(
        title: copy.charactersSearchEmpty,
        icon: Icons.people_outline,
      ),
      error: PubgetErrorState(
        title: copy.unableToLoad,
        message:
            provider.failure?.message ?? copy.checkConnection,
        onRetry: provider.retry,
      ),
      child: provider.visible.isEmpty
          ? PubgetEmptyState(
              title: copy.charactersSearchEmpty,
              icon: Icons.search_off,
            )
          : AnimeHubGrid(
              itemCount: provider.visible.length,
              itemBuilder: (context, index) {
                final item = provider.visible[index];
                return PubgetCard(
                  key: Key('cast-${item.id}'),
                  padding: EdgeInsets.zero,
                  onTap: () => _showCharacter(context, item),
                  child: Column(
                    children: <Widget>[
                      Expanded(
                        child: AnimePoster(
                          images: AnimeImages(
                            thumbnailUrl: item.imageUrl,
                          ),
                          memCacheWidth: 200,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(
                                context,
                              ).textTheme.titleSmall,
                            ),
                            if (item.role != null)
                              Text(
                                copy.role(item.role),
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  void _showCharacter(BuildContext context, AnimeCharacter character) {
    AnimeLinks.openCharacter(context, character.id);
  }
}