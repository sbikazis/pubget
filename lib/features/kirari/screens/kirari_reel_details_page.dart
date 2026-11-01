import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../../app/app_back_button.dart';
import '../../../app/app_router.dart';
import '../../../core/links/pubget_links.dart';
import '../data/kirari_repository.dart';
import '../l10n/kirari_copy.dart';
import 'kirari_feed_page.dart';

class KirariReelDetailsPage extends StatefulWidget {
  const KirariReelDetailsPage({required this.reelId, super.key});
  final String reelId;

  @override
  State<KirariReelDetailsPage> createState() => _KirariReelDetailsPageState();
}

class _KirariReelDetailsPageState extends State<KirariReelDetailsPage> {
  KirariReel? _reel;
  VideoPlayerController? _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final reel = await context.read<KirariRepository>().getReel(widget.reelId);
      final controller = VideoPlayerController.networkUrl(Uri.parse(reel.videoUrl));
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _reel = reel;
        _controller = controller;
        _loading = false;
        _error = null;
      });
      await controller.play();
    } catch (error) {
      if (!mounted) return;
      final copy = KirariCopy.of(context);
      final unavailable = error is FirebaseFunctionsException &&
          error.code == 'not-found';
      setState(() {
        _loading = false;
        _error = unavailable ? copy.reelUnavailable : copy.loadError;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = KirariCopy.of(context);
    final reel = _reel;
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(
        title: Text(copy.title),
        leading: AppBackButton.maybeOf(context),
        actions: [
          IconButton(
            tooltip: 'Share',
            onPressed: reel == null ? null : () => PubgetLinks.share(
              context, url: PubgetLinks.reel(reel.id), title: 'Kirari video', type: 'kirari',
            ),
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : reel == null
              ? Center(child: Text(_error ?? copy.loadError))
              : ListView(
                  padding: const EdgeInsets.only(bottom: 28),
                  children: [
                    AspectRatio(
                      aspectRatio: 9 / 16,
                      child: GestureDetector(
                        onTap: () {
                          if (controller == null) return;
                          setState(() {
                            if (controller.value.isPlaying) {
                              controller.pause();
                            } else {
                              controller.play();
                            }
                          });
                        },
                        child: ColoredBox(
                          color: Colors.black,
                          child: Stack(fit: StackFit.expand, children: [
                            if (reel.coverUrl.isNotEmpty)
                              Image.network(reel.coverUrl, fit: BoxFit.cover),
                            if (controller?.value.isInitialized == true)
                              FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: controller!.value.size.width,
                                  height: controller.value.size.height,
                                  child: VideoPlayer(controller),
                                ),
                              ),
                            if (controller == null || !controller.value.isPlaying)
                              const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 58)),
                          ]),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () => AppNavigation.go(context, PubgetLinks.profilePath(reel.creatorId)),
                            child: Row(children: [
                              const CircleAvatar(child: Icon(Icons.person_outline)),
                              const SizedBox(width: 10),
                              Expanded(child: Text('@${reel.creatorId}', style: Theme.of(context).textTheme.titleMedium)),
                            ]),
                          ),
                          if (reel.caption.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text(reel.caption, style: Theme.of(context).textTheme.bodyLarge),
                          ],
                          if (reel.audioId != null) ...[
                            const SizedBox(height: 12),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.music_note),
                              title: Text(reel.audioAttribution['title'] as String? ?? 'Original audio'),
                              subtitle: Text([
                                reel.audioAttribution['artist'] as String? ?? '',
                                reel.audioAttribution['license'] as String? ?? '',
                                reel.audioAttribution['attribution'] as String? ?? '',
                              ].where((value) => value.isNotEmpty).join(' · ')),
                              onTap: () => AppNavigation.go(context, PubgetLinks.audioPath(reel.audioId!)),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Wrap(spacing: 8, children: [
                            OutlinedButton.icon(
                              onPressed: () => context.read<KirariRepository>().action(reel.id, 'like'),
                              icon: const Icon(Icons.favorite_border), label: Text('${reel.likesCount}'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => showModalBottomSheet<void>(
                                context: context, isScrollControlled: true,
                                builder: (_) => KirariCommentsSheet(reel: reel, repository: context.read<KirariRepository>()),
                              ),
                              icon: const Icon(Icons.mode_comment_outlined), label: Text('${reel.commentsCount}'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => context.read<KirariRepository>().action(reel.id, 'save'),
                              icon: const Icon(Icons.bookmark_border), label: Text(copy.save),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
