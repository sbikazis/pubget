import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../l10n/anime_copy.dart';
import '../models/anime_models.dart';
import '../providers/anime_providers.dart';
import '../widgets/anime_widgets.dart';

class AnimeBrowsePage extends StatefulWidget {
  const AnimeBrowsePage({
    this.kind,
    this.genreId,
    this.genreName,
    this.year,
    this.season,
    super.key,
  });

  final AnimeCatalogKind? kind;
  final String? genreId;
  final String? genreName;
  final int? year;
  final AnimeSeason? season;

  @override
  State<AnimeBrowsePage> createState() => _AnimeBrowsePageState();
}

class _AnimeBrowsePageState extends State<AnimeBrowsePage> {
  @override
  void initState() {
    super.initState();
    final list = context.read<AnimeListProvider>();
    Future<void>.microtask(() => _open(list));
  }

  Future<void> _open(AnimeListProvider list) {
    if (widget.genreId != null && widget.genreId!.isNotEmpty) {
      return list.openGenre(
        AnimeGenre(
          id: widget.genreId!,
          name: widget.genreName ?? 'Genre',
        ),
      );
    }
    if (widget.year != null && widget.season != null) {
      return list.openSeason(year: widget.year!, season: widget.season!);
    }
    return list.openCatalog(widget.kind ?? AnimeCatalogKind.trending);
  }

  @override
  Widget build(BuildContext context) {
    final list = context.watch<AnimeListProvider>();
    final copy = AnimeCopy.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(copy.pageTitle(list.title)),
      ),
      body: PubgetLoadingStateView(
        state: list.state == LoadingState.loadingMore ||
                list.state == LoadingState.refreshing
            ? LoadingState.loaded
            : list.state,
        onRetry: list.retry,
        empty: PubgetEmptyState(
          title: copy.emptyCatalog,
          message: copy.nothingFoundMessage,
          icon: Icons.movie_filter_outlined,
        ),
        error: PubgetErrorState(
          title: copy.unableToLoad,
          message: list.failure?.message ?? copy.checkConnection,
          onRetry: list.retry,
          retryLabel: copy.retry,
        ),
        offline: PubgetOfflineState(
          message: copy.checkConnection,
          onRetry: list.retry,
        ),
        child: AnimePaginatedList(list: list),
      ),
    );
  }
}
