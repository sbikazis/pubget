import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/time_utils.dart'; // استيراد ملف أدوات الوقت لتنسيق توقيت الرسالة الصوتية
import '../models/message_model.dart'; // استيراد الموديل لقراءة الحقول الجديدة

class AudioBubble extends StatefulWidget {
  final MessageModel message; // تمرير كائن الرسالة كاملاً بدلاً من مجرد الـ url
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

    // مراقبة حالة التشغيل
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });

    // مراقبة المدة الكلية
    _player.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    });

    // مراقبة الموضع الحالي
    _player.onPositionChanged.listen((position) {
      if (mounted) setState(() => _position = position);
    });

    // عند انتهاء التشغيل، أعد للبداية
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

  // =========================================================
  // دالة تحديد لون مؤشر حالة الرسالة (صح مفرد) متطابقة مع الشات
  // =========================================================
  Color _getStatusColor() {
    if (widget.message.isRead) {
      return Colors.green; // قرأها 🟢
    } else if (widget.message.isDelivered) {
      return Colors.yellow; // وصلت ولم تُقرأ 🟡
    } else {
      return Colors.red; // لم تصل للهاتف الآخر 🔴
    }
  }

  // =========================================================
  // تشغيل أو إيقاف مؤقت
  // =========================================================
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

  // =========================================================
  // تحويل Duration إلى نص mm:ss
  // =========================================================
  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // =========================================================
  // BUILD
  // =========================================================
  @override
  Widget build(BuildContext context) {
    final bool isPlaying = _playerState == PlayerState.playing;
    final bool isPaused = _playerState == PlayerState.paused;

    final double progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    final Color activeColor =
        widget.isMe ? Colors.white : AppColors.primary;
    final Color inactiveColor =
        widget.isMe ? Colors.white38 : AppColors.primary.withValues(alpha: 0.25);

    return SizedBox(
      width: 220,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end, // محاذاة التوقيت والصح لليمين بالأسفل
        children: [
          Row(
            children: [
              // ── زر التشغيل ──
              GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: activeColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: _isLoading
                      ? Padding(
                          padding: const EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: activeColor,
                          ),
                        )
                      : Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow,
                          color: activeColor,
                          size: 22,
                    ),
                ),
              ),

              const SizedBox(width: 8),

              // ── الشريط والوقت ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // شريط التقدم
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: inactiveColor,
                        valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                      ),
                    ),

                    const SizedBox(height: 4),

                    // وقت الـ Audio الحالي أثناء التشغيل
                    Text(
                      (isPlaying || isPaused)
                          ? _formatDuration(_position)
                          : (_duration.inSeconds > 0 ? _formatDuration(_duration) : "0:00"),
                      style: TextStyle(
                        fontSize: 11,
                        color: activeColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 6),

              // ── أيقونة الصوت ──
              Icon(
                Icons.mic,
                size: 16,
                color: activeColor.withValues(alpha: 0.5),
              ),
            ],
          ),
          
          const SizedBox(height: 4),
          
          // ── التوقيت وعلامة الصح للرسالة (أسفل المشغل) ──
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                TimeUtils.formatChatTime(widget.message.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: activeColor.withValues(alpha: 0.7),
                ),
              ),
              if (widget.isMe) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.done, // علامة صح مفردة ديناميكية
                  size: 15,
                  color: _getStatusColor(),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}