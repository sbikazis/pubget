import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../models/chat_models.dart';
import '../providers/chat_provider.dart';
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

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = context
        .watch<ChatProvider>()
        .messages
        .where(
          (message) =>
              !message.isDeleted &&
              (message.isMedia ||
                  message.type == ChatMessageType.sticker ||
                  message.type == ChatMessageType.audio),
        )
        .toList(growable: false);
    final filtered = all.where(_matches).toList(growable: false);
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: const Text('Group media'),
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
              label: 'Search media',
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
                    label: filter.name,
                    selected: _filter == filter,
                    onSelected: (_) => setState(() => _filter = filter),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const PubgetEmptyState(
                    title: 'No shared media',
                    message:
                        'Images, videos, stickers, and voice notes from chat appear here.',
                    icon: Icons.perm_media_outlined,
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: AppSpacing.xs,
                      mainAxisSpacing: AppSpacing.xs,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
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
                                            (item) => item.id == message.id,
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
                                memCacheWidth: 320,
                                memCacheHeight: 320,
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
                    },
                  ),
          ),
        ],
      ),
    );
  }

  bool _matches(ChatMessage message) {
    final q = _query.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      final hay = '${message.senderName} ${message.text ?? ''} ${message.type.name}'
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
}
