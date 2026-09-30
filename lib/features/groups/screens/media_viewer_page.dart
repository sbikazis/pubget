import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../app/app_back_button.dart';
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

  /// Only the page the user is looking at may own a decoder. Without this,
  /// swiping past a video leaves every previous one initialised and playing.
  late int _visibleIndex;

  @override
  void initState() {
    super.initState();
    _visibleIndex = widget.initialIndex < 0 ? 0 : widget.initialIndex;
    _pageController = PageController(initialPage: _visibleIndex);
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
        leading: AppBackButton.maybeOf(context),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Group media'),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.messages.length,
        onPageChanged: (index) => setState(() => _visibleIndex = index),
        itemBuilder: (context, index) {
          final message = widget.messages[index];
          if (message.type == ChatMessageType.video &&
              message.mediaUrl != null) {
            if (index != _visibleIndex) {
              // Teardown happens by leaving the tree, so this is just a poster.
              return const _VideoPlaceholder();
            }
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
  VideoPlayerController? _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  @override
  void didUpdateWidget(_VideoViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      unawaited(_open());
    }
  }

  Future<void> _open() async {
    // Release the previous decoder before opening a new one, so a url change
    // never leaves the old controller holding a handle.
    await _close();
    final controller = await createStorageVideoController(widget.url);
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() => _controller = controller);
    try {
      await controller.initialize();
    } catch (error) {
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _error = error;
        _controller = null;
      });
      await controller.dispose();
      return;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    // The widget may have been replaced while the decoder was starting.
    if (!identical(_controller, controller)) {
      await controller.dispose();
      return;
    }
    setState(() {});
  }

  Future<void> _close() async {
    final controller = _controller;
    _controller = null;
    _error = null;
    await controller?.dispose();
  }

  @override
  void dispose() {
    // Fire and forget: dispose() must not be async, and nothing may be set.
    unawaited(_controller?.dispose());
    _controller = null;
    super.dispose();
  }

  void _toggle() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    setState(() {
      controller.value.isPlaying ? controller.pause() : controller.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_error != null) {
      return const _VideoMessage(
        icon: Icons.videocam_off_outlined,
        label: 'This video could not be played.',
      );
    }
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return GestureDetector(
      onTap: _toggle,
      child: Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              VideoPlayer(controller),
              if (!controller.value.isPlaying)
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
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder();

  @override
  Widget build(BuildContext context) => const _VideoMessage(
    icon: Icons.play_circle_outline,
    label: 'Swipe to load video',
  );
}

class _VideoMessage extends StatelessWidget {
  const _VideoMessage({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: Colors.white, size: 56),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
