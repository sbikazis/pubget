import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/loading/loading_state.dart';
import '../../../core/network/network_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../authentication/providers/onboarding_provider.dart';
import '../models/anime_models.dart';
import '../providers/anime_providers.dart';
import '../widgets/anime_widgets.dart';

class AnimeDetailsPage extends StatefulWidget {
  const AnimeDetailsPage({required this.animeId, super.key});

  final String animeId;

  @override
  State<AnimeDetailsPage> createState() => _AnimeDetailsPageState();
}

class _AnimeDetailsPageState extends State<AnimeDetailsPage> {
  @override
  void initState() {
    super.initState();
    final details = context.read<AnimeDetailsProvider>();
    final auth = context.read<AuthProvider>();
    final onboarding = context.read<OnboardingProvider>();
    details.bindFavorites(
      userId: auth.currentUser?.id,
      favoriteIds: onboarding.profile?.favoriteAnimeIds ?? const <String>[],
      onboarding: onboarding,
    );
    Future<void>.microtask(() => details.load(widget.animeId));
  }

  @override
  Widget build(BuildContext context) {
    final details = context.watch<AnimeDetailsProvider>();
    final network = context.watch<NetworkService>();
    final anime = details.anime;
    return Scaffold(
      appBar: AppBar(
        title: Text(anime?.title ?? AnimeStrings.hubTitle),
        actions: <Widget>[
          if (anime != null) ...<Widget>[
            PubgetIconButton(
              icon: Icons.share_outlined,
              tooltip: AnimeStrings.share,
              onPressed: () => AnimeLinks.share(
                context,
                widget.animeId,
                title: anime.title,
              ),
            ),
            PubgetIconButton(
              icon: Icons.link_outlined,
              tooltip: AnimeStrings.copied,
              onPressed: () => AnimeLinks.copyCanonical(context, widget.animeId),
            ),
            PubgetIconButton(
              icon: details.isFavorite ? Icons.favorite : Icons.favorite_border,
              tooltip: details.isFavorite
                  ? AnimeStrings.favorited
                  : AnimeStrings.favorite,
              loading: details.savingFavorite,
              onPressed: details.toggleFavorite,
            ),
          ],
        ],
      ),
      body: PubgetLoadingStateView(
        state: details.state,
        onRetry: details.retry,
        empty: const PubgetEmptyState(
          title: AnimeStrings.detailsMissing,
          icon: Icons.movie_filter_outlined,
        ),
        error: PubgetErrorState(
          title: AnimeStrings.unableToLoad,
          message: details.failure?.message ?? AnimeStrings.checkConnection,
          onRetry: details.retry,
          retryLabel: AnimeStrings.retry,
        ),
        offline: PubgetOfflineState(
          message: AnimeStrings.checkConnection,
          onRetry: details.retry,
        ),
        child: anime == null
            ? const SizedBox.shrink()
            : ListView(
                children: <Widget>[
                  if (details.fromCache)
                    AnimeCachedBanner(offline: !network.isOnline),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(
                          width: 140,
                          child: AnimePoster(
                            images: anime.images,
                            memCacheWidth: 320,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: _HeaderFacts(anime: anime)),
                      ],
                    ),
                  ),
                  if (anime.alternativeTitles.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Text(
                        anime.alternativeTitles.join(' · '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  if (anime.genres.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.md,
                        0,
                      ),
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: <Widget>[
                          for (final genre in anime.genres.where(
                            (item) => item.isBrowsable,
                          ))
                            PubgetSelectionChip(
                              label: genre.name,
                              selected: false,
                              onSelected: (_) =>
                                  AnimeLinks.openGenre(context, genre),
                            ),
                        ],
                      ),
                    ),
                  if (anime.synopsis != null && anime.synopsis!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: PubgetCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              AnimeStrings.synopsisTitle,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(anime.synopsis!),
                          ],
                        ),
                      ),
                    ),
                  _CharactersSection(details: details),
                  if (anime.trailerUrl != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: PubgetSecondaryButton(
                        onPressed: () =>
                            AnimeLinks.copyUrl(context, anime.trailerUrl!),
                        semanticLabel: AnimeStrings.trailer,
                        child: const Text(AnimeStrings.trailer),
                      ),
                    ),
                  if (anime.externalLinks.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: PubgetCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              AnimeStrings.links,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            for (final link in anime.externalLinks)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(link.label),
                                subtitle: Text(
                                  link.url,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () =>
                                    AnimeLinks.copyUrl(context, link.url),
                              ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
      ),
    );
  }
}

class _HeaderFacts extends StatelessWidget {
  const _HeaderFacts({required this.anime});

  final Anime anime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(anime.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        if (anime.score != null)
          Text('Score ${anime.score!.toStringAsFixed(2)}', style: theme.textTheme.titleMedium),
        if (anime.rank != null) Text('Rank #${anime.rank}'),
        if (anime.popularity != null) Text('Popularity #${anime.popularity}'),
        if (anime.status != null) Text(anime.status!),
        if (anime.episodes != null) Text('${anime.episodes} episodes'),
        if (anime.duration != null) Text(anime.duration!),
        if (anime.startDate != null || anime.endDate != null)
          Text(_aired(anime)),
        if (anime.season != null || anime.year != null)
          Text(
            [
              if (anime.season != null) anime.season!.label,
              if (anime.year != null) '${anime.year}',
            ].join(' '),
          ),
        if (anime.studios.isNotEmpty) Text(anime.studios.join(', ')),
        if (anime.source != null) Text('Source: ${anime.source}'),
        if (anime.nextEpisodeLabel != null) Text(anime.nextEpisodeLabel!),
      ],
    );
  }

  String _aired(Anime anime) {
    final start = anime.startDate?.toIso8601String().split('T').first;
    final end = anime.endDate?.toIso8601String().split('T').first;
    if (start != null && end != null) return '$start – $end';
    return start ?? end ?? '';
  }
}

class _CharactersSection extends StatelessWidget {
  const _CharactersSection({required this.details});

  final AnimeDetailsProvider details;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              AnimeStrings.charactersTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (details.charactersState == LoadingState.loading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: PubgetSkeleton.card(height: 120),
            )
          else if (details.charactersState == LoadingState.error ||
              details.charactersState == LoadingState.offline)
            PubgetErrorState(
              title: AnimeStrings.unableToLoad,
              message:
                  details.charactersFailure?.message ??
                  AnimeStrings.checkConnection,
              onRetry: details.retryCharacters,
              retryLabel: AnimeStrings.retry,
            )
          else if (details.characters.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text('No character list is available.'),
            )
          else
            SizedBox(
              height: 180,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                scrollDirection: Axis.horizontal,
                itemCount: details.characters.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final character = details.characters[index];
                  return SizedBox(
                    width: 120,
                    child: PubgetCard(
                      padding: EdgeInsets.zero,
                      onTap: () => _showCharacter(context, character),
                      child: Column(
                        children: <Widget>[
                          Expanded(
                            child: AnimePoster(
                              images: AnimeImages(
                                thumbnailUrl: character.imageUrl,
                              ),
                              memCacheWidth: 160,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            child: Column(
                              children: <Widget>[
                                Text(
                                  character.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                if (character.role != null)
                                  Text(
                                    character.role!,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _showCharacter(BuildContext context, AnimeCharacter character) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(character.name, style: Theme.of(context).textTheme.titleLarge),
            if (character.role != null) Text(character.role!),
            if (character.favorites != null)
              Text('Favorites: ${character.favorites}'),
            const SizedBox(height: AppSpacing.md),
            for (final actor in character.voiceActors.take(5))
              Text(
                [
                  actor.name,
                  if (actor.language != null) actor.language!,
                ].join(' · '),
              ),
          ],
        ),
      ),
    );
  }
}
