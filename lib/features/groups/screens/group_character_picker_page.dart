import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../l10n/group_copy.dart';
import '../models/group_catalog_models.dart';
import '../models/group_models.dart';
import '../providers/group_catalog_provider.dart';
import '../repositories/group_catalog_repository.dart';
import '../widgets/catalog_starter_list.dart';

/// Picks the character a member will play, or that a founder reserves.
///
/// A group bound to an anime answers with the cast of the whole work — every
/// season of it, each character tagged with the seasons it is credited in — so
/// a character that only appears in a later season is still reachable, and a
/// title whose cast is split across a cour is not treated as two different
/// groups. A group that is not bound to one anime answers with the character
/// catalog itself. The previous version read a single anime's characters
/// through the client repository, or a social "popular" table that is empty on
/// a new product, and then filtered that list on the device; both paths are
/// gone.
class GroupCharacterPickerPage extends StatefulWidget {
  const GroupCharacterPickerPage({
    this.animeId,
    this.reservedKeys = const <String>{},
    this.catalog,
    super.key,
  });

  final String? animeId;
  final Set<String> reservedKeys;
  final List<RoleplayCharacter>? catalog;

  @override
  State<GroupCharacterPickerPage> createState() =>
      _GroupCharacterPickerPageState();
}

class _GroupCharacterPickerPageState extends State<GroupCharacterPickerPage> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  GroupCatalogProvider? _owned;
  bool _opened = false;

  bool get _open =>
      widget.animeId != null && widget.animeId!.trim().isNotEmpty;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) return;
    _opened = true;
    final provider = _own(context);
    if (widget.reservedKeys.isNotEmpty) provider.reserve(widget.reservedKeys);
    if (widget.catalog != null) {
      // A roster handed in by the caller is used as-is: it is already the
      // group's own list, and re-asking the catalog would only reorder it.
      _seeded = widget.catalog!;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) provider.openCharacters(_request());
      });
    }
  }

  late List<RoleplayCharacter> _seeded = const <RoleplayCharacter>[];

  GroupCharacterRequest _request() => _open
      ? GroupCharacterRequest.forAnime(widget.animeId!.trim())
      : const GroupCharacterRequest.open();

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
    if (_scroll.hasClients && _scroll.position.extentAfter < 320) {
      final provider = _owned;
      if (provider != null && provider.charactersHasNextPage) {
        provider.loadMoreCharacters();
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
    final seeded = _seeded;
    final reserved = widget.reservedKeys;
    final items = seeded.isNotEmpty
        ? seeded
              .map(
                (item) => reserved.contains(item.key) ? item.asReserved() : item,
              )
              .toList(growable: false)
        : provider.characters
              .map(
                (item) => reserved.contains(item.key) ? item.asReserved() : item,
              )
              .toList(growable: false);
    final searching = _search.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(copy.selectCharacter),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            PubgetSearchField(
              key: const Key('group-character-search'),
              controller: _search,
              hint: copy.searchCharacters,
              onChanged: (value) {
                setState(() {});
                if (seeded.isEmpty) provider.searchCharacters(value);
              },
              onClear: () {
                _search.clear();
                setState(() {});
                if (seeded.isEmpty) provider.searchCharacters('');
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              // Before a keystroke the roster scope explains nothing to a user
              // who cannot see a roster yet, and "this group is not bound to
              // one anime" read as a fault. The scope is kept for once there is
              // a list or a search to explain.
              searching || items.isNotEmpty
                  ? (_open ? copy.wholeWorkHint : copy.freeRosterHint)
                  : copy.startTypingToSearch,
              key: const Key('group-character-hint'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (provider.seasons.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              _SeasonStrip(
                title: copy.seasonsOfWork,
                seasons: provider.seasons,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: seeded.isNotEmpty
                  ? _grid(items, const <Widget>[])
                  : !searching && items.isEmpty
                  ? _starter(provider, copy)
                  : PubgetLoadingStateView(
                      state: provider.charactersState,
                      onRetry: provider.retryCharacters,
                      empty: PubgetEmptyState(
                        key: const Key('group-character-empty'),
                        title: copy.noCharacters,
                        message: copy.catalogSearchHint,
                        icon: Icons.person_off_outlined,
                      ),
                      error: PubgetErrorState(
                        key: const Key('group-character-error'),
                        message:
                            provider.charactersFailure?.message ??
                            copy.roleplayCharactersLoadFailed,
                        onRetry: provider.retryCharacters,
                      ),
                      offline: PubgetOfflineState(
                        key: const Key('group-character-offline'),
                        message: copy.catalogUnavailable,
                        onRetry: provider.retryCharacters,
                      ),
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification.metrics.extentAfter < 320) {
                            provider.loadMoreCharacters();
                          }
                          return false;
                        },
                        child: _grid(items, <Widget>[
                          _CharacterFooter(
                            loading: provider.charactersLoadingMore,
                            failure: provider.charactersPageFailure,
                            hasNextPage: provider.charactersHasNextPage,
                            onRetry: provider.retryCharactersPage,
                            onLoadMore: provider.loadMoreCharacters,
                          ),
                        ]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// The page before anything has been typed. A roster that failed or came back
  /// with nothing is one quiet line here, not an error screen: the search is
  /// server-backed and answers from the first letter, so the picker looks ready
  /// rather than broken. "No results" stays reserved for a search that ran.
  ///
  /// A group bound to one work gets no name shortcuts: its roster is filtered
  /// to that work server-side, so a name from another series would only miss.
  Widget _starter(GroupCatalogProvider provider, GroupCopy copy) =>
      CatalogStarterList(
    key: const Key('group-character-starter'),
    subtitle: copy.startTypingToSearch,
    seeds: _open ? const <String>[] : catalogStarterCharacterSearches,
    onPick: _searchFor,
    notice: switch (provider.charactersState) {
      LoadingState.error =>
        provider.charactersFailure?.message ?? copy.roleplayCharactersLoadFailed,
      LoadingState.offline => copy.catalogUnavailable,
      _ => null,
    },
    onRetry: provider.retryCharacters,
  );

  void _searchFor(String term) {
    _search.text = term;
    _search.selection = TextSelection.collapsed(offset: term.length);
    setState(() {});
    _owned?.searchCharacters(term);
  }

  Widget _grid(List<RoleplayCharacter> items, List<Widget> footer) {
    if (items.isEmpty && footer.isEmpty) {
      return const SizedBox.shrink();
    }
    return CustomScrollView(
      controller: _scroll,
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 0.78,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _CharacterTile(
                character: items[index],
                onTap: () => _select(items[index]),
              ),
              childCount: items.length,
            ),
          ),
        ),
        for (final child in footer)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: child,
            ),
          ),
      ],
    );
  }

  void _select(RoleplayCharacter character) {
    final copy = GroupCopy.of(context);
    if (character.reserved) {
      PubgetSnackbars.showInfo(context, copy.characterReserved);
      return;
    }
    Navigator.pop(context, character);
  }
}

/// The seasons of the linked work, so a member can see that a cast member
/// belongs to a later season before claiming them.
class _SeasonStrip extends StatelessWidget {
  const _SeasonStrip({required this.title, required this.seasons});

  final String title;
  final List<CatalogSeason> seasons;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: seasons.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final season = seasons[index];
              return PubgetSelectionChip(
                key: Key('group-season-${season.id}'),
                label: season.label.isEmpty ? season.title : season.label,
                selected: false,
                onSelected: (_) {},
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CharacterFooter extends StatelessWidget {
  const _CharacterFooter({
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
        key: const Key('group-character-page-failure'),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                copy.pageLoadFailed,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            TextButton(
              key: const Key('group-character-page-retry'),
              onPressed: onRetry,
              child: Text(copy.retry),
            ),
          ],
        ),
      );
    }
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (hasNextPage) {
      return Center(
        child: TextButton(
          key: const Key('group-character-load-more'),
          onPressed: onLoadMore,
          child: Text(copy.loadMore),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _CharacterTile extends StatelessWidget {
  const _CharacterTile({required this.character, required this.onTap});

  final RoleplayCharacter character;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final copy = GroupCopy.of(context);
    return PubgetCard(
      key: Key('group-character-${character.key}'),
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Column(
            children: <Widget>[
              Expanded(
                child: character.avatarUrl.isEmpty
                    ? const ColoredBox(
                        color: Color(0x332C1654),
                        child: Center(child: Icon(Icons.person_outline)),
                      )
                    : AppImageLoader(
                        imageUrl: character.avatarUrl,
                        fit: BoxFit.cover,
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      character.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (character.seasons.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          character.seasons.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (character.reserved)
            DecoratedBox(
              decoration: const BoxDecoration(color: Color(0x99210F2E)),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.lock_outline,
                      color: Colors.white70,
                      size: 32,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        copy.reservedByOthers,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
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
