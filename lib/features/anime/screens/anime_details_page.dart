import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/network/network_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../authentication/providers/onboarding_provider.dart';
import '../models/anime_list_models.dart';
import '../models/anime_models.dart';
import '../models/anime_rating_models.dart';
import '../providers/anime_hub_social_provider.dart';
import '../providers/anime_library_provider.dart';
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
    final library = maybeAnimeLibrary(context, listen: false);
    final social = maybeAnimeHubSocial(context, listen: false);
    Future<void>.microtask(() async {
      await details.load(widget.animeId);
      await library?.load();
      await social?.loadAnime(widget.animeId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final details = context.watch<AnimeDetailsProvider>();
    final network = context.watch<NetworkService>();
    final social = maybeAnimeHubSocial(context);
    final auth = context.watch<AuthProvider>();
    final onboarding = context.watch<OnboardingProvider>();
    details.bindFavorites(
      userId: auth.currentUser?.id,
      favoriteIds: onboarding.profile?.favoriteAnimeIds ?? const <String>[],
      onboarding: onboarding,
    );
    final anime = details.anime;
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
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
                padding: const EdgeInsets.only(bottom: AppSpacing.huge),
                children: <Widget>[
                  if (details.fromCache)
                    AnimeCachedBanner(offline: !network.isOnline),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      0,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(
                          width: 148,
                          child: AnimePoster(
                            images: anime.images,
                            memCacheWidth: 360,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: _HeroCopy(anime: anime, social: social),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _ActionRow(anime: anime, details: details, social: social),
                  const SizedBox(height: AppSpacing.xl),
                  _AnimeListControls(anime: anime),
                  if (anime.alternativeTitles.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.xl,
                        AppSpacing.lg,
                        0,
                      ),
                      child: Text(
                        anime.alternativeTitles.join(' · '),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  if (anime.genres.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.xl,
                        AppSpacing.lg,
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
                  _FactsCard(anime: anime),
                  if (anime.synopsis != null && anime.synopsis!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.xl,
                        AppSpacing.lg,
                        0,
                      ),
                      child: PubgetCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              AnimeStrings.synopsisTitle,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              anime.synopsis!,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      ),
                    ),
                  _CharactersSection(details: details),
                  _ReviewsSection(social: social, anime: anime),
                  if (anime.trailerUrl != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.xl,
                        AppSpacing.lg,
                        0,
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
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.xl,
                        AppSpacing.lg,
                        0,
                      ),
                      child: PubgetCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              AnimeStrings.links,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.md),
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
                ],
              ),
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.anime, required this.social});

  final Anime anime;
  final AnimeHubSocialProvider? social;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = social?.stats;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          anime.title,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AnimeScoreBadge(
          malScore: anime.score,
          community: stats,
          large: true,
        ),
        if (stats != null && stats.hasRatings) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${stats.ratingCount} Pubget ratings',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (anime.subtitle.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Text(
            anime.subtitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (anime.status != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            anime.status!,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.anime,
    required this.details,
    required this.social,
  });

  final Anime anime;
  final AnimeDetailsProvider details;
  final AnimeHubSocialProvider? social;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PubgetPrimaryButton(
            onPressed: social == null
                ? null
                : () => _openRating(context, anime, social!),
            semanticLabel: social?.myRating == null
                ? AnimeStrings.rateAnime
                : AnimeStrings.editRating,
            leadingIcon: Icons.star_outline,
            child: Text(
              social?.myRating == null
                  ? AnimeStrings.rateAnime
                  : AnimeStrings.editRating,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          details.isFavorite
              ? PubgetPrimaryButton(
                  key: const Key('favorite-anime'),
                  onPressed: details.savingFavorite
                      ? null
                      : details.toggleFavorite,
                  semanticLabel: AnimeStrings.favorited,
                  leadingIcon: Icons.favorite,
                  loading: details.savingFavorite,
                  child: const Text(AnimeStrings.favorited),
                )
              : PubgetSecondaryButton(
                  key: const Key('favorite-anime'),
                  onPressed: details.savingFavorite
                      ? null
                      : details.toggleFavorite,
                  semanticLabel: AnimeStrings.favorite,
                  leadingIcon: Icons.favorite_border,
                  loading: details.savingFavorite,
                  child: const Text(AnimeStrings.favorite),
                ),
        ],
      ),
    );
  }
}

class _FactsCard extends StatelessWidget {
  const _FactsCard({required this.anime});

  final Anime anime;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      if (anime.episodes != null) ('Episodes', '${anime.episodes}'),
      if (anime.duration != null) ('Duration', anime.duration!),
      if (anime.startDate != null || anime.endDate != null)
        ('Aired', _aired(anime)),
      if (anime.studios.isNotEmpty) ('Studios', anime.studios.join(', ')),
      if (anime.source != null) ('Source', anime.source!),
      if (anime.nextEpisodeLabel != null) ('Broadcast', anime.nextEpisodeLabel!),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Details',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 420;
              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: <Widget>[
                  for (final row in rows)
                    SizedBox(
                      width: wide
                          ? (constraints.maxWidth - AppSpacing.md) / 2
                          : constraints.maxWidth,
                      child: PubgetCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              row.$1,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: AppColors.goldSheen,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              row.$2,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
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
    if (details.charactersState == LoadingState.loading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.lg,
          0,
        ),
        child: PubgetSkeleton.card(height: 140),
      );
    }
    if (details.characters.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              AnimeStrings.charactersTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 196,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              scrollDirection: Axis.horizontal,
              itemCount: details.characters.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, index) {
                final character = details.characters[index];
                return SizedBox(
                  width: 128,
                  child: PubgetCard(
                    key: Key('character-${character.id}'),
                    padding: EdgeInsets.zero,
                    onTap: () => _showCharacter(context, details, character),
                    child: Column(
                      children: <Widget>[
                        Expanded(
                          child: AnimePoster(
                            images: AnimeImages(
                              thumbnailUrl: character.imageUrl,
                            ),
                            memCacheWidth: 180,
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
}

Future<void> _showCharacter(
  BuildContext context,
  AnimeDetailsProvider details,
  AnimeCharacter preview,
) {
  final social = maybeAnimeHubSocial(context, listen: false);
  return PubgetBottomSheet.show<void>(
    context,
    isScrollControlled: true,
    title: preview.name,
    child: _CharacterProfileSheet(
      preview: preview,
      details: details,
      social: social,
    ),
  );
}

class _CharacterProfileSheet extends StatefulWidget {
  const _CharacterProfileSheet({
    required this.preview,
    required this.details,
    required this.social,
  });

  final AnimeCharacter preview;
  final AnimeDetailsProvider details;
  final AnimeHubSocialProvider? social;

  @override
  State<_CharacterProfileSheet> createState() => _CharacterProfileSheetState();
}

class _CharacterProfileSheetState extends State<_CharacterProfileSheet> {
  late AnimeCharacter _character;
  CharacterCommunityStats? _stats;
  var _loadingProfile = false;

  @override
  void initState() {
    super.initState();
    _character = widget.preview;
    _loadingProfile =
        widget.preview.id.isNotEmpty && !widget.preview.hasFullProfile;
    Future<void>.microtask(_hydrate);
  }

  Future<void> _hydrate() async {
    final preview = widget.preview;
    final profileFuture = widget.details.characterProfile(preview);
    final statsFuture = widget.social?.characterStats(preview.id);
    final profile = await profileFuture;
    if (!mounted) return;
    setState(() {
      _character = profile;
      _loadingProfile = false;
    });
    if (statsFuture == null) return;
    final stats = await statsFuture;
    if (!mounted) return;
    setState(() => _stats = stats);
  }

  @override
  Widget build(BuildContext context) {
    final character = _character;
    final stats = _stats;
    final library = maybeAnimeLibrary(context);
    final favorited = library?.isCharacterFavorite(character.id) == true;
    final theme = Theme.of(context);
    final about = CharacterAboutSections.parse(character.about);
    return ConstrainedBox(
      key: const Key('character-sheet'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (character.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ColoredBox(
                  color: AppColors.royalNight,
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: AnimePoster(
                      images: AnimeImages(
                        thumbnailUrl: character.imageUrl,
                        largeUrl: character.imageUrl,
                      ),
                      fit: BoxFit.contain,
                      memCacheWidth: 960,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              character.name,
              key: const Key('character-sheet-name'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (character.nameKanji != null &&
                character.nameKanji!.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(character.nameKanji!, style: theme.textTheme.titleMedium),
            ],
            if (character.role != null && character.role!.isNotEmpty) ...<
              Widget
            >[
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${AnimeStrings.characterRole}: ${character.role}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.goldSheen,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (_loadingProfile) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(
                AnimeStrings.loadingProfile,
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                _factChip(theme, AnimeStrings.characterMalId, character.id),
                if (character.favorites != null)
                  _factChip(
                    theme,
                    AnimeStrings.malFavorites,
                    '${character.favorites}',
                  ),
                if (stats != null)
                  _factChip(
                    theme,
                    AnimeStrings.pubgetFavorites,
                    '${stats.favoritesCount}',
                  ),
                if (character.role != null && character.role!.isNotEmpty)
                  _factChip(theme, AnimeStrings.characterRole, character.role!),
              ],
            ),
            if (character.nicknames.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              Text(
                AnimeStrings.characterNicknames,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  for (final name in character.nicknames)
                    Chip(label: Text(name)),
                ],
              ),
            ],
            if (about.facts.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              Text(
                AnimeStrings.characterFacts,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final fact in about.facts)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 108,
                        child: Text(
                          fact.label,
                          style: theme.textTheme.labelLarge,
                        ),
                      ),
                      Expanded(child: SelectableText(fact.value)),
                    ],
                  ),
                ),
            ],
            if (about.narrative.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              Text(
                AnimeStrings.characterAbout,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              SelectableText(about.narrative),
            ] else if (character.about != null &&
                character.about!.isNotEmpty &&
                about.facts.isEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              Text(
                AnimeStrings.characterAbout,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              SelectableText(character.about!),
            ],
            ..._appearanceBlock(
              theme,
              title: AnimeStrings.characterAnime,
              items: character.animeography,
            ),
            ..._appearanceBlock(
              theme,
              title: AnimeStrings.characterManga,
              items: character.mangaography,
            ),
            if (character.voiceActors.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              Text(
                AnimeStrings.characterVoices,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  for (final actor in _sortedVoiceActors(character.voiceActors))
                    SizedBox(
                      width: 156,
                      child: PubgetCard(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Column(
                          children: <Widget>[
                            ClipOval(
                              child: SizedBox(
                                width: 64,
                                height: 64,
                                child: actor.imageUrl == null
                                    ? const ColoredBox(
                                        color: AppColors.royalDusk,
                                        child: Icon(Icons.person_outline),
                                      )
                                    : AnimePoster(
                                        images: AnimeImages(
                                          thumbnailUrl: actor.imageUrl,
                                          largeUrl: actor.imageUrl,
                                        ),
                                        fit: BoxFit.cover,
                                        memCacheWidth: 160,
                                      ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              actor.name,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (actor.language != null) ...<Widget>[
                              const SizedBox(height: AppSpacing.xs),
                              Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text(actor.language!),
                              ),
                            ],
                            if (actor.animeTitle != null)
                              Text(
                                actor.animeTitle!,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall,
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
            if (character.url != null && character.url!.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              PubgetTextButton(
                onPressed: () => AnimeLinks.copyUrl(context, character.url!),
                semanticLabel: AnimeStrings.copied,
                child: Text(
                  character.url!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            PubgetPrimaryButton(
              onPressed: library == null
                  ? null
                  : () => library.toggleCharacter(
                      characterId: character.id,
                      name: character.name,
                      imageUrl: character.imageUrl,
                    ),
              semanticLabel: AnimeStrings.favoriteCharacter,
              leadingIcon: favorited ? Icons.favorite : Icons.favorite_border,
              child: Text(
                favorited
                    ? AnimeStrings.favorited
                    : AnimeStrings.favoriteCharacter,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<VoiceActor> _sortedVoiceActors(List<VoiceActor> actors) {
    int rank(VoiceActor actor) {
      final language = actor.language?.toLowerCase() ?? '';
      if (language.contains('japanese')) return 0;
      if (language.contains('english')) return 1;
      return 2;
    }

    return [...actors]..sort((a, b) => rank(a).compareTo(rank(b)));
  }

  Widget _factChip(ThemeData theme, String label, String value) {
    return Chip(
      label: Text('$label: $value'),
      visualDensity: VisualDensity.compact,
    );
  }

  List<Widget> _appearanceBlock(
    ThemeData theme, {
    required String title,
    required List<CharacterAppearance> items,
  }) {
    if (items.isEmpty) return const <Widget>[];
    return <Widget>[
      const SizedBox(height: AppSpacing.lg),
      Text(title, style: theme.textTheme.titleMedium),
      const SizedBox(height: AppSpacing.sm),
      for (final item in items)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (item.imageUrl != null) ...<Widget>[
                SizedBox(
                  width: 40,
                  height: 56,
                  child: AnimePoster(
                    images: AnimeImages(thumbnailUrl: item.imageUrl),
                    memCacheWidth: 80,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Text(
                  [
                    item.title,
                    if (item.role != null && item.role!.isNotEmpty) item.role!,
                  ].join(' · '),
                ),
              ),
            ],
          ),
        ),
    ];
  }
}

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({required this.social, required this.anime});

  final AnimeHubSocialProvider? social;
  final Anime anime;

  @override
  Widget build(BuildContext context) {
    final reviews = social?.reviews ?? const <AnimeReview>[];
    if (reviews.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AnimeStrings.reviewsTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final review in reviews.take(20))
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: PubgetCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            review.username.isEmpty
                                ? 'Pubget user'
                                : review.username,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          review.overall.toStringAsFixed(1),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: AppColors.gold),
                        ),
                      ],
                    ),
                    if (review.comment.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      Text(review.comment),
                    ],
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: PubgetTextButton(
                        onPressed: social == null
                            ? null
                            : () => social!.reportReview(
                                targetUserId: review.userId,
                                reason: 'inappropriate',
                              ),
                        semanticLabel: 'Report review',
                        child: const Text('Report'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AnimeListControls extends StatelessWidget {
  const _AnimeListControls({required this.anime});

  final Anime anime;

  @override
  Widget build(BuildContext context) {
    final library = maybeAnimeLibrary(context);
    if (library == null) return const SizedBox.shrink();
    final current = library.entryFor(anime.id);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: PubgetCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              AnimeStrings.listStatus,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final status in AnimeListStatus.values)
                  PubgetSelectionChip(
                    label: status.label,
                    selected: current?.status == status,
                    onSelected: library.saving
                        ? null
                        : (_) => library.setStatus(
                            animeId: anime.id,
                            status: status,
                            title: anime.title,
                            rating: current?.rating,
                          ),
                  ),
              ],
            ),
            if (current != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              PubgetTextButton(
                onPressed: library.saving
                    ? null
                    : () => library.remove(anime.id),
                semanticLabel: AnimeStrings.removeFromList,
                child: const Text(AnimeStrings.removeFromList),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> _openRating(
  BuildContext context,
  Anime anime,
  AnimeHubSocialProvider social,
) async {
  var scores = social.myRating?.criteria ?? AnimeCriteriaScores.empty;
  var comment = social.myRating?.comment ?? '';
  await PubgetBottomSheet.show<void>(
    context,
    isScrollControlled: true,
    title: AnimeStrings.rateAnime,
    child: StatefulBuilder(
      builder: (context, setSheetState) {
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 560),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Overall ${scores.overall.toStringAsFixed(1)}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final criterion in AnimeRatingCriterion.values) ...<
                  Widget
                >[
                  Text(criterion.label),
                  Slider(
                    min: 0,
                    max: 10,
                    divisions: 10,
                    value: scores.scoreFor(criterion).toDouble(),
                    label: '${scores.scoreFor(criterion)}',
                    onChanged: (value) {
                      setSheetState(() {
                        scores = scores.withScore(criterion, value.round());
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                PubgetTextArea(
                  hint: AnimeStrings.reviewHint,
                  onChanged: (value) => comment = value,
                ),
                const SizedBox(height: AppSpacing.lg),
                PubgetPrimaryButton(
                  onPressed: social.saving
                      ? null
                      : () async {
                          await social.saveRating(
                            criteria: scores,
                            title: anime.title,
                            imageUrl: anime.images.displayUrl,
                            comment: comment,
                          );
                          if (context.mounted) Navigator.of(context).pop();
                        },
                  semanticLabel: AnimeStrings.submitRating,
                  loading: social.saving,
                  child: const Text(AnimeStrings.submitRating),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
