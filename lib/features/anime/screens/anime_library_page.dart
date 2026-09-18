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
import 'anime_custom_list_page.dart';

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
      length: AnimeListStatus.values.length + 1,
      child: Scaffold(
        appBar: AppBar(
          leading: AppBackButton.maybeOf(context),
          title: Text(AnimeCopy.of(context).libraryTitle),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              for (final status in AnimeListStatus.values)
                Tab(text: AnimeCopy.of(context).listStatusLabel(status)),
              Tab(text: AnimeCopy.of(context).customListTab),
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
                library.failure?.message ??
                AnimeCopy.of(context).checkConnection,
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
              const _CustomListsTab(),
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

class _CustomListsTab extends StatelessWidget {
  const _CustomListsTab();

  @override
  Widget build(BuildContext context) {
    final library = context.watch<AnimeLibraryProvider>();
    final lists = library.customLists;
    final copy = AnimeCopy.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        PubgetCard(
          onTap: library.saving
              ? null
              : () => _showCreateListSheet(context, library),
          child: ListTile(
            leading: const Icon(Icons.add),
            title: Text(copy.newCustomList),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (lists.isEmpty)
          PubgetEmptyState(
            title: copy.customListsEmpty,
            message: copy.customListsEmptyMessage,
            icon: Icons.playlist_add,
          )
        else
          for (final list in lists)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: PubgetCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AnimeCustomListPage(listId: list.id, list: list),
                  ),
                ),
                child: ListTile(
                  title: Text(list.name),
                  subtitle: Text(
                    [
                      copy.customListItemCount(list.itemsCount),
                      if (list.private) copy.privateList,
                    ].join(' · '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
            ),
      ],
    );
  }
}

Future<void> _showCreateListSheet(
  BuildContext context,
  AnimeLibraryProvider library,
) async {
  final copy = AnimeCopy.of(context);
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  var private = false;
  var error = '';
  await PubgetBottomSheet.show<void>(
    context,
    isScrollControlled: true,
    title: copy.newCustomList,
    child: StatefulBuilder(
      builder: (context, setSheetState) {
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              PubgetTextField(
                controller: nameController,
                label: copy.customListName,
                onChanged: (_) {
                  if (error.isNotEmpty) setSheetState(() => error = '');
                },
              ),
              if (error.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(error, style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: AppSpacing.md),
              PubgetTextField(
                controller: descriptionController,
                label: copy.customListDescription,
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.md),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(copy.privateList),
                subtitle: Text(copy.privateListHint),
                value: private,
                onChanged: (value) =>
                    setSheetState(() => private = value),
              ),
              const SizedBox(height: AppSpacing.lg),
              PubgetPrimaryButton(
                semanticLabel: copy.createList,
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    setSheetState(() => error = copy.listNameRequired);
                    return;
                  }
                  final created = await library.createCustomList(
                    name: name,
                    description: descriptionController.text.trim(),
                    private: private,
                  );
                  if (created.isSuccess && context.mounted) {
                    Navigator.of(context).pop();
                    final list = created.valueOrNull;
                    if (list?.id.isNotEmpty == true && context.mounted) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              AnimeCustomListPage(listId: list!.id, list: list),
                        ),
                      );
                    }
                  }
                },
                child: Text(copy.createList),
              ),
            ],
          ),
        );
      },
    ),
  );
}
