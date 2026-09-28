import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../models/anime_rating_models.dart';
import '../widgets/anime_ranked_cards.dart';
import '../l10n/anime_copy.dart';
import '../models/anime_models.dart';
import '../providers/anime_hub_social_provider.dart';
import '../providers/anime_providers.dart';
import '../widgets/anime_hub_drawer.dart';

/// Drawer "MAL Ranking" and "Pubget Rating".
///
/// [AnimeRankingSource.mal] is the Jikan/MyAnimeList top rated catalog, so it
/// reads through the paged [AnimeListProvider]. [AnimeRankingSource.pubget] is
/// the community ranking, so it reads the member-driven top rated list.
enum AnimeRankingSource { mal, pubget }

class AnimeRatingsPage extends StatefulWidget {
  const AnimeRatingsPage({this.source = AnimeRankingSource.pubget, super.key});

  final AnimeRankingSource source;

  @override
  State<AnimeRatingsPage> createState() => _AnimeRatingsPageState();
}

class _AnimeRatingsPageState extends State<AnimeRatingsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    if (!mounted) return;
    if (widget.source == AnimeRankingSource.mal) {
      context.read<AnimeListProvider>().openCatalog(AnimeCatalogKind.top);
      return;
    }
    final social = maybeAnimeHubSocial(context, listen: false);
    social?.loadTopRated();
  }

  @override
  Widget build(BuildContext context) {
    return widget.source == AnimeRankingSource.mal
        ? _MalRankingBody(onRetry: _load)
        : _PubgetRankingBody(onRetry: _load);
  }
}

class _PubgetRankingBody extends StatelessWidget {
  const _PubgetRankingBody({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final social = maybeAnimeHubSocial(context);
    final copy = AnimeCopy.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(copy.communityRankingTitle),
      ),
      drawer: AnimeHubDrawer(current: '/anime/ratings/pubget'),
      body: PubgetLoadingStateView(
        state: social?.topState ?? LoadingState.empty,
        onRetry: onRetry,
        empty: PubgetEmptyState(
          title: copy.noRatingsYet,
          icon: Icons.star_outline,
        ),
        error: PubgetErrorState(
          title: copy.unableToLoad,
          message: social?.topFailure?.message ?? copy.checkConnection,
          onRetry: onRetry,
        ),
        child: AnimeCommunityRankedList(
          items: social?.topRated ?? const <AnimeCommunityStats>[],
        ),
      ),
    );
  }
}

/// MAL ranking: the Jikan top rated catalog, paginated like every other
/// catalog page, with the same skeleton, empty, error and offline states.
class _MalRankingBody extends StatelessWidget {
  const _MalRankingBody({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final list = context.watch<AnimeListProvider>();
    final copy = AnimeCopy.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(copy.malRankingTitle),
      ),
      drawer: AnimeHubDrawer(current: '/anime/ratings'),
      body: PubgetLoadingStateView(
        state:
            list.state == LoadingState.loadingMore ||
                list.state == LoadingState.refreshing
            ? LoadingState.loaded
            : list.state,
        onRetry: onRetry,
        empty: PubgetEmptyState(
          title: copy.emptyCatalog,
          message: copy.nothingFoundMessage,
          icon: Icons.emoji_events_outlined,
        ),
        error: PubgetErrorState(
          title: copy.unableToLoad,
          message: list.failure?.message ?? copy.checkConnection,
          onRetry: onRetry,
          retryLabel: copy.retry,
        ),
        offline: PubgetOfflineState(
          message: copy.offlineCached,
          onRetry: onRetry,
        ),
        child: AnimeRankedPaginatedGrid(list: list),
      ),
    );
  }
}
