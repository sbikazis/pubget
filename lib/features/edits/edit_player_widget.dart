import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:pubget/models/edits_model.dart';

class EditPlayerWidget extends StatefulWidget {
  final EditModel edit;
  final bool isActive;

  const EditPlayerWidget({
    super.key,
    required this.edit,
    required this.isActive,
  });

  @override
  State<EditPlayerWidget> createState() => _EditPlayerWidgetState();
}

class _EditPlayerWidgetState extends State<EditPlayerWidget> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _showControls = false;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.edit.videoUrl),
    );
    await _controller.initialize();
    _controller.setLooping(true);
    if (mounted) setState(() => _initialized = true);

    // يشتغل فقط إذا كان active وظاهر
    if (widget.isActive && _isVisible) {
      _controller.play();
    }
  }

  @override
  void didUpdateWidget(covariant EditPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_initialized) return;

    if (widget.isActive && _isVisible) {
      _controller.play();
    } else {
      _controller.pause();
    }
  }

  void _togglePlayPause() {
    if (!_initialized) return;

    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
      _showControls = true;
    });

    // إخفاء الأيقونة بعد ثانيتين
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key(widget.edit.id),
      onVisibilityChanged: (info) {
        final wasVisible = _isVisible;
        _isVisible = info.visibleFraction > 0.8;

        if (!_initialized) return;

        if (_isVisible && widget.isActive) {
          _controller.play();
        } else if (!_isVisible) {
          // ← الإصلاح الرئيسي: يوقف الفيديو عند الخروج من الشاشة
          _controller.pause();
        }
      },
      child: GestureDetector(
        onTap: _togglePlayPause,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── الفيديو
            _initialized
                ? SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller.value.size.width,
                        height: _controller.value.size.height,
                        child: VideoPlayer(_controller),
                      ),
                    ),
                  )
                : _buildThumbnail(),

            // ── أيقونة Play/Pause عند الضغط
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(16),
                child: Icon(
                  _controller.value.isPlaying
                      ? Icons.pause
                      : Icons.play_arrow,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),

            // ── شريط التقدم في الأسفل
            if (_initialized)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: VideoProgressIndicator(
                  _controller,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: Colors.white,
                    bufferedColor: Colors.white38,
                    backgroundColor: Colors.white12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    return widget.edit.thumbnailUrl.isNotEmpty
        ? Image.network(
            widget.edit.thumbnailUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          )
        : const ColoredBox(color: Colors.black);
  }
}