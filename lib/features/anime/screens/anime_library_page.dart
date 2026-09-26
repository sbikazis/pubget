import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../l10n/anime_copy.dart';
import '../models/anime_list_models.dart';
import '../providers/anime_library_provider.dart';
import '../providers/anime_my_list_provider.dart';
import '../widgets/anime_hub_widgets.dart';
import '../widgets/anime_widgets.dart';

/// "My list": the five personal states, searchable, sortable and renderable
/// either as a 3-column grid or as a network list.
///
/// There is no episode list and no watch action anywhere on this page: it
/// tracks what a member intends to do with a title, nothing more.
class AnimeLibraryPage extends StatefulWidget {
  const AnimeLibraryPage({super.key});

  @override
  State<AnimeLibraryPage> createState() => _AnimeLibraryPageState();
}

class _AnimeLibraryPageState extends State<AnimeLibraryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: AnimeListStatus.tabs.length,
    vsync: this,
  );
  final TextEditingController _search = TextEditingController();
  final Map<AnimeListStatus, ScrollController> _scroll =
      <AnimeListStatus, ScrollController>{};
  AnimeMyListProvider? _myList;

  @override
  void initState() {
    super.initState();
    for (final status in AnimeListStatus.tabs) {
      _scroll[status] = ScrollController(
        initialScrollOffset: 0,
        keepScrollOffset: true,
      )..addListener(() => _remember(status));
    }
  }

  void _remember(AnimeListStatus status) {
    final offset = _scroll[status]?.offset;
    if (offset == null) return;
    _myList?.rememberScrollOffset(status, offset);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final myList = maybeAnimeMyList(context, listen: false);
    if (identical(myList, _myList)) return;
    _myList = myList;
    myList?.addListener(_syncTab);
    final initial = myList?.scrollOffsetFor(myList.tab) ?? 0;
    final controller = _scroll[myList?.tab];
    if (controller != null && controller.hasClients && initial > 0) {
      controller.jumpTo(initial);
    }
    _hydrateAfterFrame();
  }

  /// Loading notifies listeners, so it has to happen after the current frame
  /// rather than from inside `initState` or `didChangeDependencies`.
  void _hydrateAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<AnimeLibraryProvider>().load();
      if (!mounted) return;
      await _myList?.hydrate();
    });
  }

  void _syncTab() {
    final myList = _myList;
    if (myList == null) return;
    final index = AnimeListStatus.tabs.indexOf(myList.tab);
    if (index >= 0 && index != _tabs.index) {
      _tabs.animateTo(index);
    }
    final offset = myList.scrollOffsetFor(myList.tab);
    final controller = _scroll[myList.tab];
    if (controller != null && controller.hasClients && offset > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!controller.hasClients) return;
        if ((controller.offset - offset).abs() > 1) controller.jumpTo(offset);
      });
    }
  }

  @override
  void dispose() {
    _myList?.removeListener(_syncTab);
    for (final controller in _scroll.values) {
      controller.dispose();
    }
    _search.dispose();
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = AnimeCopy.of(context);
    final library = context.watch<AnimeLibraryProvider>();
    final myList = maybeAnimeMyList(context);
    final signedIn = context.select<AuthProvider, bool>(
      (auth) => auth.currentUser != null,
    );

    return AnimeHubBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: AppBackButton.maybeOf(context),
          title: Text(copy.libraryTitle),
          actions: <Widget>[
            if (myList != null)
              IconButton(
                key: const Key('anime-my-list-view-toggle'),
                tooltip: myList.view.name,
                onPressed: myList.toggleView,
                icon: Icon(
                  myList.view == AnimeListView.grid
                      ? Icons.grid_view_rounded
                      : Icons.view_agenda_outlined,
                ),
              ),
            if (myList != null)
              IconButton(
                key: const Key('anime-my-list-sort'),
                tooltip: copy.sortBy,
                onPressed: () => _openSortSheet(context, myList),
                icon: const Icon(Icons.swap_vert_rounded),
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(96),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: TextField(
                    key: const Key('anime-my-list-search'),
                    controller: _search,
                    onChanged: (value) => myList?.setQuery(value),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: copy.searchInList,
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _search.clear();
                                myList?.setQuery('');
                              },
                            ),
                    ),
                  ),
                ),
                if (myList != null)
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      children: <Widget>[
                        for (final filter in AnimeListFormatFilter.values)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              end: AppSpacing.sm,
                            ),
                            child: ChoiceChip(
                              key: ValueKey<String>(
                                'anime-format-${filter.wireValue}',
                              ),
                              label: Text(_formatLabel(context, filter)),
                              selected: myList.format == filter,
                              onSelected: (_) => myList.setFormat(filter),
                            ),
                          ),
                      ],
                    ),
                  ),
                TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  onTap: (index) =>
                      myList?.selectTab(AnimeListStatus.tabs[index]),
                  tabs: <Widget>[
                    for (final status in AnimeListStatus.tabs)
                      Tab(text: copy.listStatusLabel(status)),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: !signedIn
            ? PubgetEmptyState(
                title: copy.signInToSaveList,
                icon: Icons.lock_outline,
              )
            : _body(context, library, myList, copy),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AnimeLibraryProvider library,
    AnimeMyListProvider? myList,
    AnimeCopy copy,
  ) {
    if (library.state == LoadingState.error && library.entries.isEmpty) {
      return PubgetErrorState(
        title: copy.unableToLoad,
        message: library.failure?.message ?? copy.checkConnection,
        onRetry: library.load,
      );
    }
    if (library.state == LoadingState.loading && library.entries.isEmpty) {
      return const AnimeHubGridSkeleton();
    }

    return TabBarView(
      controller: _tabs,
      physics: const PageScrollPhysics(),
      children: <Widget>[
        for (final status in AnimeListStatus.tabs)
          _StatusTab(
            status: status,
            myList: myList,
            library: library,
            controller: _scroll[status]!,
          ),
      ],
    );
  }

  Future<void> _openSortSheet(
    BuildContext context,
    AnimeMyListProvider myList,
  ) async {
    final selected = await showModalBottomSheet<AnimeListSort>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            for (final sort in AnimeListSort.values)
              RadioListTile<AnimeListSort>(
                key: ValueKey<String>('anime-sort-${sort.name}'),
                value: sort,
                groupValue: myList.sort,
                title: Text(_sortLabel(context, sort)),
                onChanged: (value) => Navigator.of(context).pop(value),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    myList.setSort(selected);
    for (final status in AnimeListStatus.tabs) {
      final controller = _scroll[status];
      if (controller != null && controller.hasClients) controller.jumpTo(0);
    }
    myList.resetScrollOffsets();
  }

  String _sortLabel(BuildContext context, AnimeListSort sort) {
    final copy = AnimeCopy.of(context);
    return switch (sort) {
      AnimeListSort.recentlyUpdated => copy.sortRecentlyUpdated,
      AnimeListSort.titleAsc => copy.sortTitleAsc,
      AnimeListSort.titleDesc => copy.sortTitleDesc,
      AnimeListSort.ratingDesc => copy.sortRatingDesc,
      AnimeListSort.ratingAsc => copy.sortRatingAsc,
      AnimeListSort.popularityDesc => copy.sortPopularityDesc,
      AnimeListSort.yearDesc => copy.sortYearDesc,
      AnimeListSort.yearAsc => copy.sortYearAsc,
    };
  }

  String _formatLabel(BuildContext context, AnimeListFormatFilter filter) {
    final copy = AnimeCopy.of(context);
    if (filter == AnimeListFormatFilter.all) return copy.formatAll;
    if (filter.isAiringState) return copy.status('Airing');
    return copy.typeLabel(filter.wireValue);
  }
}

class _StatusTab extends StatelessWidget {
  const _StatusTab({
    required this.status,
    required this.myList,
    required this.library,
    required this.controller,
  });

  final AnimeListStatus status;
  final AnimeMyListProvider? myList;
  final AnimeLibraryProvider library;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final copy = AnimeCopy.of(context);
    final view = myList;
    final entries = view?.entriesFor(status) ?? library.byStatus(status);

    if (entries.isEmpty) {
      final filtered = view != null && view.hasActiveFilters;
      return PubgetEmptyState(
        title: filtered ? copy.nothingFound : copy.libraryEmpty,
        message: filtered ? copy.nothingFoundMessage : copy.libraryEmptyMessage,
        icon: filtered ? Icons.search_off_rounded : Icons.bookmark_border,
      );
    }

    if (view != null && view.view == AnimeListView.network) {
      return ListView.builder(
        controller: controller,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          final summary = view.animeFor(entry.animeId);
          return AnimeHubNetworkTile(
            key: ValueKey<String>('anime-entry-${entry.animeId}'),
            title: summary?.title.isNotEmpty == true
                ? summary!.title
                : entry.title,
            imageUrl: summary?.images.thumbnailUrl ?? '',
            subtitle: [
              if (summary?.year != null) '${summary!.year}',
              if (summary != null && summary.type != null)
                copy.typeLabel(summary.type),
            ].join(' · '),
            trailingLabel: copy.listStatusLabel(entry.status),
            onTap: () => AnimeLinks.openDetails(context, entry.animeId),
            onLongPress: () => _openActions(context, entry),
          );
        },
      );
    }

    final hydrating = view?.hydrating ?? false;
    return Stack(
      children: <Widget>[
        AnimeHubGrid(
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            final summary = view?.animeFor(entry.animeId);
            return AnimeHubPosterCard(
              key: ValueKey<String>('anime-entry-${entry.animeId}'),
              title: summary?.title.isNotEmpty == true
                  ? summary!.title
                  : entry.title,
              imageUrl: summary?.images.thumbnailUrl ?? '',
              year: summary?.year,
              subtitle: copy.typeLabel(summary?.type),
              rating: entry.rating,
              favorite: entry.favorite,
              statusLabel: copy.listStatusLabel(entry.status),
              onTap: () => AnimeLinks.openDetails(context, entry.animeId),
              onLongPress: () => _openActions(context, entry),
            );
          },
        ),
        if (hydrating)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }

  Future<void> _openActions(BuildContext context, AnimeListEntry entry) async {
    final copy = AnimeCopy.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                key: const Key('anime-entry-change-status'),
                leading: const Icon(Icons.swap_horiz_rounded),
                title: Text(copy.changeStatus),
                onTap: () => Navigator.of(context).pop('status'),
              ),
              ListTile(
                key: const Key('anime-entry-remove'),
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(copy.removeFromList),
                onTap: () => Navigator.of(context).pop('remove'),
              ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    if (action == 'remove') {
      await library.remove(entry.animeId);
      return;
    }
    final next = await showAnimeStatusSheet(context, current: entry.status);
    if (next == null || next == entry.status) return;
    await library.setStatus(
      animeId: entry.animeId,
      status: next,
      title: entry.title,
      rating: entry.rating,
      favorite: entry.favorite,
    );
  }
}
