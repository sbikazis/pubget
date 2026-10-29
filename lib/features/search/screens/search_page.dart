import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../anime/l10n/anime_copy.dart';
import '../l10n/search_copy.dart';
import '../search_hit.dart';
import '../search_provider.dart';
import '../search_query.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: context.read<SearchProvider>().query,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Re-runs a recent search and puts the term back in the field, so the field
  /// and the results never disagree about what was searched.
  void _runRecent(SearchProvider search, String term) {
    _controller.value = TextEditingValue(
      text: term,
      selection: TextSelection.collapsed(offset: term.length),
    );
    search.searchChanged(term);
    search.recordQuery(term);
  }

  @override
  Widget build(BuildContext context) {
    final search = context.watch<SearchProvider>();
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(SearchCopy.of(context).title),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: PubgetSearchField(
              controller: _controller,
              hint: AnimeCopy.of(context).searchHomeHint,
              onChanged: search.searchChanged,
              onSubmitted: search.recordQuery,
              onClear: () {
                _controller.clear();
                search.searchChanged('');
              },
            ),
          ),
          // Two chips would be noise: only offer the filter row once the search
          // actually spans more than one entity type.
          if (search.isRunnable && search.availableFilters.length > 1)
            _FilterBar(search: search),
          Expanded(
            child: _SearchBody(
              search: search,
              onHistoryPicked: (term) => _runRecent(search, term),
            ),
          ),
        ],
      ),
    );
  }
}

/// Entity-type filter (spec §6). Only types present in the results appear.
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.search});

  final SearchProvider search;

  @override
  Widget build(BuildContext context) {
    final copy = SearchCopy.of(context);
    final labels = AppStrings.of(context);
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
            child: FilterChip(
              label: Text(copy.allFilter),
              selected: search.filter == null,
              onSelected: (_) => search.setFilter(null),
            ),
          ),
          for (final type in search.availableFilters)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
              child: FilterChip(
                label: Text(labels.searchHitLabel(type.name)),
                selected: search.filter == type,
                // Tapping the active chip clears it, so a filter is never a
                // trap the member has to hunt for a way out of.
                onSelected: (_) =>
                    search.setFilter(search.filter == type ? null : type),
              ),
            ),
        ],
      ),
    );
  }
}

class SearchResultsView extends StatelessWidget {
  const SearchResultsView({
    required this.search,
    this.shrinkWrap = false,
    super.key,
  });

  final SearchProvider search;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) =>
      _SearchBody(search: search, shrinkWrap: shrinkWrap);
}

class _SearchBody extends StatelessWidget {
  const _SearchBody({
    required this.search,
    this.shrinkWrap = false,
    this.onHistoryPicked,
  });

  final SearchProvider search;
  final bool shrinkWrap;

  /// Absent in embedded uses of [SearchResultsView], which own no text field to
  /// replay a term into.
  final ValueChanged<String>? onHistoryPicked;

  @override
  Widget build(BuildContext context) {
    if (!search.isRunnable) {
      return _HistoryAndHint(search: search, onPicked: onHistoryPicked);
    }
    if (search.state == LoadingState.loading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: <Widget>[
            PubgetSkeletonListTile(),
            PubgetSkeletonListTile(),
            PubgetSkeletonListTile(),
          ],
        ),
      );
    }
    if (search.state == LoadingState.empty) {
      final copy = SearchCopy.of(context);
      return PubgetEmptyState(
        title: copy.emptyTitle,
        message: copy.emptyMessage,
      );
    }
    if (search.state == LoadingState.offline) {
      return PubgetOfflineState(onRetry: search.retry);
    }
    if (search.state == LoadingState.error) {
      return PubgetErrorState(
        message:
            search.failure?.message ?? AppStrings.of(context).searchLoadFailed,
        onRetry: search.retry,
      );
    }
    if (search.hits.isEmpty && search.hasAnyHit) {
      // The filter emptied the list, not the backend: say so, and do not imply
      // the thing does not exist.
      final copy = SearchCopy.of(context);
      return PubgetEmptyState(
        title: copy.filterEmptyTitle,
        message: copy.filterEmptyMessage,
        icon: Icons.filter_list_off,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      itemCount: search.hits.length,
      itemBuilder: (context, index) => SearchHitTile(
        hit: search.hits[index],
        onOpen: () => search.recordQuery(search.query),
      ),
    );
  }
}

/// Recent searches above the runnable hint. A member who searched yesterday
/// should not have to retype the same name today.
class _HistoryAndHint extends StatelessWidget {
  const _HistoryAndHint({required this.search, this.onPicked});

  final SearchProvider search;
  final ValueChanged<String>? onPicked;

  @override
  Widget build(BuildContext context) {
    final copy = SearchCopy.of(context);
    final entries = onPicked == null
        ? const <String>[]
        : search.history.entries;
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: <Widget>[
        if (entries.isNotEmpty) ...<Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              0,
              AppSpacing.sm,
              0,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    copy.historyTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                TextButton(
                  onPressed: search.history.clear,
                  child: Text(copy.clearHistory),
                ),
              ],
            ),
          ),
          for (final term in entries)
            ListTile(
              leading: const Icon(Icons.history),
              title: Text(term, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                tooltip: copy.removeHistoryEntry(term),
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => search.history.remove(term),
              ),
              onTap: () => onPicked?.call(term),
            ),
          const Divider(height: AppSpacing.lg),
        ],
        PubgetEmptyState(
          title: copy.runnableTitle,
          message: copy.runnableMessage(SearchQuery.minLength),
          icon: Icons.search,
        ),
      ],
    );
  }
}

class SearchHitTile extends StatelessWidget {
  const SearchHitTile({required this.hit, this.onOpen, super.key});

  final SearchHit hit;

  /// Fired before navigation so the query can be remembered as a real search.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final subtitle = _localizedSubtitle(copy);
    return ListTile(
      leading: _leading,
      title: Text(_localizedTitle(copy)),
      subtitle: subtitle == null ? null : Text(subtitle),
      onTap: () {
        onOpen?.call();
        hit.open(context);
      },
    );
  }

  /// People without a chosen username are stored with the English sentinel
  /// 'Pubget user'. Swap it for the localized fallback so the Arabic build
  /// never shows an English placeholder.
  String _localizedTitle(AppStrings copy) {
    if (hit.type == SearchHitType.user && hit.title == 'Pubget user') {
      return copy.pubgetUser;
    }
    return hit.title;
  }

  /// Discovery results carry literal kind labels ('Event', 'Person', …) baked
  /// in at search time. Swap the known literals for the localized label and
  /// keep anything authored (e.g. a fan-work creator name) untouched.
  String? _localizedSubtitle(AppStrings copy) {
    final raw = hit.subtitle;
    if (raw == null || raw.isEmpty) return null;
    final isKindLiteral = switch (hit.type) {
      SearchHitType.group => raw == 'Group',
      SearchHitType.user => raw == 'Person',
      SearchHitType.event => raw == 'Event',
      SearchHitType.anime => raw == 'Anime',
      SearchHitType.fanWork => raw == 'Fan Work',
      SearchHitType.character => raw == 'شخصية',
      SearchHitType.reel => raw == 'ريل',
      SearchHitType.audio => raw == 'Audio',
      SearchHitType.hashtag => raw == 'Hashtag',
    };
    if (!isKindLiteral) return raw;
    final label = copy.searchHitLabel(hit.type.name);
    return label.isEmpty ? raw : label;
  }

  Widget get _leading {
    if (hit.imageUrl != null && hit.imageUrl!.isNotEmpty) {
      return PubgetAvatar(
        imageUrl: hit.imageUrl,
        name: hit.title,
        size: PubgetAvatarSize.small,
      );
    }
    final icon = switch (hit.type) {
      SearchHitType.group => Icons.groups_outlined,
      SearchHitType.user => Icons.person_outline,
      SearchHitType.event => Icons.celebration_outlined,
      SearchHitType.anime => Icons.movie_outlined,
      SearchHitType.fanWork => Icons.auto_awesome_outlined,
      SearchHitType.character => Icons.face_outlined,
      SearchHitType.reel => Icons.video_library_outlined,
      SearchHitType.audio => Icons.music_note_outlined,
      SearchHitType.hashtag => Icons.tag,
    };
    return Icon(icon);
  }
}
