import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../l10n/anime_copy.dart';
import '../models/anime_list_models.dart';
import '../providers/anime_library_provider.dart';
import '../widgets/anime_widgets.dart';

class AnimeLibraryPage extends StatefulWidget {
  const AnimeLibraryPage({super.key});

  @override
  State<AnimeLibraryPage> createState() => _AnimeLibraryPageState();
}

class _AnimeLibraryPageState extends State<AnimeLibraryPage> {
  @override
  void initState() {
    super.initState();
    final library = context.read<AnimeLibraryProvider>();
    Future<void>.microtask(library.load);
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<AnimeLibraryProvider>();
    return DefaultTabController(
      length: AnimeListStatus.values.length,
      child: Scaffold(
        appBar: AppBar(
          leading: AppBackButton.maybeOf(context),
          title: Text(AnimeCopy.of(context).libraryTitle),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              for (final status in AnimeListStatus.values)
                Tab(text: AnimeCopy.of(context).listStatusLabel(status)),
            ],
          ),
        ),
        body: PubgetLoadingStateView(
          state: library.state == LoadingState.initial
              ? LoadingState.loading
              : library.state,
          onRetry: library.load,
          empty: PubgetEmptyState(
            title: AnimeCopy.of(context).libraryEmpty,
            message: AnimeCopy.of(context).libraryEmptyMessage,
            icon: Icons.bookmark_border,
          ),
          error: PubgetErrorState(
            title: AnimeCopy.of(context).unableToLoad,
            message:
                library.failure?.message ?? AnimeCopy.of(context).checkConnection,
            onRetry: library.load,
          ),
          offline: PubgetOfflineState(
            message: AnimeCopy.of(context).checkConnection,
            onRetry: library.load,
          ),
          child: TabBarView(
            children: [
              for (final status in AnimeListStatus.values)
                _StatusList(status: status, entries: library.byStatus(status)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusList extends StatelessWidget {
  const _StatusList({required this.status, required this.entries});

  final AnimeListStatus status;
  final List<AnimeListEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return PubgetEmptyState(
        title: AnimeCopy.of(context).libraryEmpty,
        message: 'Nothing in ${status.label.toLowerCase()} yet.',
        icon: Icons.movie_filter_outlined,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return PubgetCard(
          onTap: () => AnimeLinks.openDetails(context, entry.animeId),
          child: ListTile(
            title: Text(
              entry.title.isEmpty ? 'Anime ${entry.animeId}' : entry.title,
            ),
            subtitle: Text(
              [
                status.label,
                if (entry.rating != null) 'Rated ${entry.rating}/10',
              ].join(' · '),
            ),
            trailing: const Icon(Icons.chevron_right),
          ),
        );
      },
    );
  }
}
