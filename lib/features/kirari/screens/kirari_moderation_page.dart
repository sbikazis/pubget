import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../../app/app_back_button.dart';
import '../data/kirari_repository.dart';

class KirariModerationPage extends StatefulWidget {
  const KirariModerationPage({super.key});

  @override
  State<KirariModerationPage> createState() => _KirariModerationPageState();
}

class _KirariModerationPageState extends State<KirariModerationPage> {
  late Future<List<Map<String, dynamic>>> _future;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _future = context.read<KirariRepository>().getModerationQueue();
  }

  void _reload() {
    setState(() => _future = context.read<KirariRepository>().getModerationQueue());
  }

  Future<void> _review(Map<String, dynamic> item, String decision) async {
    final id = item['id'] as String? ?? '';
    if (id.isEmpty) return;
    setState(() => _busyId = id);
    try {
      await context.read<KirariRepository>().reviewContent(
        reelId: item['reelId'] as String? ?? '',
        commentId: item['commentId'] as String?,
        decision: decision,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(decision == 'approved' ? 'Content approved.' : 'Content rejected.')),
      );
      _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review failed. Check administrator access and retry.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: const Text('Kirari moderation'),
        actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh))],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Administrator access is required to view this queue.'),
                TextButton(onPressed: _reload, child: const Text('Retry')),
              ]),
            );
          }
          final items = snapshot.data ?? const <Map<String, dynamic>>[];
          if (items.isEmpty) {
            return const Center(child: Text('The moderation queue is empty.'));
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final item = items[index];
                final id = item['id'] as String? ?? '';
                final isComment = item['contentType'] == 'comment';
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isComment ? 'Reported comment' : 'Reported video',
                          style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        Text('Reason: ' + (item['reason'] as String? ?? 'Community report')),
                        if (isComment) ...[
                          const SizedBox(height: 10),
                          Text(item['content'] as String? ?? ''),
                        ] else ...[
                          if (item['videoPreviewUrl'] is String)
                            _ModerationVideoPreview(url: item['videoPreviewUrl'] as String)
                          else if (item['coverPreviewUrl'] is String)
                            Image.network(item['coverPreviewUrl'] as String,
                              fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                          const SizedBox(height: 10),
                          Text(item['content'] as String? ?? ''),
                          Text('Creator: ' + (item['creatorId'] as String? ?? 'unknown')),
                        ],
                        const SizedBox(height: 14),
                        Row(children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _busyId == id ? null : () => _review(item, 'rejected'),
                              child: const Text('Reject'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: _busyId == id ? null : () => _review(item, 'approved'),
                              child: _busyId == id
                                  ? const SizedBox(width: 18, height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Text('Approve'),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ModerationVideoPreview extends StatefulWidget {
  const _ModerationVideoPreview({required this.url});
  final String url;

  @override
  State<_ModerationVideoPreview> createState() => _ModerationVideoPreviewState();
}

class _ModerationVideoPreviewState extends State<_ModerationVideoPreview> {
  late final VideoPlayerController _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() {});
      }).catchError((_) {
        if (mounted) setState(() => _failed = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const Center(child: Text('Preview unavailable'));
    if (!_controller.value.isInitialized) {
      return const AspectRatio(
        aspectRatio: 9 / 16,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: Stack(alignment: Alignment.center, children: [
        VideoPlayer(_controller),
        IconButton.filledTonal(
          onPressed: () => setState(() {
            _controller.value.isPlaying ? _controller.pause() : _controller.play();
          }),
          icon: Icon(_controller.value.isPlaying ? Icons.pause : Icons.play_arrow),
        ),
      ]),
    );
  }
}
