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

class AnimeCustomListPage extends StatefulWidget {
  const AnimeCustomListPage({
    required this.listId,
    this.list,
    this.userId,
    this.own = true,
    super.key,
  });

  final String listId;
  final AnimeCustomList? list;
  final String? userId;
  final bool own;

  @override
  State<AnimeCustomListPage> createState() => _AnimeCustomListPageState();
}

class _AnimeCustomListPageState extends State<AnimeCustomListPage> {
  @override
  void initState() {
    super.initState();
    final library = context.read<AnimeLibraryProvider>();
    Future<void>.microtask(
      () => library.loadCustomList(
        widget.listId,
        userId: widget.userId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<AnimeLibraryProvider>();
    final detail = library.customListDetail(widget.listId);
    final list = detail?.list ?? widget.list;
    final items = detail?.items ?? const <AnimeCustomListItem>[];
    final title =
        list?.name ?? AnimeCopy.of(context).customList;
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(title),
        actions: <Widget>[
          if (widget.own && list != null) _EditMenu(list: list),
        ],
      ),
      body: PubgetLoadingStateView(
        state: detail == null ? LoadingState.loading : LoadingState.loaded,
        empty: PubgetEmptyState(
          title: AnimeCopy.of(context).emptyCatalog,
          message: AnimeCopy.of(context).libraryEmptyMessage,
          icon: Icons.list,
        ),
        child: ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final item = items[index];
            return PubgetCard(
              onTap: () => AnimeLinks.openDetails(context, item.animeId),
              child: ListTile(
                title: Text(
                  item.title.isEmpty
                      ? 'Anime ${item.animeId}'
                      : item.title,
                ),
                subtitle: Text(item.animeId),
                trailing: widget.own
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: library.saving
                            ? null
                            : () => library.removeFromCustomList(
                                listId: widget.listId,
                                animeId: item.animeId,
                              ),
                      )
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EditMenu extends StatelessWidget {
  const _EditMenu({required this.list});

  final AnimeCustomList list;

  @override
  Widget build(BuildContext context) {
    final copy = AnimeCopy.of(context);
    final library = context.read<AnimeLibraryProvider>();
    return PopupMenuButton<_MenuAction>(
      onSelected: (action) async {
        if (_MenuAction.rename == action) {
          await _showEditSheet(
            context,
            copy,
            library,
            list,
            field: _EditableField.name,
          );
        } else if (_MenuAction.editDescription == action) {
          await _showEditSheet(
            context,
            copy,
            library,
            list,
            field: _EditableField.description,
          );
        } else if (_MenuAction.togglePrivacy == action) {
          await library.updateCustomList(
            listId: list.id,
            private: !list.private,
          );
        } else if (_MenuAction.delete == action) {
          final confirm = await PubgetConfirmationDialog.show(
            context,
            title: copy.deleteList,
            message: 'Are you sure?',
            confirmLabel: copy.delete,
          );
          if (confirm == true && context.mounted) {
            await library.removeCustomList(list.id);
            if (context.mounted) Navigator.of(context).pop();
          }
        }
      },
      itemBuilder: (_) => <PopupMenuEntry<_MenuAction>>[
        PopupMenuItem<_MenuAction>(
          value: _MenuAction.rename,
          child: Text(copy.editList),
        ),
        PopupMenuItem<_MenuAction>(
          value: _MenuAction.editDescription,
          child: Text(copy.customListDescription),
        ),
        PopupMenuItem<_MenuAction>(
          value: _MenuAction.togglePrivacy,
          child: Text(
            list.private
                ? 'Make public'
                : copy.privateList,
          ),
        ),
        PopupMenuItem<_MenuAction>(
          value: _MenuAction.delete,
          child: Text(copy.deleteList),
        ),
      ],
    );
  }
}

enum _MenuAction { rename, editDescription, togglePrivacy, delete }

enum _EditableField { name, description }

Future<void> _showEditSheet(
  BuildContext context,
  AnimeCopy copy,
  AnimeLibraryProvider library,
  AnimeCustomList list, {
  required _EditableField field,
}) async {
  final isName = field == _EditableField.name;
  final controller = TextEditingController(
    text: isName ? list.name : list.description,
  );
  var error = '';
  await PubgetBottomSheet.show<void>(
    context,
    isScrollControlled: true,
    title: isName ? copy.editList : copy.customListDescription,
    child: StatefulBuilder(
      builder: (context, setSheetState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            PubgetTextField(
              controller: controller,
              label: isName ? copy.customListName : copy.customListDescription,
              maxLines: isName ? 1 : 3,
              onChanged: (_) {
                if (error.isNotEmpty) setSheetState(() => error = '');
              },
            ),
            if (error.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(error, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: AppSpacing.lg),
            PubgetPrimaryButton(
              semanticLabel: copy.createList,
              onPressed: () async {
                final value = controller.text.trim();
                if (isName && value.isEmpty) {
                  setSheetState(() => error = copy.listNameRequired);
                  return;
                }
                await library.updateCustomList(
                  listId: list.id,
                  name: isName ? value : null,
                  description: isName ? null : value,
                );
                if (context.mounted) Navigator.of(context).pop();
              },
              child: Text(copy.createList),
            ),
          ],
        );
      },
    ),
  );
}
