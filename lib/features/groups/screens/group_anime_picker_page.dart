import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../l10n/group_copy.dart';
import '../models/group_catalog_models.dart';
import '../providers/group_catalog_provider.dart';
import '../repositories/group_catalog_repository.dart';

/// Picks the anime a group is bound to out of the whole catalog.
///
/// The previous version held one page of "most popular" titles and ranked them
/// on the device, so any title outside the top twenty was unreachable and a
/// search only ever searched what was already on screen. Every list here comes
/// from the server catalog with a page number, and the next page is fetched
/// when the end comes into view.
class GroupAnimePickerPage extends StatefulWidget {
  const GroupAnimePickerPage({super.key, this.initialYear, this.initialSeason});

  /// Preselects a broadcast season, so opening the picker from a season list
  /// keeps the axis the user came from.
  final int? initialYear;
  final String? initialSeason;

  @override
  State<GroupAnimePickerPage> createState() => _GroupAnimePickerPageState();
}

class _GroupAnimePickerPageState extends State<GroupAnimePickerPage> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  GroupCatalogProvider? _owned;
  bool _opened = false;
  GroupCatalogRequest? _request;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) return;
    _opened = true;
    final provider = _own(context);
    final request = _initialRequest();
    _request = request;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) provider.openAnime(request);
    });
  }

  GroupCatalogRequest _initialRequest() {
    if (widget.initialYear != null &&
        (widget.initialSeason ?? '').isNotEmpty) {
      return GroupCatalogRequest.seasonOf(
        widget.initialYear!,
        widget.initialSeason!,
      );
    }
    return const GroupCatalogRequest();
  }

  GroupCatalogProvider _own(BuildContext context) {
    if (_owned != null) return _owned!;
    GroupCatalogRepository repository;
    try {
      repository = context.read<GroupCatalogRepository>();
    } on ProviderNotFoundException {
      repository = const UnavailableGroupCatalogRepository();
    }
    final provider = GroupCatalogProvider(repository: repository)
      ..addListener(_onChange);
    _owned = provider;
    return provider;
  }

  void _onChange() {
    if (!mounted) return;
    // Reaching the end asks for the next page; the provider guards against a
    // duplicate request, so scrolling back and forth cannot double-fetch.
    if (_scroll.hasClients && _scroll.position.extentAfter < 320) {
      final provider = _owned;
      if (provider != null && provider.animeHasNextPage) {
        provider.loadMoreAnime();
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    _owned?.removeListener(_onChange);
    _owned?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = GroupCopy.of(context);
    final provider = _own(context);
    final items = provider.anime;
    final hasQuery = _search.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(copy.selectAnime),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              0,
            ),
            child: PubgetSearchField(
              key: const Key('group-anime-search'),
              controller: _search,
              hint: copy.searchAnime,
              onChanged: (value) {
                setState(() {});
                provider.searchAnime(value);
              },
              onClear: () {
                _search.clear();
                setState(() {});
                _open(provider, _initialRequest());
              },
            ),
          ),
          if (!hasQuery) ...<Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: _AxisBar(
                selected: _request,
                onSelected: (request) => _open(provider, request),
              ),
            ),
            if (_request?.kind == GroupCatalogKind.season)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  0,
                ),
                child: _SeasonPicker(
                  year: _request?.year,
                  season: _request?.season,
                  onChanged: (year, season) => _open(
                    provider,
                    GroupCatalogRequest.seasonOf(year, season),
                  ),
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: PubgetLoadingStateView(
              state: provider.animeState,
              onRetry: provider.retryAnime,
              empty: PubgetEmptyState(
                key: const Key('group-anime-empty'),
                title: copy.noAnime,
                message: hasQuery ? copy.catalogSearchHint : copy.noAnimeHint,
                icon: Icons.search_off_outlined,
              ),
              error: PubgetErrorState(
                key: const Key('group-anime-error'),
                message: provider.animeFailure?.message ?? copy.noAnime,
                onRetry: provider.retryAnime,
              ),
              offline: PubgetOfflineState(
                key: const Key('group-anime-offline'),
                message: copy.catalogUnavailable,
                onRetry: provider.retryAnime,
              ),
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.metrics.extentAfter < 320) {
                    provider.loadMoreAnime();
                  }
                  return false;
                },
                child: ListView.separated(
                  key: const Key('group-anime-list'),
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  itemCount: items.length + 1,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    if (index == items.length) {
                      return _AnimeFooter(
                        loading: provider.animeLoadingMore,
                        failure: provider.animePageFailure,
                        hasNextPage: provider.animeHasNextPage,
                        onRetry: provider.retryAnimePage,
                        onLoadMore: provider.loadMoreAnime,
                      );
                    }
                    final anime = items[index];
                    return PubgetCard(
                      key: Key('group-anime-${anime.id}'),
                      onTap: () => Navigator.pop(
                        context,
                        anime.toAnime(),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: SizedBox(
                          width: 48,
                          height: 64,
                          child: anime.imageUrl.isEmpty
                              ? const ColoredBox(
                                  color: Color(0x332C1654),
                                  child: Icon(Icons.movie_outlined),
                                )
                              : AppImageLoader(
                                  imageUrl: anime.imageUrl,
                                  fit: BoxFit.cover,
                                ),
                        ),
                        title: Text(anime.title),
                        subtitle: Text(
                          anime.subtitleParts.isEmpty
                              ? anime.genres.take(3).join(' · ')
                              : anime.subtitleParts,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _open(GroupCatalogProvider provider, GroupCatalogRequest request) {
    if (_search.text.trim().isNotEmpty) _search.clear();
    setState(() => _request = request);
    if (_scroll.hasClients) _scroll.jumpTo(0);
    provider.openAnime(request);
  }
}

/// The tail of the list. A failed page keeps the rows above it and offers a
/// retry; it never blanks the list it failed to extend.
class _AnimeFooter extends StatelessWidget {
  const _AnimeFooter({
    required this.loading,
    required this.failure,
    required this.hasNextPage,
    required this.onRetry,
    required this.onLoadMore,
  });

  final bool loading;
  final Object? failure;
  final bool hasNextPage;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final copy = GroupCopy.of(context);
    if (failure != null) {
      return PubgetCard(
        key: const Key('group-anime-page-failure'),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                copy.pageLoadFailed,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            TextButton(
              key: const Key('group-anime-page-retry'),
              onPressed: onRetry,
              child: Text(copy.retry),
            ),
          ],
        ),
      );
    }
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (hasNextPage) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(
          child: TextButton(
            key: const Key('group-anime-load-more'),
            onPressed: onLoadMore,
            child: Text(copy.loadMore),
          ),
        ),
      );
    }
    return const SizedBox(height: AppSpacing.lg);
  }
}

class _AxisBar extends StatelessWidget {
  const _AxisBar({required this.selected, required this.onSelected});

  final GroupCatalogRequest? selected;
  final ValueChanged<GroupCatalogRequest> onSelected;

  static const _axes = <GroupCatalogKind>[
    GroupCatalogKind.trending,
    GroupCatalogKind.popular,
    GroupCatalogKind.top,
    GroupCatalogKind.airing,
    GroupCatalogKind.upcoming,
    GroupCatalogKind.thisSeason,
    GroupCatalogKind.season,
  ];

  @override
  Widget build(BuildContext context) {
    final copy = GroupCopy.of(context);
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _axes.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final kind = _axes[index];
          final isSelected = selected?.kind == kind && !_isSearch(selected);
          return PubgetSelectionChip(
            key: Key('group-anime-axis-${kind.name}'),
            label: copy.catalogAxisLabel(kind.name),
            selected: isSelected,
            onSelected: (_) => onSelected(GroupCatalogRequest(kind: kind)),
          );
        },
      ),
    );
  }

  bool _isSearch(GroupCatalogRequest? request) =>
      (request?.query.trim() ?? '').isNotEmpty;
}

class _SeasonPicker extends StatelessWidget {
  const _SeasonPicker({
    required this.year,
    required this.season,
    required this.onChanged,
  });

  final int? year;
  final String? season;
  final void Function(int year, String season) onChanged;

  static const _seasons = <String>['winter', 'spring', 'summer', 'fall'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final years = <int>[now.year, now.year - 1, now.year - 2, now.year - 3];
    final selectedYear = year ?? now.year;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (final option in years)
          PubgetSelectionChip(
            key: Key('group-anime-year-$option'),
            label: '$option',
            selected: selectedYear == option,
            onSelected: (_) => onChanged(
              option,
              season ?? _current(now),
            ),
          ),
        for (final option in _seasons)
          PubgetSelectionChip(
            key: Key('group-anime-season-$option'),
            label: option,
            selected: selectedYear == (year ?? now.year) && season == option,
            onSelected: (_) => onChanged(selectedYear, option),
          ),
      ],
    );
  }

  static String _current(DateTime now) => switch (now.month) {
    >= 12 => 'winter',
    >= 9 => 'fall',
    >= 6 => 'summer',
    _ => 'spring',
  };
}
