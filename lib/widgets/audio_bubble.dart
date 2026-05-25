import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import '../core/theme/app_colors.dart';
import '../models/message_model.dart';

class AudioBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMe;

  const AudioBubble({
    super.key,
    required this.message,
    this.isMe = false,
  });

  @override
  State<AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<AudioBubble> {
  final AudioPlayer _player = AudioPlayer();

  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });

    _player.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    });

    _player.onPositionChanged.listen((position) {
      if (mounted) setState(() => _position = position);
    });

    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _position = Duration.zero;
          _playerState = PlayerState.stopped;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    if (_isLoading) return;

    if (_playerState == PlayerState.playing) {
      await _player.pause();
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_playerState == PlayerState.paused) {
        await _player.resume();
      } else {
        await _player.play(UrlSource(widget.message.mediaUrl ?? ''));
      }
    } catch (e) {
      debugPrint('AudioBubble error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final bool isPlaying = _playerState == PlayerState.playing;
    final bool isPaused = _playerState == PlayerState.paused;

    final double progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    final Color activeColor = widget.isMe ? Colors.white : AppColors.primary;
    final Color inactiveColor = widget.isMe ? Colors.white38 : AppColors.primary.withValues(alpha: 0.25);

    return SizedBox(
      width: 200,
      child: Row(
        children: [
          // زر التشغيل
          GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: activeColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: _isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(8),
                      child: CircularProgressIndicator(strokeWidth: 2, color: activeColor),
                    )
                  : Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: activeColor, size: 20),
            ),
          ),
          const SizedBox(width: 8),
          // الشريط والمدة
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    backgroundColor: inactiveColor,
                    valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  (isPlaying || isPaused) ? _formatDuration(_position) : _formatDuration(_duration),
                  style: TextStyle(fontSize: 10, color: activeColor.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.mic, size: 14, color: activeColor.withValues(alpha: 0.5)),
        ],
      ),
    );
  }
}