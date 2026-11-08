import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../../app/app_router.dart';
import '../../../core/links/pubget_links.dart';

import '../data/kirari_repository.dart';
import '../data/kirari_video_cache.dart';
import '../l10n/kirari_copy.dart';
import 'kirari_upload_page.dart';
import 'kirari_saved_page.dart';

class KirariFeedPage extends StatefulWidget {
  const KirariFeedPage({super.key});

  @override
  State<KirariFeedPage> createState() => _KirariFeedPageState();
}

class _KirariFeedPageState extends State<KirariFeedPage>
    with WidgetsBindingObserver {
  static const _feedTypes = <String, String>{
    'For You': 'forYou',
    'Following': 'following',
    'Trending': 'trending',
  };

  late KirariRepository _repository;
  final KirariVideoCache _videoCache = KirariVideoCache();
  String _feedType = 'forYou';
  final List<KirariReel> _items = <KirariReel>[];
  VideoPlayerController? _controller;
  VideoPlayerController? _prefetchController;
  int? _prefetchIndex;
  KirariPlaybackReporter? _reporter;
  static double? _measuredMbps;
  static DateTime? _measuredAt;
  Timer? _reportTimer;
  int _activeIndex = 0;
  int _activationGeneration = 0;
  int _feedGeneration = 0;
  bool _resumeAfterLifecycle = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  Map<String, dynamic>? _cursor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repository = context.read<KirariRepository>();
    if (_items.isEmpty && _loading) {
      unawaited(_load(reset: true));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _reportTimer?.cancel();
      final controller = _controller;
      _resumeAfterLifecycle = controller?.value.isPlaying == true;
      if (_resumeAfterLifecycle) unawaited(controller!.pause());
    } else if (state == AppLifecycleState.resumed && _resumeAfterLifecycle) {
      _resumeAfterLifecycle = false;
      final controller = _controller;
      if (controller != null && controller.value.isInitialized) {
        unawaited(controller.play());
        _startReporter();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _activationGeneration++;
    _feedGeneration++;
    _reportTimer?.cancel();
    final controller = _controller;
    _controller = null;
    if (controller != null) unawaited(controller.dispose());
    final prefetch = _prefetchController;
    _prefetchController = null;
    if (prefetch != null) unawaited(prefetch.dispose());
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    if (!reset && (_loadingMore || !_hasMore)) return;
    if (reset) _feedGeneration++;
    final generation = _feedGeneration;
    setState(() {
      if (reset) {
        _loading = true;
        _error = null;
        _items.clear();
        _cursor = null;
        _hasMore = true;
        _activeIndex = 0;
      } else {
        _loadingMore = true;
      }
    });
    try {
      final page = await _repository.getFeed(
        type: _feedType,
        cursor: reset ? null : _cursor,
      );
      if (!mounted || generation != _feedGeneration) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _loading = false;
        _loadingMore = false;
      });
      if (reset && _items.isNotEmpty) {
        await _activate(_activeIndex);
      } else if (_items.isNotEmpty) {
        unawaited(_prefetchNext(_activeIndex + 1));
      }
    } catch (error) {
      if (!mounted || generation != _feedGeneration) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = KirariCopy.of(context).loadError;
      });
    }
  }

  Future<int> _adaptiveQuality(KirariReel reel) async {
    if (_measuredMbps == null || _measuredAt == null ||
        DateTime.now().difference(_measuredAt!) > const Duration(minutes: 5)) {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      final watch = Stopwatch()..start();
      try {
        final request = await client.getUrl(Uri.parse(reel.videoUrl))
            .timeout(const Duration(seconds: 4));
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-131071');
        final response = await request.close().timeout(const Duration(seconds: 5));
        var bytes = 0;
        await for (final chunk in response.timeout(const Duration(seconds: 5))) {
          bytes += chunk.length;
          if (bytes >= 131072) break;
        }
        watch.stop();
        _measuredMbps = response.statusCode == HttpStatus.partialContent && watch.elapsedMilliseconds > 0
            ? (bytes * 8 / (watch.elapsedMilliseconds / 1000)) / 1000000
            : 1.8;
        _measuredAt = DateTime.now();
      } catch (_) {
        _measuredMbps = 1.8;
        _measuredAt = DateTime.now();
      } finally {
        client.close(force: true);
      }
    }
    final speed = _measuredMbps ?? 1.8;
    if (speed < 1.5) return 360;
    if (speed > 5.0) return 720;
    return 540;
  }

  Future<VideoPlayerController> _makeController(KirariReel reel) async {
    Object? lastError;

    // Try durable local renditions before touching the network. This allows
    // previously cached videos to play in airplane mode or during outages.
    for (final quality in const <int>[540, 360, 720]) {
      VideoPlayerController? controller;
      try {
        final cached = await _videoCache.getCached(reelId: reel.id, quality: quality);
        if (cached == null) continue;
        controller = VideoPlayerController.file(cached);
        await controller.initialize().timeout(const Duration(seconds: 20));
        return controller;
      } catch (error) {
        lastError = error;
        if (controller != null) await controller.dispose();
      }
    }

    final preferred = await _adaptiveQuality(reel);
    final qualities = <int>{preferred, 540, 360, 720};
    final attemptedUrls = <String>{};
    for (final quality in qualities) {
      VideoPlayerController? controller;
      try {
        final cached = await _videoCache.getCached(reelId: reel.id, quality: quality);
        if (cached != null) {
          controller = VideoPlayerController.file(cached);
        } else {
          final url = await _repository.getPlaybackUrl(reel, quality: quality);
          if (url.isEmpty || !attemptedUrls.add(url)) continue;
          controller = VideoPlayerController.networkUrl(Uri.parse(url));
        }
        await controller.initialize().timeout(const Duration(seconds: 20));
        return controller;
      } catch (error) {
        lastError = error;
        if (controller != null) await controller.dispose();
      }
    }

    throw StateError('Kirari playback failed for all available renditions: $lastError');
  }

  Future<VideoPlayerController> _makeCachedController(KirariReel reel) {
    // Initialize the next controller from a cached file when available, or
    // directly from the adaptive network rendition. Never download an entire
    // next video before allowing the user to swipe to it.
    return _makeController(reel);
  }

  Future<void> _prefetchNext(int index) async {
    if (index < 0 || index >= _items.length ||
        _prefetchController != null || index != _activeIndex + 1) return;
    final reel = _items[index];
    VideoPlayerController? controller;
    try {
      controller = await _makeCachedController(reel);
      await controller.setLooping(true);
      await controller.pause();
      if (!mounted || index != _activeIndex + 1 ||
          _items[index].id != reel.id) {
        await controller.dispose();
        return;
      }
      _prefetchController = controller;
      _prefetchIndex = index;
    } catch (_) {
      if (controller != null) await controller.dispose();
      // Prefetch is opportunistic; the active item still has its own retry path.
    }
  }

  Future<void> _activate(int index) async {
    if (index < 0 || index >= _items.length) return;
    final generation = ++_activationGeneration;
    _reportTimer?.cancel();
    final previous = _controller;
    _controller = null;
    _reporter = null;
    if (previous != null) await previous.dispose();
    if (!mounted || generation != _activationGeneration) return;
    VideoPlayerController? controller;
    if (_prefetchIndex == index) {
      controller = _prefetchController;
      _prefetchController = null;
      _prefetchIndex = null;
    } else {
      final unused = _prefetchController;
      _prefetchController = null;
      _prefetchIndex = null;
      if (unused != null) await unused.dispose();
    }
    final reel = _items[index];
    try {
      controller ??= await _makeController(reel);
      if (!mounted || generation != _activationGeneration) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      setState(() => _activeIndex = index);
      if (!controller.value.isInitialized) {
        await controller.initialize().timeout(const Duration(seconds: 20));
      }
      if (!mounted || generation != _activationGeneration ||
          !identical(_controller, controller)) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(true);
      await controller.play();
      _cacheActiveReel(reel);
      final reporter = KirariPlaybackReporter(_repository, reel.id);
      try {
        await reporter.start();
        if (mounted && identical(_controller, controller)) {
          _reporter = reporter;
          _startReporter();
        }
      } catch (_) {
        // Playback must remain available when analytics is temporarily offline.
      }
      if (!mounted || generation != _activationGeneration ||
          !identical(_controller, controller)) {
        await controller.dispose();
        return;
      }
      setState(() {});
      unawaited(_prefetchNext(index + 1));
    } catch (_) {
      if (mounted && generation == _activationGeneration &&
          identical(_controller, controller)) {
        setState(() => _error = KirariCopy.of(context).playbackError);
      }
      if (controller != null) await controller.dispose();
    }
  }

  void _cacheActiveReel(KirariReel reel) {
    // Cache the active rendition in the background after playback has started.
    // Playback remains network-first so a slow download never blocks the
    // first frame on weak mobile connections.
    unawaited(() async {
      final quality = await _adaptiveQuality(reel);
      // Do not compete with active playback on a weak connection. Disk
      // caching is opportunistic and reserved for fast, stable links.
      if ((_measuredMbps ?? 0) < 5.0) return;
      final cached = await _videoCache.getCached(reelId: reel.id, quality: quality);
      if (cached != null) return;
      final url = await _repository.getPlaybackUrl(reel, quality: quality);
      if (url.isEmpty) return;
      await _videoCache.getOrDownload(
        reelId: reel.id,
        quality: quality,
        source: Uri.parse(url),
      );
    }().catchError((Object _) {
      // Cache is opportunistic; it must never interrupt active playback.
    }));
  }

  void _startReporter() {
    _reportTimer?.cancel();
    _reportTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final controller = _controller;
      final reporter = _reporter;
      if (controller != null && reporter != null) {
        unawaited(reporter.report(controller));
      }
    });
  }

  Future<void> _switchFeed(String type) async {
    if (_feedType == type) return;
    _feedType = type;
    final current = _controller;
    _controller = null;
    _reporter = null;
    _reportTimer?.cancel();
    if (current != null) await current.dispose();
    final prefetch = _prefetchController;
    _prefetchController = null;
    _prefetchIndex = null;
    if (prefetch != null) await prefetch.dispose();
    if (!mounted) return;
    await _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final copy = KirariCopy.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(copy.title),
        actions: [
          IconButton(
            tooltip: 'Saved videos',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const KirariSavedPage(),
              ),
            ),
            icon: const Icon(Icons.bookmarks_outlined),
          ),
          IconButton(
            tooltip: copy.create,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const KirariUploadPage(),
              ),
            ),
            icon: const Icon(Icons.add_box_outlined),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(42),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _feedTypes.entries.map((entry) {
              final selected = _feedType == entry.value;
              return TextButton(
                onPressed: () => _switchFeed(entry.value),
                child: Text(
                  switch (entry.value) {
                    'forYou' => copy.forYou,
                    'following' => copy.following,
                    _ => copy.trending,
                  },
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white60,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
      body: _body(),
    );
  }

  Future<void> _runAction(
    String reelId,
    String kind, {
    int? index,
  }) async {
    KirariReel? previous;
    var actionKind = kind;
    if (index != null && index >= 0 && index < _items.length) {
      previous = _items[index];
      if (kind == 'like' || kind == 'unlike') {
        actionKind = previous.viewerLiked ? 'unlike' : 'like';
        _items[index] = previous.copyWith(
          viewerLiked: !previous.viewerLiked,
          likesCount: previous.viewerLiked
              ? (previous.likesCount > 0 ? previous.likesCount - 1 : 0)
              : previous.likesCount + 1,
        );
      } else if (kind == 'save' || kind == 'unsave') {
        actionKind = previous.viewerSaved ? 'unsave' : 'save';
        _items[index] = previous.copyWith(
          viewerSaved: !previous.viewerSaved,
        );
      }
      if (mounted) setState(() {});
    }
    try {
      await _repository.action(reelId, actionKind);
    } catch (_) {
      if (!mounted) return;
      if (previous != null && index != null && index < _items.length) {
        setState(() => _items[index] = previous!);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(KirariCopy.of(context).actionError)),
      );
    }
  }

  Future<void> _giveRespect(String creatorId) async {
    var value = 5.0;
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Give Respect'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value.round().toString(), style: Theme.of(context).textTheme.headlineMedium),
              Slider(
                min: 0, max: 7, divisions: 7, value: value,
                onChanged: (next) => update(() => value = next),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, value.round()), child: const Text('Give')),
          ],
        ),
      ),
    );
    if (selected == null) return;
    try {
      await _repository.giveCreatorRespect(creatorId: creatorId, value: selected);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(KirariCopy.of(context).actionError)),
      );
    }
  }

  Widget _body() {
    final copy = KirariCopy.of(context);
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _load(reset: true),
              child: Text(KirariCopy.of(context).retry),
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(child: Text(KirariCopy.of(context).noVideos, style: const TextStyle(color: Colors.white)));
    }
    return PageView.builder(
      key: ValueKey(_feedType),
      scrollDirection: Axis.vertical,
      itemCount: _items.length + (_loadingMore ? 1 : 0),
      onPageChanged: (index) {
        if (index >= _items.length - 2 && _hasMore) {
          unawaited(_load(reset: false));
        }
        if (index < _items.length) unawaited(_activate(index));
      },
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return const Center(child: CircularProgressIndicator());
        }
        final reel = _items[index];
        final active = index == _activeIndex;
        final controller = active ? _controller : null;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (reel.coverUrl.isNotEmpty)
              Image.network(reel.coverUrl, fit: BoxFit.cover)
            else
              const ColoredBox(color: Color(0xFF17131F)),
            if (controller?.value.isInitialized == true)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller!.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            Positioned(
              left: 18,
              right: 84,
              bottom: 30,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => AppNavigation.go(context, PubgetLinks.profilePath(reel.creatorId)),
                    child: Text(
                      '@${reel.creatorUsername.isNotEmpty ? reel.creatorUsername : reel.creatorId}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(reel.caption,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 15)),
                ],
              ),
            ),
            Positioned(
              right: 12,
              bottom: 42,
              child: Column(
                children: [
                  IconButton(
                    color: reel.viewerLiked ? Colors.redAccent : Colors.white,
                    onPressed: () => _runAction(reel.id, 'like', index: index),
                    icon: Icon(
                      reel.viewerLiked ? Icons.favorite : Icons.favorite_border,
                      size: 30,
                    ),
                  ),
                  Text('${reel.likesCount}', style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 16),
                  IconButton(
                    color: reel.viewerSaved ? Colors.amber : Colors.white,
                    onPressed: () => _runAction(reel.id, 'save', index: index),
                    icon: Icon(
                      reel.viewerSaved ? Icons.bookmark : Icons.bookmark_border,
                      size: 28,
                    ),
                  ),
                  Text(
                    reel.viewerSaved ? 'Saved' : copy.save,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  IconButton(
                    color: Colors.white,
                    tooltip: copy.comments,
                    onPressed: () => showModalBottomSheet<void>(
                      context: context, isScrollControlled: true,
                      builder: (_) => KirariCommentsSheet(reel: reel, repository: _repository),
                    ),
                    icon: const Icon(Icons.mode_comment_outlined, size: 26),
                  ),
                  Text('${reel.commentsCount}', style: const TextStyle(color: Colors.white)),
                  IconButton(
                    color: Colors.white,
                    tooltip: 'Respect',
                    onPressed: () => _giveRespect(reel.creatorId),
                    icon: const Icon(Icons.volunteer_activism_outlined, size: 26),
                  ),
                  PopupMenuButton<String>(
                    iconColor: Colors.white,
                    onSelected: (value) async {
                      if (value == 'mute') {
                        await _repository.setCreatorMute(creatorId: reel.creatorId, muted: true);
                      } else {
                        await _runAction(reel.id, value);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'not_interested', child: Text(copy.notInterested)),
                      PopupMenuItem(value: 'mute', child: Text(copy.muteCreator)),
                      PopupMenuItem(value: 'report', child: Text(copy.report)),
                    ],
                  ),
                  if (reel.audioId != null && reel.audioId!.isNotEmpty)
                    IconButton(
                      color: Colors.white,
                      tooltip: copy.audioLibrary,
                      onPressed: () => AppNavigation.go(context, PubgetLinks.audioPath(reel.audioId!)),
                      icon: const Icon(Icons.music_note, size: 26),
                    ),
                ],
              ),
            ),
            if (active && (controller == null || !controller.value.isInitialized))
              const Center(child: CircularProgressIndicator()),
          ],
        );
      },
    );
  }
}

class KirariCommentsSheet extends StatefulWidget {
  const KirariCommentsSheet({required this.reel, required this.repository, super.key});
  final KirariReel reel;
  final KirariRepository repository;

  @override
  State<KirariCommentsSheet> createState() => _KirariCommentsSheetState();
}

class _KirariCommentsSheetState extends State<KirariCommentsSheet> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _comments = const [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  String? _replyToId;
  String? _replyToAuthor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final comments = await widget.repository.getComments(widget.reel.id);
      if (mounted) setState(() { _comments = comments; _loading = false; _error = null; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Could not load comments.'; });
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.repository.addComment(widget.reel.id, text, parentId: _replyToId);
      _controller.clear();
      if (mounted) setState(() { _replyToId = null; _replyToAuthor = null; });
      await _load();
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not send comment. Please retry.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = KirariCopy.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(child: Text(copy.comments, style: Theme.of(context).textTheme.titleLarge)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ]),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _comments.isEmpty
                        ? const Center(child: Text('No comments yet.'))
                        : ListView.builder(
                            itemCount: _comments.length,
                            itemBuilder: (context, index) {
                              final item = _comments[index];
                              final deleted = item['status'] == 'deleted';
                              final commentId = item['id'] as String? ?? '';
                              final authorId = item['authorId'] as String? ?? '';
                              return ListTile(
                                title: Text(deleted ? 'Comment removed' : item['text'] as String? ?? ''),
                                subtitle: Text('@' + authorId),
                                onTap: deleted || authorId.isEmpty
                                    ? null
                                    : () => AppNavigation.go(
                                          context,
                                          PubgetLinks.profilePath(authorId),
                                        ),
                                trailing: deleted ? null : Wrap(
                                  children: [
                                    IconButton(
                                      tooltip: item['viewerLiked'] == true
                                          ? 'Unlike comment'
                                          : 'Like comment',
                                      color: item['viewerLiked'] == true
                                          ? Colors.redAccent
                                          : null,
                                      icon: Icon(
                                        item['viewerLiked'] == true
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        size: 19,
                                      ),
                                      onPressed: () async {
                                        await widget.repository.commentAction(
                                          widget.reel.id,
                                          commentId,
                                          item['viewerLiked'] == true
                                              ? 'unlike'
                                              : 'like',
                                        );
                                        await _load();
                                      },
                                    ),
                                    Text((item['likesCount'] ?? 0).toString()),
                                    IconButton(
                                      tooltip: 'Reply',
                                      icon: const Icon(Icons.reply, size: 19),
                                      onPressed: () => setState(() { _replyToId = commentId; _replyToAuthor = authorId; }),
                                    ),
                                    PopupMenuButton<String>(
                                      onSelected: (kind) async {
                                        await widget.repository.commentAction(widget.reel.id, commentId, kind);
                                        await _load();
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(value: 'report', child: Text('Report comment')),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
              if (_error != null) Padding(padding: const EdgeInsets.all(8), child: Text(_error!)),
              if (_replyToId != null)
                ListTile(
                  dense: true,
                  title: Text('Replying to @' + (_replyToAuthor ?? '')),
                  trailing: IconButton(
                    onPressed: () => setState(() { _replyToId = null; _replyToAuthor = null; }),
                    icon: const Icon(Icons.close),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(children: [
                  Expanded(child: TextField(
                    controller: _controller,
                    maxLength: 500,
                    decoration: InputDecoration(hintText: copy.addComment, counterText: ''),
                  )),
                  IconButton(onPressed: _sending ? null : _send, icon: _sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send)),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
