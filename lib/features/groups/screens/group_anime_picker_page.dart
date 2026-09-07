import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../anime/l10n/anime_copy.dart';
import '../../anime/models/anime_models.dart';
import '../../anime/providers/anime_providers.dart';
import '../../anime/repositories/anime_repository.dart';
import '../data/group_fuzzy.dart';
import '../l10n/group_copy.dart';

class GroupAnimePickerPage extends StatefulWidget {
  const GroupAnimePickerPage({super.key});

  @override
  State<GroupAnimePickerPage> createState() => _GroupAnimePickerPageState();
}

class _GroupAnimePickerPageState extends State<GroupAnimePickerPage> {
  final _search = TextEditingController();
  AnimeListProvider? _owned;
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;
    AnimeListProvider? existing;
    try {
      existing = context.read<AnimeListProvider>();
    } on ProviderNotFoundException {
      existing = null;
    }
    if (existing == null) {
      try {
        final repo = context.read<AnimeRepository>();
        _owned = AnimeListProvider(repository: repo, debounce: Duration.zero)
          ..addListener(() {
            if (mounted) setState(() {});
          });
      } on ProviderNotFoundException {
        _owned = null;
      }
    }
    final list = existing ?? _owned;
    if (list != null && list.items.isEmpty && list.query.isEmpty) {
      Future<void>.microtask(() => list.openCatalog(AnimeCatalogKind.popular));
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _owned?.dispose();
    super.dispose();
  }

  AnimeListProvider? _listOf(BuildContext context) {
    if (_owned != null) return _owned;
    try {
      return context.watch<AnimeListProvider>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  AnimeHubProvider? _hub(BuildContext context) {
    try {
      return context.watch<AnimeHubProvider>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = GroupCopy.of(context);
    final list = _listOf(context);
    final hub = _hub(context);
    final items = _visible(list);
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(copy.selectAnime),
        actions: <Widget>[
          PubgetIconButton(
            key: const Key('group-anime-filter'),
            icon: Icons.filter_list,
            tooltip: copy.filters,
            onPressed: list == null
                ? null
                : () => _openFilters(context, list, hub),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: <Widget>[
            PubgetSearchField(
              key: const Key('group-anime-search'),
              controller: _search,
              hint: copy.searchAnime,
              onChanged: (value) {
                list?.searchChanged(value);
                setState(() {});
              },
              onClear: () {
                _search.clear();
                list?.clearSearch();
                list?.openCatalog(AnimeCatalogKind.popular);
                setState(() {});
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: list == null
                  ? PubgetEmptyState(
                      title: copy.noAnime,
                      message: copy.noAnimeHint,
                    )
                  : PubgetLoadingStateView(
                      state: list.state,
                      onRetry: () => list.query.trim().isEmpty
                          ? list.openCatalog(AnimeCatalogKind.popular)
                          : list.retrySearch(),
                      empty: PubgetEmptyState(
                        key: const Key('group-anime-empty'),
                        title: copy.noAnime,
                        message: copy.noAnimeHint,
                        icon: Icons.search_off_outlined,
                      ),
                      error: PubgetErrorState(
                        message: list.failure?.message ?? copy.noAnime,
                        onRetry: () => list.query.trim().isEmpty
                            ? list.openCatalog(AnimeCatalogKind.popular)
                            : list.retrySearch(),
                      ),
                      offline: PubgetOfflineState(
                        onRetry: () => list.query.trim().isEmpty
                            ? list.openCatalog(AnimeCatalogKind.popular)
                            : list.retrySearch(),
                      ),
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final anime = items[index];
                          return PubgetCard(
                            key: Key('group-anime-${anime.id}'),
                            onTap: () => Navigator.pop(context, anime),
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: SizedBox(
                                width: 48,
                                height: 64,
                                child: anime.images.displayUrl == null
                                    ? const ColoredBox(
                                        color: Color(0x332C1654),
                                        child: Icon(Icons.movie_outlined),
                                      )
                                    : AppImageLoader(
                                        imageUrl: anime.images.displayUrl!,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                              title: Text(anime.title),
                              subtitle: Text(
                                [
                                  if (anime.year != null) '${anime.year}',
                                  if (anime.type != null) anime.type!,
                                ].join(' · '),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Anime> _visible(AnimeListProvider? list) {
    if (list == null) return const <Anime>[];
    final query = _search.text;
    if (query.trim().isEmpty) return list.items;
    final filtered = list.items
        .where(
          (anime) =>
              GroupFuzzy.matches(query, anime.title) ||
              anime.alternativeTitles.any(
                (title) => GroupFuzzy.matches(query, title),
              ),
        )
        .toList(growable: false);
    return filtered.isEmpty ? list.items : filtered;
  }

  Future<void> _openFilters(
    BuildContext context,
    AnimeListProvider list,
    AnimeHubProvider? hub,
  ) async {
    final copy = GroupCopy.of(context);
    final anime = AnimeCopy.of(context);
    await PubgetBottomSheet.show<void>(
      context,
      title: copy.filters,
      isScrollControlled: true,
      child: _AnimeFilterSheet(list: list, hub: hub, anime: anime),
    );
  }
}

class _AnimeFilterSheet extends StatelessWidget {
  const _AnimeFilterSheet({
    required this.list,
    required this.hub,
    required this.anime,
  });

  final AnimeListProvider list;
  final AnimeHubProvider? hub;
  final AnimeCopy anime;

  @override
  Widget build(BuildContext context) {
    final filter = list.filter;
    final years = hub?.seasons.take(8).map((item) => item.year).toList() ??
        <int>[DateTime.now().year];
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final type in AnimeTypeFilter.values)
                PubgetSelectionChip(
                  label: anime.typeFilter(type),
                  selected: filter.type == type,
                  onSelected: (_) => list.applyFilter(
                    filter.copyWith(
                      type: type,
                      clearType: filter.type == type,
                    ),
                  ),
                ),
              for (final season in AnimeSeason.values)
                PubgetSelectionChip(
                  label: anime.season(season),
                  selected: filter.season == season,
                  onSelected: (_) => list.applyFilter(
                    filter.copyWith(
                      season: season,
                      year: filter.year ?? DateTime.now().year,
                      clearSeason: filter.season == season,
                      clearYear: filter.season == season,
                    ),
                  ),
                ),
              for (final year in years)
                PubgetSelectionChip(
                  label: '$year',
                  selected: filter.year == year,
                  onSelected: (_) => list.applyFilter(
                    filter.copyWith(
                      year: year,
                      season: filter.season ?? AnimeSeason.fromDate(DateTime.now()),
                      clearYear: filter.year == year,
                      clearSeason: filter.year == year,
                    ),
                  ),
                ),
              if (hub != null)
                for (final genre in hub!.genres.take(16))
                  PubgetSelectionChip(
                    label: anime.genre(genre.name),
                    selected: filter.genreId == genre.id,
                    onSelected: (_) => list.applyFilter(
                      filter.copyWith(
                        genreId: genre.id,
                        clearGenre: filter.genreId == genre.id,
                      ),
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}
