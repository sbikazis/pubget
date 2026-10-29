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
    _controller = TextEditingController(text: context.read<SearchProvider>().query);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
              onClear: () {
                _controller.clear();
                search.searchChanged('');
              },
            ),
          ),
          Expanded(child: _SearchBody(search: search)),
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
  const _SearchBody({required this.search, this.shrinkWrap = false});

  final SearchProvider search;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    if (!search.isRunnable) {
      final copy = SearchCopy.of(context);
      return PubgetEmptyState(
        title: copy.runnableTitle,
        message: copy.runnableMessage(SearchQuery.minLength),
        icon: Icons.search,
      );
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
        message: search.failure?.message ?? AppStrings.of(context).searchLoadFailed,
        onRetry: search.retry,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      itemCount: search.hits.length,
      itemBuilder: (context, index) => SearchHitTile(hit: search.hits[index]),
    );
  }
}

class SearchHitTile extends StatelessWidget {
  const SearchHitTile({required this.hit, super.key});

  final SearchHit hit;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final subtitle = _localizedSubtitle(copy);
    return ListTile(
      leading: _leading,
      title: Text(_localizedTitle(copy)),
      subtitle: subtitle == null ? null : Text(subtitle),
      onTap: () => hit.open(context),
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
    };
    return Icon(icon);
  }
}
