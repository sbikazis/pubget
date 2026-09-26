import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../app/app_router.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../edits/models/edit_models.dart';
import '../../edits/repositories/edits_repository.dart';
import '../../fan_works/providers/fan_work_providers.dart';
import '../../fan_works/repositories/fan_work_repository.dart';
import '../../fan_works/widgets/fan_work_widgets.dart';
import '../l10n/anime_copy.dart';
import '../models/anime_models.dart';
import '../models/anime_rating_models.dart';
import '../providers/anime_character_provider.dart';
import '../providers/anime_hub_social_provider.dart';
import '../providers/anime_library_provider.dart';
import '../widgets/anime_hub_widgets.dart';
import '../widgets/anime_widgets.dart';

class AnimeCharacterPage extends StatefulWidget {
  const AnimeCharacterPage({required this.characterId, super.key});

  final String characterId;

  @override
  State<AnimeCharacterPage> createState() => _AnimeCharacterPageState();
}

class _AnimeCharacterPageState extends State<AnimeCharacterPage> {
  FanWorkFeedProvider? _relatedFanWorks;
  CharacterEditsRepository? _reelsRepository;
  List<Edit> _relatedReels = const <Edit>[];
  bool _loadingReels = false;

  @override
  void initState() {
    super.initState();
    final character = maybeAnimeCharacter(context, listen: false);
    final social = maybeAnimeHubSocial(context, listen: false);
    final library = maybeAnimeLibrary(context, listen: false);
    final fanWorks = _fanWorkRepository(context);
    _reelsRepository = _characterEditsRepository(context);
    if (fanWorks != null) {
      final feed = FanWorkFeedProvider(repository: fanWorks);
      _relatedFanWorks = feed;
      Future<void>.microtask(() => feed.load(characterId: widget.characterId));
    }
    Future<void>.microtask(() async {
      await character?.load(widget.characterId);
      await library?.load();
      await social?.loadCharacterDiscussion(widget.characterId);
    });
    Future<void>.microtask(_loadReels);
  }

  Future<void> _loadReels() async {
    final repository = _reelsRepository;
    if (repository == null) return;
    setState(() => _loadingReels = true);
    final result = await repository.getCharacterEdits(widget.characterId);
    if (!mounted) return;
    setState(() {
      _relatedReels = result.valueOrNull ?? const <Edit>[];
      _loadingReels = false;
    });
  }

  @override
  void dispose() {
    _relatedFanWorks?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = maybeAnimeCharacter(context);
    final social = maybeAnimeHubSocial(context, listen: false);
    final copy = AnimeCopy.of(context);
    final character = provider?.character;
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(character?.name ?? copy.charactersTitle),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await provider?.load(widget.characterId, refresh: true);
          await social?.loadCharacterDiscussion(
            widget.characterId,
            refresh: true,
          );
          await _loadReels();
        },
        child: _body(context, copy, provider),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AnimeCopy copy,
    AnimeCharacterProvider? provider,
  ) {
    if (provider == null) {
      return _CharacterScroll(
        character: null,
        relatedFanWorks: _relatedFanWorks,
        relatedReels: _relatedReels,
        loadingReels: _loadingReels,
      );
    }
    return PubgetLoadingStateView(
      state: provider.state,
      onRetry: provider.retry,
      empty: PubgetEmptyState(
        title: copy.characterNotFound,
        icon: Icons.person_off_outlined,
      ),
      error: PubgetErrorState(
        title: copy.unableToLoad,
        message: provider.failure?.message ?? copy.checkConnection,
        onRetry: provider.retry,
      ),
      child: _CharacterScroll(
        character: provider.character,
        relatedFanWorks: _relatedFanWorks,
        relatedReels: _relatedReels,
        loadingReels: _loadingReels,
      ),
    );
  }
}

class _CharacterScroll extends StatelessWidget {
  const _CharacterScroll({
    required this.character,
    required this.relatedFanWorks,
    required this.relatedReels,
    required this.loadingReels,
  });

  final AnimeCharacter? character;
  final FanWorkFeedProvider? relatedFanWorks;
  final List<Edit> relatedReels;
  final bool loadingReels;

  @override
  Widget build(BuildContext context) {
    final current = character;
    if (current == null) {
      return const SizedBox.expand();
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        _CharacterHeader(character: current),
        const SizedBox(height: AppSpacing.lg),
        _CharacterActions(character: current),
        const SizedBox(height: AppSpacing.lg),
        _CharacterProfileBody(character: current),
        _CharacterFanWorksSection(feed: relatedFanWorks),
        _CharacterReelsSection(reels: relatedReels, loading: loadingReels),
        _CharacterDiscussionSection(characterId: current.id),
      ],
    );
  }
}

class _CharacterHeader extends StatelessWidget {
  const _CharacterHeader({required this.character});

  final AnimeCharacter character;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = AnimeCopy.of(context);
    final about = CharacterAboutSections.parse(character.about);
    final provider = maybeAnimeCharacter(context, listen: false);
    final stats = provider?.stats;
    final rank = provider?.rank;
    final displayName = about.arabicName?.isNotEmpty == true
        ? about.arabicName!
        : character.name;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Spec: 220x220 with a 32 radius, not a poster ratio.
        AnimeCharacterPortrait(
          imageUrl: character.imageUrl ?? '',
          name: displayName,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                displayName,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              if (displayName != character.name) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  character.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.goldPale,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (character.nameKanji?.isNotEmpty == true) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(character.nameKanji!, style: theme.textTheme.titleMedium),
              ],
              if (character.role?.isNotEmpty == true) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${copy.characterRole}: ${copy.role(character.role)}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.goldSheen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  _StatChip(
                    icon: Icons.favorite,
                    label: copy.pubgetFavorites,
                    value: '${stats?.favoritesCount ?? 0}',
                  ),
                  if (rank != null)
                    _StatChip(
                      icon: Icons.leaderboard_outlined,
                      label: copy.characterRank,
                      value: '#$rank',
                    ),
                  if (character.favorites != null)
                    _StatChip(
                      icon: Icons.favorite_border,
                      label: copy.malFavorites,
                      value: '${character.favorites}',
                    ),
                ],
              ),
              // Composite: what Pubget counts against what MAL counts.
              AnimeHubFactGrid(
                facts: <AnimeHubFactTile>[
                  if (stats != null && stats.favoritesCount > 0)
                    AnimeHubFactTile(
                      icon: Icons.favorite,
                      label: copy.pubgetFavorites,
                      value: '${stats.favoritesCount}',
                    ),
                  if (rank != null)
                    AnimeHubFactTile(
                      icon: Icons.leaderboard_outlined,
                      label: copy.characterRank,
                      value: '#$rank',
                    ),
                  if (character.favorites != null)
                    AnimeHubFactTile(
                      icon: Icons.groups_outlined,
                      label: copy.malFavorites,
                      value: '${character.favorites}',
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.royalDusk,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: AppColors.goldSheen),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '$label $value',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CharacterActions extends StatelessWidget {
  const _CharacterActions({required this.character});

  final AnimeCharacter character;

  @override
  Widget build(BuildContext context) {
    final library = maybeAnimeLibrary(context);
    final copy = AnimeCopy.of(context);
    final favorite = library?.isCharacterFavorite(character.id) == true;
    final rating = library?.characterFavorite(character.id)?.rating;
    final busy = library?.saving == true;
    return PubgetCard(
      child: Row(
        children: <Widget>[
          Expanded(
            child: FilledButton.icon(
              onPressed: busy
                  ? null
                  : () => library?.toggleCharacter(
                      characterId: character.id,
                      name: character.name,
                      imageUrl: character.imageUrl,
                    ),
              icon: Icon(
                favorite ? Icons.favorite : Icons.favorite_border,
                size: 18,
              ),
              label: Text(favorite ? copy.favorited : copy.favoriteCharacter),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: DropdownButtonFormField<int>(
              key: const Key('character-rating'),
              value: rating,
              decoration: InputDecoration(
                labelText: copy.characterYourRating,
                isDense: true,
              ),
              items: <DropdownMenuItem<int>>[
                for (var value = 1; value <= 10; value++)
                  DropdownMenuItem<int>(value: value, child: Text('$value')),
              ],
              onChanged: busy
                  ? null
                  : (value) {
                      if (value == null) return;
                      library?.setCharacterRating(
                        characterId: character.id,
                        rating: value,
                        name: character.name,
                        imageUrl: character.imageUrl,
                      );
                    },
            ),
          ),
        ],
      ),
    );
  }
}

class _CharacterProfileBody extends StatelessWidget {
  const _CharacterProfileBody({required this.character});

  final AnimeCharacter character;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = AnimeCopy.of(context);
    final about = CharacterAboutSections.parse(character.about);
    final narrative = about.narrative.isNotEmpty
        ? about.narrative
        : (character.about ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (narrative.isNotEmpty) ...<Widget>[
          Text(copy.characterAbout, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          SelectableText(narrative, style: theme.textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (about.facts.isNotEmpty) ...<Widget>[
          Text(copy.characterFacts, style: theme.textTheme.titleLarge),
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
          const SizedBox(height: AppSpacing.lg),
        ],
        if (character.nicknames.isNotEmpty) ...<Widget>[
          Text(copy.characterNicknames, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final name in character.nicknames) Chip(label: Text(name)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        _AppearanceList(
          title: copy.characterAnime,
          items: character.animeography,
        ),
        if (character.voiceActors.isNotEmpty) ...<Widget>[
          Text(copy.characterVoices, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final actor in character.voiceActors.take(12))
                Chip(
                  avatar: const Icon(Icons.mic_none, size: 16),
                  label: Text(
                    actor.language == null
                        ? actor.name
                        : '${actor.name} · ${actor.language}',
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _AppearanceList extends StatelessWidget {
  const _AppearanceList({required this.title, required this.items});

  final String title;
  final List<CharacterAppearance> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final copy = AnimeCopy.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        for (final item in items.take(12))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: SizedBox(
              width: 40,
              child: item.imageUrl == null
                  ? const Icon(Icons.movie_outlined)
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AnimePoster(
                        images: AnimeImages(thumbnailUrl: item.imageUrl),
                        memCacheWidth: 120,
                      ),
                    ),
            ),
            title: Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: item.role == null ? null : Text(copy.role(item.role)),
            onTap: item.id.isEmpty
                ? null
                : () => AnimeLinks.openDetails(context, item.id),
          ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

class _CharacterFanWorksSection extends StatelessWidget {
  const _CharacterFanWorksSection({required this.feed});

  final FanWorkFeedProvider? feed;

  @override
  Widget build(BuildContext context) {
    final current = feed;
    if (current == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: current,
      builder: (context, _) {
        final items = current.items;
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              AnimeCopy.of(context).relatedFanWorksTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 280,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.take(8).length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) => SizedBox(
                  width: 140,
                  child: FanWorkPreviewCard(work: items[index]),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        );
      },
    );
  }
}

class _CharacterReelsSection extends StatelessWidget {
  const _CharacterReelsSection({required this.reels, required this.loading});

  final List<Edit> reels;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (!loading && reels.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          AnimeCopy.of(context).characterReels,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 210,
          child: loading && reels.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: reels.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final edit = reels[index];
                    return SizedBox(
                      width: 150,
                      child: PubgetCard(
                        padding: EdgeInsets.zero,
                        onTap: () => AppNavigation.go(context, '/edits'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: SizedBox(
                                width: double.infinity,
                                child: edit.thumbnailUrl.isEmpty
                                    ? const ColoredBox(
                                        color: AppColors.royalDusk,
                                        child: Icon(Icons.play_circle_outline),
                                      )
                                    : AnimePoster(
                                        images: AnimeImages(
                                          thumbnailUrl: edit.thumbnailUrl,
                                        ),
                                        fit: BoxFit.cover,
                                        memCacheWidth: 320,
                                      ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    edit.caption.isEmpty
                                        ? edit.animeTag
                                        : edit.caption,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Row(
                                    children: <Widget>[
                                      const Icon(Icons.favorite, size: 12),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${edit.likesCount}',
                                        style: theme.textTheme.labelSmall,
                                      ),
                                    ],
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
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

class _CharacterDiscussionSection extends StatefulWidget {
  const _CharacterDiscussionSection({required this.characterId});

  final String characterId;

  @override
  State<_CharacterDiscussionSection> createState() =>
      _CharacterDiscussionSectionState();
}

class _CharacterDiscussionSectionState
    extends State<_CharacterDiscussionSection> {
  final TextEditingController _controller = TextEditingController();
  bool _posting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _posting) return;
    final social = maybeAnimeHubSocial(context, listen: false);
    setState(() => _posting = true);
    final result = await social?.postCharacterDiscussion(
      characterId: widget.characterId,
      text: text,
    );
    if (!mounted) return;
    setState(() => _posting = false);
    if (result?.isSuccess == true) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = AnimeCopy.of(context);
    final social = maybeAnimeHubSocial(context);
    final userId = context.watch<AuthProvider>().currentUser?.id;
    final posts = social?.discussions ?? const <CharacterDiscussion>[];
    final state = social?.discussionState ?? LoadingState.empty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(copy.characterDiscussions, style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        PubgetCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                key: const Key('character-discussion-input'),
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: copy.characterDiscussionHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton(
                  key: const Key('character-discussion-post'),
                  onPressed: _posting ? null : _post,
                  child: Text(copy.post),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (state == LoadingState.loading && posts.isEmpty)
          const Center(child: CircularProgressIndicator())
        else if (posts.isEmpty)
          Text(copy.characterDiscussionEmpty, style: theme.textTheme.bodyMedium)
        else
          for (final post in posts)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: PubgetCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            post.username.isEmpty ? 'Pubget' : post.username,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(post.text, style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    if (userId != null && post.userId == userId)
                      IconButton(
                        key: Key('character-discussion-delete-${post.id}'),
                        tooltip: copy.delete,
                        onPressed: () => social?.deleteCharacterDiscussion(
                          characterId: widget.characterId,
                          postId: post.id,
                        ),
                        icon: const Icon(Icons.delete_outline, size: 20),
                      ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

FanWorkRepository? _fanWorkRepository(BuildContext context) {
  try {
    return Provider.of<FanWorkRepository>(context, listen: false);
  } on ProviderNotFoundException {
    return null;
  }
}

CharacterEditsRepository? _characterEditsRepository(BuildContext context) {
  try {
    final repository = Provider.of<EditsRepository>(context, listen: false);
    return repository is CharacterEditsRepository
        ? repository as CharacterEditsRepository
        : null;
  } on ProviderNotFoundException {
    return null;
  }
}
