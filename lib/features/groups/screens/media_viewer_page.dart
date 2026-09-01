import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/widgets/pubget_design_system.dart';
import '../models/chat_models.dart';
import '../services/storage_video_controller.dart';

class MediaViewerPage extends StatefulWidget {
  const MediaViewerPage({
    required this.messages,
    required this.initialIndex,
    super.key,
  });

  final List<ChatMessage> messages;
  final int initialIndex;

  @override
  State<MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends State<MediaViewerPage> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: widget.initialIndex < 0 ? 0 : widget.initialIndex,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Group media'),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.messages.length,
        itemBuilder: (context, index) {
          final message = widget.messages[index];
          if (message.type == ChatMessageType.video &&
              message.mediaUrl != null) {
            return _VideoViewer(url: message.mediaUrl!);
          }
          return InteractiveViewer(
            minScale: 0.8,
            maxScale: 5,
            child: Center(
              child: AppImageLoader(
                imageUrl: message.mediaUrl ?? '',
                fit: BoxFit.contain,
                errorWidget: const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white,
                  size: 64,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VideoViewer extends StatefulWidget {
  const _VideoViewer({required this.url});

  final String url;

  @override
  State<_VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<_VideoViewer> {
  late final VideoPlayerController _controller;
  late final Future<void> _initialization;
  bool _controllerReady = false;

  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    _controller = await createStorageVideoController(widget.url);
    await _controller.initialize();
    _controllerReady = true;
  }

  @override
  void dispose() {
    if (_controllerReady) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return GestureDetector(
          onTap: () {
            setState(() {
              _controller.value.isPlaying
                  ? _controller.pause()
                  : _controller.play();
            });
          },
          child: Center(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  VideoPlayer(_controller),
                  if (!_controller.value.isPlaying)
                    const Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 72,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
