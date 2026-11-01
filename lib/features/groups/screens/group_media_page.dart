import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../../core/l10n/app_strings.dart';
import '../models/chat_models.dart';
import '../providers/chat_media_library.dart';
import '../repositories/chat_repository.dart';
import 'media_viewer_page.dart';

enum _MediaFilter { all, images, videos, gifs, stickers, audio }

class GroupMediaPage extends StatefulWidget {
  const GroupMediaPage({required this.groupId, super.key});

  final String groupId;

  @override
  State<GroupMediaPage> createState() => _GroupMediaPageState();
}

class _GroupMediaPageState extends State<GroupMediaPage> {
  _MediaFilter _filter = _MediaFilter.all;
  final _query = TextEditingController();
  final _scroll = ScrollController();
  ChatMediaLibrary? _library;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _library = ChatMediaLibrary(
      repository: context.read<ChatRepository>(),
    );
    Future.microtask(() => _library?.open(widget.groupId));
  }

  void _onScroll() {
    if (!_scroll.hasClients || _library == null) return;
    if (_scroll.position.pixels >
        _scroll.position.maxScrollExtent - 240) {
      _library!.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final library = _library;
    if (library == null) {
      return Scaffold(
        appBar: AppBar(
          leading: AppBackButton.maybeOf(context),
          title: Text(copy.groupMedia),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return ChangeNotifierProvider<ChatMediaLibrary>.value(
      value: library,
      child: Scaffold(
        appBar: AppBar(
          leading: AppBackButton.maybeOf(context),
          title: Text(copy.groupMedia),
        ),
        body: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: PubgetTextField(
                controller: _query,
                label: copy.chatMediaSearchHint,
                prefixIcon: const Icon(Icons.search),
                onChanged: (_) => setState(() {}),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: <Widget>[
                  for (final filter in _MediaFilter.values) ...[
                    PubgetSelectionChip(
                      label: _filterLabel(filter, copy),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Consumer<ChatMediaLibrary>(
                builder: (context, lib, _) {
                  final all = lib.media;
                  final filtered = all.where(_matches).toList(growable: false);
                  switch (lib.state) {
                    case ChatMediaLibraryState.loading:
                      return const Center(child: CircularProgressIndicator());
                    case ChatMediaLibraryState.error:
                      return PubgetErrorState(
                        message: copy.chatMediaLoadFailed,
                        onRetry: lib.refresh,
                      );
                    case ChatMediaLibraryState.offline:
                      return PubgetOfflineState(onRetry: lib.refresh);
                    case ChatMediaLibraryState.empty:
                    case ChatMediaLibraryState.loaded:
                    case ChatMediaLibraryState.initial:
                      if (filtered.isEmpty &&
                          lib.state == ChatMediaLibraryState.empty) {
                        return PubgetEmptyState(
                          title: copy.chatMediaEmptyTitle,
                          message: copy.chatMediaEmptyMessage,
                          icon: Icons.perm_media_outlined,
                        );
                      }
                      if (filtered.isEmpty) {
                        return PubgetEmptyState(
                          title: copy.chatMediaEmptyTitle,
                          message: copy.chatMediaEmptyMessage,
                          icon: Icons.perm_media_outlined,
                        );
                      }
                      return GridView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: AppSpacing.xs,
                          mainAxisSpacing: AppSpacing.xs,
                        ),
                        itemCount: filtered.length +
                            ((lib.hasMore && !lib.loadingMore) ? 1 : 0) +
                            (lib.loadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index < filtered.length) {
                            final message = filtered[index];
                            return InkWell(
                              onTap: message.isMedia
                                  ? () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => MediaViewerPage(
                                            messages: filtered
                                                .where((item) => item.isMedia)
                                                .toList(growable: false),
                                            initialIndex: filtered
                                                .where((item) => item.isMedia)
                                                .toList(growable: false)
                                                .indexWhere(
                                                  (item) =>
                                                      item.id == message.id,
                                                )
                                                .clamp(0, 9999),
                                          ),
                                        ),
                                      )
                                  : null,
                              child: Stack(
                                fit: StackFit.expand,
                                children: <Widget>[
                                  if (message.isMedia)
                                    AppImageLoader(
                                      imageUrl: message.thumbnailUrl ??
                                          message.mediaUrl ??
                                          '',
                                    )
                                  else
                                    ColoredBox(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      child: Icon(
                                        message.type == ChatMessageType.audio
                                            ? Icons.graphic_eq
                                            : Icons.emoji_emotions_outlined,
                                      ),
                                    ),
                                  if (message.type == ChatMessageType.video)
                                    const Align(
                                      child: Icon(
                                        Icons.play_circle_fill,
                                        color: Colors.white,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }
                          if (lib.loadingMore) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          }
                          return InkWell(
                            onTap: lib.loadMore,
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(copy.chatMediaLoadMore),
                            ),
                          );
                        },
                      );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _matches(ChatMessage message) {
    final q = _query.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      final hay =
          '${message.senderName} ${message.text ?? ''} ${message.type.name}'
              .toLowerCase();
      if (!hay.contains(q)) return false;
    }
    return switch (_filter) {
      _MediaFilter.all => true,
      _MediaFilter.images => message.type == ChatMessageType.image,
      _MediaFilter.videos => message.type == ChatMessageType.video,
      _MediaFilter.gifs => message.type == ChatMessageType.gif,
      _MediaFilter.stickers => message.type == ChatMessageType.sticker,
      _MediaFilter.audio => message.type == ChatMessageType.audio,
    };
  }

  String _filterLabel(_MediaFilter filter, AppStrings copy) => switch (filter) {
        _MediaFilter.all => copy.chatMediaFilterAll,
        _MediaFilter.images => copy.chatMediaFilterImages,
        _MediaFilter.videos => copy.chatMediaFilterVideos,
        _MediaFilter.gifs => copy.chatMediaFilterGifs,
        _MediaFilter.stickers => copy.chatMediaFilterStickers,
        _MediaFilter.audio => copy.chatMediaFilterAudio,
      };

}
