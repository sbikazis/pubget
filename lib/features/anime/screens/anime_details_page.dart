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
import '../l10n/anime_copy.dart';
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
    final copy = AnimeCopy.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(anime?.title ?? copy.hubTitle),
        actions: <Widget>[
          if (anime != null) ...<Widget>[
            PubgetIconButton(
              icon: Icons.share_outlined,
              tooltip: copy.share,
              onPressed: () => AnimeLinks.share(
                context,
                widget.animeId,
                title: anime.title,
              ),
            ),
            PubgetIconButton(
              icon: Icons.link_outlined,
              tooltip: copy.copied,
              onPressed: () => AnimeLinks.copyCanonical(context, widget.animeId),
            ),
          ],
        ],
      ),
      body: PubgetLoadingStateView(
        state: details.state,
        onRetry: details.retry,
        empty: PubgetEmptyState(
          title: copy.detailsMissing,
          icon: Icons.movie_filter_outlined,
        ),
        error: PubgetErrorState(
          title: copy.unableToLoad,
          message: details.failure?.message ?? copy.checkConnection,
          onRetry: details.retry,
          retryLabel: copy.retry,
        ),
        offline: PubgetOfflineState(
          message: copy.checkConnection,
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
                              label: AnimeCopy.of(context).genre(genre.name),
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
                              AnimeCopy.of(context).synopsisTitle,
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
                        semanticLabel: AnimeCopy.of(context).trailer,
                        child: Text(AnimeCopy.of(context).trailer),
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
                              AnimeCopy.of(context).links,
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
            AnimeCopy.of(context).ratingsCount(stats.ratingCount),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (anime.subtitle.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Text(
            AnimeCopy.of(context).subtitle(anime),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (anime.status != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            AnimeCopy.of(context).status(anime.status),
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
                ? AnimeCopy.of(context).rateAnime
                : AnimeCopy.of(context).editRating,
            leadingIcon: Icons.star_outline,
            child: Text(
              social?.myRating == null
                  ? AnimeCopy.of(context).rateAnime
                  : AnimeCopy.of(context).editRating,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          details.isFavorite
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.royalPurple.withValues(alpha: 0.48),
                        blurRadius: 16,
                      ),
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.36),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: PubgetPrimaryButton(
                    key: const Key('favorite-anime'),
                    onPressed: details.savingFavorite
                        ? null
                        : details.toggleFavorite,
                    semanticLabel: AnimeCopy.of(context).favorited,
                    leadingIcon: Icons.favorite,
                    loading: details.savingFavorite,
                    child: Text(AnimeCopy.of(context).favorited),
                  ),
                )
              : PubgetSecondaryButton(
                  key: const Key('favorite-anime'),
                  onPressed: details.savingFavorite
                      ? null
                      : details.toggleFavorite,
                  semanticLabel: AnimeCopy.of(context).favorite,
                  leadingIcon: Icons.favorite_border,
                  loading: details.savingFavorite,
                  child: Text(AnimeCopy.of(context).favorite),
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
    final copy = AnimeCopy.of(context);
    final rows = <(IconData, String, String)>[
      if (anime.type != null && anime.type!.isNotEmpty)
        (Icons.movie_filter_outlined, copy.factType, copy.typeLabel(anime.type)),
      if (anime.episodes != null)
        (Icons.view_list_outlined, copy.factEpisodes, '${anime.episodes}'),
      if (anime.duration != null)
        (Icons.timer_outlined, copy.factDuration, anime.duration!),
      if (anime.startDate != null || anime.endDate != null)
        (Icons.calendar_month_outlined, copy.factAired, _aired(anime)),
      if (anime.studios.isNotEmpty)
        (Icons.apartment_outlined, copy.factStudios, anime.studios.join(', ')),
      if (anime.source != null)
        (Icons.menu_book_outlined, copy.factSource, copy.source(anime.source)),
      if (anime.nextEpisodeLabel != null)
        (Icons.podcasts_outlined, copy.factBroadcast, anime.nextEpisodeLabel!),
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
            copy.detailsSection,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.goldPale,
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
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Icon(row.$1, color: AppColors.goldSheen, size: 22),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    row.$2,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: AppColors.goldSheen,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    row.$3,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: AppColors.goldPale,
                                      fontWeight: FontWeight.w800,
                                      height: 1.25,
                                    ),
                                  ),
                                ],
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
              AnimeCopy.of(context).charactersTitle,
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
                                  AnimeCopy.of(context).role(character.role),
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
              _characterDisplayName(character, about),
              key: const Key('character-sheet-name'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            if (about.arabicName != null &&
                about.arabicName!.isNotEmpty &&
                about.arabicName != character.name) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(
                character.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.goldPale,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
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
                '${AnimeCopy.of(context).characterRole}: ${AnimeCopy.of(context).role(character.role)}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.goldSheen,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (_loadingProfile) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(
                AnimeCopy.of(context).loadingProfile,
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            if (about.age != null || about.birthday != null)
              Text(
                [
                  if (about.age != null)
                    '${AnimeCopy.of(context).age}: ${about.age}',
                  if (about.birthday != null) about.birthday,
                ].join(' | '),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            if (about.height != null || about.weight != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(
                [
                  if (about.height != null) about.height,
                  if (about.weight != null) about.weight,
                ].join(' | '),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                if (character.favorites != null)
                  _favoritesCounter(
                    theme,
                    AnimeCopy.of(context).malFavorites,
                    character.favorites!,
                  ),
                if (stats != null)
                  _favoritesCounter(
                    theme,
                    AnimeCopy.of(context).pubgetFavorites,
                    stats.favoritesCount,
                  ),
                _factChip(
                  theme,
                  AnimeCopy.of(context).characterMalId,
                  character.id,
                ),
                if (character.role != null && character.role!.isNotEmpty)
                  _factChip(
                    theme,
                    AnimeCopy.of(context).characterRole,
                    AnimeCopy.of(context).role(character.role),
                  ),
              ],
            ),
            if (character.nicknames.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              Text(
                AnimeCopy.of(context).characterNicknames,
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
                AnimeCopy.of(context).characterFacts,
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
                          AnimeCopy.of(context).factLabel(fact.label),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: AppColors.goldSheen,
                            fontWeight: FontWeight.w800,
                          ),
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
                AnimeCopy.of(context).characterAbout,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: SingleChildScrollView(
                  child: SelectableText(
                    about.narrative,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ),
            ] else if (character.about != null &&
                character.about!.isNotEmpty &&
                about.facts.isEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              Text(
                AnimeCopy.of(context).characterAbout,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: SingleChildScrollView(
                  child: SelectableText(
                    character.about!,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ),
            ],
            ..._appearanceBlock(
              theme,
              title: AnimeCopy.of(context).characterAnime,
              items: character.animeography,
            ),
            ..._appearanceBlock(
              theme,
              title: AnimeCopy.of(context).characterManga,
              items: character.mangaography,
            ),
            if (character.voiceActors.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              Text(
                AnimeCopy.of(context).characterVoices,
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
                      width: 164,
                      child: PubgetCard(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Column(
                          children: <Widget>[
                            ClipOval(
                              child: SizedBox(
                                width: 72,
                                height: 72,
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
                                label: Text(
                                  AnimeCopy.of(context).voiceLanguage(
                                    actor.language,
                                  ),
                                ),
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
                semanticLabel: AnimeCopy.of(context).copied,
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
              semanticLabel: AnimeCopy.of(context).favoriteCharacter,
              leadingIcon: favorited ? Icons.favorite : Icons.favorite_border,
              child: Text(
                favorited
                    ? AnimeCopy.of(context).favorited
                    : AnimeCopy.of(context).favoriteCharacter,
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

  String _characterDisplayName(
    AnimeCharacter character,
    CharacterAboutSections about,
  ) {
    final arabic = about.arabicName?.trim();
    if (arabic != null && arabic.isNotEmpty) {
      return '$arabic / ${character.name}';
    }
    return character.name;
  }

  Widget _favoritesCounter(ThemeData theme, String label, int count) {
    return Chip(
      avatar: const Icon(Icons.favorite, color: AppColors.gold, size: 16),
      label: Text('$label: $count'),
      visualDensity: VisualDensity.compact,
    );
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
            AnimeCopy.of(context).reviewsTitle,
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
              AnimeCopy.of(context).listStatus,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final status in AnimeListStatus.values)
                  PubgetSelectionChip(
                    label: AnimeCopy.of(context).listStatusLabel(status),
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
                semanticLabel: AnimeCopy.of(context).removeFromList,
                child: Text(AnimeCopy.of(context).removeFromList),
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
    title: AnimeCopy.of(context).rateAnime,
    child: StatefulBuilder(
      builder: (context, setSheetState) {
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 560),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  AnimeCopy.of(context).overallScore(
                    scores.overall.toStringAsFixed(1),
                  ),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final criterion in AnimeRatingCriterion.values) ...<
                  Widget
                >[
                  Text(AnimeCopy.of(context).criterion(criterion)),
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
                  hint: AnimeCopy.of(context).reviewHint,
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
                  semanticLabel: AnimeCopy.of(context).submitRating,
                  loading: social.saving,
                  child: Text(AnimeCopy.of(context).submitRating),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
