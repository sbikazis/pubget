import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../data/kirari_repository.dart';
import '../l10n/kirari_copy.dart';
import 'kirari_upload_page.dart';

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
  String _feedType = 'forYou';
  final List<KirariReel> _items = <KirariReel>[];
  VideoPlayerController? _controller;
  KirariPlaybackReporter? _reporter;
  Timer? _reportTimer;
  int _activeIndex = 0;
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
      _controller?.pause();
    } else if (state == AppLifecycleState.resumed) {
      _controller?.play();
      _startReporter();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reportTimer?.cancel();
    final controller = _controller;
    _controller = null;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    if (_loadingMore || (!reset && !_hasMore)) return;
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
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _loading = false;
        _loadingMore = false;
      });
      if (_items.isNotEmpty) await _activate(_activeIndex);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = 'Could not load Kirari. Check your connection and retry.';
      });
    }
  }

  Future<void> _activate(int index) async {
    if (index < 0 || index >= _items.length) return;
    _reportTimer?.cancel();
    final previous = _controller;
    _controller = null;
    _reporter = null;
    if (previous != null) await previous.dispose();
    if (!mounted) return;
    final reel = _items[index];
    final controller = VideoPlayerController.networkUrl(Uri.parse(reel.videoUrl));
    _controller = controller;
    setState(() => _activeIndex = index);
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
      final reporter = KirariPlaybackReporter(_repository, reel.id);
      await reporter.start();
      if (!mounted || !identical(_controller, controller)) {
        await controller.dispose();
        return;
      }
      _reporter = reporter;
      _startReporter();
      setState(() {});
    } catch (_) {
      if (identical(_controller, controller)) {
        setState(() => _error = 'This video could not be played. Swipe to continue.');
      }
      await controller.dispose();
    }
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

  Future<void> _runAction(String reelId, String kind) async {
    try {
      await _repository.action(reelId, kind);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(KirariCopy.of(context).uploadError)),
      );
    }
  }

  Widget _body() {
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
      return const Center(
        child: Text('No videos yet. Be the first to create one.',
            style: TextStyle(color: Colors.white)),
      );
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
                  Text('@${reel.creatorId}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                    color: Colors.white,
                    onPressed: () => _runAction(reel.id, 'like'),
                    icon: const Icon(Icons.favorite_border, size: 30),
                  ),
                  Text('${reel.likesCount}', style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 16),
                  IconButton(
                    color: Colors.white,
                    onPressed: () => _runAction(reel.id, 'save'),
                    icon: const Icon(Icons.bookmark_border, size: 28),
                  ),
                  const Text('Save', style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 16),
                  IconButton(
                    color: Colors.white,
                    onPressed: () => _runAction(reel.id, 'not_interested'),
                    icon: const Icon(Icons.visibility_off_outlined, size: 26),
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
