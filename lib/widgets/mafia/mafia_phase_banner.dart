// lib/widgets/mafia/mafia_phase_banner.dart
//
// ✅ تلميع: تدرّج لوني (gradient) لكل مرحلة، أيقونة مميزة، انتقال
// متحرك (AnimatedSwitcher) عند تغيّر المرحلة بدل التبديل المفاجئ.

import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/mafia_constants.dart';
import '../../core/mafia/mafia_game_engine.dart';
import 'package:pubget/core/mafia/mafia_timer_service.dart';
import '../../models/mafia/mafia_game_model.dart';

class MafiaPhaseBanner extends StatefulWidget {
  final MafiaGameModel game;

  const MafiaPhaseBanner({super.key, required this.game});

  @override
  State<MafiaPhaseBanner> createState() => _MafiaPhaseBannerState();
}

class _MafiaPhaseBannerState extends State<MafiaPhaseBanner> {
  final MafiaTimerService _timerService = MafiaTimerService();
  Timer? _ticker;
  int _remaining = 0;

  @override
  void initState() {
    super.initState();
    _recalculate();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(_recalculate);
    });
  }

  @override
  void didUpdateWidget(covariant MafiaPhaseBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game.phaseEndsAt != widget.game.phaseEndsAt ||
        oldWidget.game.status != widget.game.status) {
      _recalculate();
    }
  }

  void _recalculate() {
    _remaining = _timerService.remainingSeconds(widget.game.phaseEndsAt);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  List<Color> _phaseGradient(MafiaGameStatus status) {
    switch (status) {
      case MafiaGameStatus.night:
        return const [Color(0xFF1E1B4B), Color(0xFF3730A3)];
      case MafiaGameStatus.day:
        return const [Color(0xFFF59E0B), Color(0xFFFBBF24)];
      case MafiaGameStatus.discussion:
        return const [Color(0xFF0F766E), Color(0xFF14B8A6)];
      case MafiaGameStatus.voting:
        return const [Color(0xFFB91C1C), Color(0xFFEA580C)];
      case MafiaGameStatus.execution:
        return const [Color(0xFF450A0A), Color(0xFFB91C1C)];
      case MafiaGameStatus.finished:
        return const [Color(0xFF065F46), Color(0xFF10B981)];
      case MafiaGameStatus.cancelled:
        return const [Color(0xFF3F3F46), Color(0xFF71717A)];
      default:
        return const [Color(0xFF5B2EFF), Color(0xFF7A57FF)];
    }
  }

  IconData _phaseIcon(MafiaGameStatus status) {
    switch (status) {
      case MafiaGameStatus.night:
        return Icons.nightlight_round;
      case MafiaGameStatus.day:
        return Icons.wb_sunny_rounded;
      case MafiaGameStatus.discussion:
        return Icons.forum_rounded;
      case MafiaGameStatus.voting:
        return Icons.how_to_vote_rounded;
      case MafiaGameStatus.execution:
        return Icons.gavel_rounded;
      case MafiaGameStatus.finished:
        return Icons.emoji_events_rounded;
      case MafiaGameStatus.cancelled:
        return Icons.cancel_rounded;
      default:
        return Icons.hourglass_top_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    const engine = MafiaGameEngine();
    final status = widget.game.status;
    final gradient = _phaseGradient(status);
    final totalDuration = engine.durationOf(status);
    final showCountdown = widget.game.phaseEndsAt != null && totalDuration > 0;
    final progress = _timerService.progressRatio(
      endsAt: widget.game.phaseEndsAt,
      totalDurationSeconds: totalDuration,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.last.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.2),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: Row(
                  key: ValueKey(status),
                  children: [
                    Icon(_phaseIcon(status), color: Colors.white, size: 26),
                    const SizedBox(width: 10),
                    Text(
                      engine.labelOf(status),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
              if (showCountdown)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _timerService.formatSeconds(_remaining),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'اليوم ${widget.game.currentDay} - الليل ${widget.game.currentNight}',
            style: TextStyle(color: Colors.white.withOpacity(0.85)),
          ),
          if (showCountdown) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
