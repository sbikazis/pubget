import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'media_viewer_page.dart';

class GroupMediaPage extends StatelessWidget {
  const GroupMediaPage({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    final media = context
        .watch<ChatProvider>()
        .messages
        .where((message) => message.isMedia && !message.isDeleted)
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(title: const Text('Group media')),
      body: media.isEmpty
          ? const PubgetEmptyState(
              title: 'No shared media',
              message:
                  'Images and videos from the loaded chat pages appear here.',
              icon: Icons.perm_media_outlined,
            )
          : GridView.builder(
              padding: const EdgeInsets.all(AppSpacing.sm),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: AppSpacing.xs,
                mainAxisSpacing: AppSpacing.xs,
              ),
              itemCount: media.length,
              itemBuilder: (context, index) {
                final message = media[index];
                return InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          MediaViewerPage(messages: media, initialIndex: index),
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      AppImageLoader(
                        imageUrl:
                            message.thumbnailUrl ?? message.mediaUrl ?? '',
                        memCacheWidth: 320,
                        memCacheHeight: 320,
                      ),
                      if (message.type == ChatMessageType.video)
                        const Icon(Icons.play_circle_fill, color: Colors.white),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
