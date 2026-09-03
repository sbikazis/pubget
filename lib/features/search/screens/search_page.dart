import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../anime/models/anime_models.dart';
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
      appBar: AppBar(title: const Text('Search')),
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
              hint: AnimeStrings.searchHomeHint,
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
      return PubgetEmptyState(
        title: 'Search Pubget',
        message:
            'Type at least ${SearchQuery.minLength} characters to find groups, people, events, anime, and Fan Works.',
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
      return const PubgetEmptyState(
        title: 'Nothing found',
        message: 'Try another group, username, event, anime, or Fan Work.',
      );
    }
    if (search.state == LoadingState.offline) {
      return PubgetOfflineState(onRetry: search.retry);
    }
    if (search.state == LoadingState.error) {
      return PubgetErrorState(
        message: search.failure?.message ?? 'Search failed.',
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
    return ListTile(
      leading: _leading,
      title: Text(hit.title),
      subtitle: hit.subtitle == null ? null : Text(hit.subtitle!),
      onTap: () => hit.open(context),
    );
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
    };
    return Icon(icon);
  }
}
