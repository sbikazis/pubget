// lib/widgets/mafia/mafia_waiting_room.dart
//
// ✅ التعديل الوحيد: عند وصول العداد للصفر (لكن قبل أن يعالجه
// Cloud Function)، عرض حالة "جاري التحقق..." متحركة بدل تجميد الرقم
// على 00:00 بلا أي مؤشر. هذا يوضح للمستخدم أن هناك معالجة تجري
// بالخلفية، بدل أن تبدو الشاشة معطوبة.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/mafia/mafia_game_model.dart';
import '../../models/mafia/mafia_player_model.dart';
import '../../core/constants/mafia_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/mafia_game_provider.dart';

class MafiaWaitingRoom extends StatefulWidget {
  final MafiaGameModel game;
  final List<MafiaPlayerModel> players;
  final String currentUserId;

  const MafiaWaitingRoom({
    super.key,
    required this.game,
    required this.players,
    required this.currentUserId,
  });

  @override
  State<MafiaWaitingRoom> createState() => _MafiaWaitingRoomState();
}

class _MafiaWaitingRoomState extends State<MafiaWaitingRoom> {
  Timer? _ticker;
  Duration _remaining = Duration.zero;
  bool _actionInProgress = false;

  @override
  void initState() {
    super.initState();
    _recalculateRemaining();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(_recalculateRemaining);
    });
  }

  @override
  void didUpdateWidget(covariant MafiaWaitingRoom oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game.countdownEndsAt != widget.game.countdownEndsAt) {
      _recalculateRemaining();
    }
  }

  void _recalculateRemaining() {
    final endsAt = widget.game.countdownEndsAt;
    if (endsAt == null) {
      _remaining = Duration.zero;
      return;
    }
    final diff = endsAt.difference(DateTime.now());
    _remaining = diff.isNegative ? Duration.zero : diff;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  bool get _isCurrentUserJoined =>
      widget.players.any((p) => p.id == widget.currentUserId);

  bool get _canJoin =>
      widget.game.status == MafiaGameStatus.waiting &&
      !widget.game.isLocked &&
      !_isCurrentUserJoined;

  bool get _canLeave =>
      (widget.game.status == MafiaGameStatus.waiting ||
          widget.game.status == MafiaGameStatus.starting) &&
      _isCurrentUserJoined;

  Future<void> _handleJoin() async {
    setState(() => _actionInProgress = true);
    try {
      await context.read<MafiaGameProvider>().joinCurrentUser(gameId: widget.game.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _handleLeave() async {
    setState(() => _actionInProgress = true);
    try {
      await context.read<MafiaGameProvider>().leaveCurrentUser(gameId: widget.game.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  String get _countdownLabel {
    final m = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// ✅ جديد: هل انتهى العد لكن الحالة لسه ما تغيّرت (المرحلة
  /// الانتقالية بين انتهاء الوقت محلياً وتنفيذ processExpiredLobbies
  /// على السيرفر، حتى دقيقة واحدة كحد أقصى).
  bool get _isPendingServerResolution {
    final endsAt = widget.game.countdownEndsAt;
    if (endsAt == null) return false;
    return _remaining == Duration.zero;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isStarting = widget.game.status == MafiaGameStatus.starting;
    final showCountdown = widget.game.countdownEndsAt != null;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.groups_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('غرفة انتظار المافيا', style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
                ],
              ),
              if (widget.game.isLocked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.goldAccent.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.goldAccent),
                  ),
                  child: const Text('اكتمل العدد',
                      style: TextStyle(color: AppColors.goldAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text('${widget.players.length} / ${widget.game.maxPlayers} لاعبين',
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.disabled)),
          if (showCountdown) ...[
            const SizedBox(height: 10),
            _isPendingServerResolution
                ? Row(
                    children: [
                      const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.goldAccent),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isStarting ? 'جاري بدء المباراة...' : 'جاري التحقق من اكتمال العدد...',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.goldAccent,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Icon(
                        isStarting ? Icons.rocket_launch_rounded : Icons.timer_outlined,
                        size: 18,
                        color: isStarting ? AppColors.primary : AppColors.goldAccent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isStarting
                            ? 'تبدأ المباراة خلال $_countdownLabel'
                            : 'ينتهي وقت الانتظار خلال $_countdownLabel',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: widget.players.length,
              itemBuilder: (context, index) {
                final player = widget.players[index];
                final isMe = player.id == widget.currentUserId;
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isMe
                          ? AppColors.primary.withOpacity(0.4)
                          : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                  ),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundImage:
                                player.avatar.isNotEmpty ? NetworkImage(player.avatar) : null,
                            child: player.avatar.isEmpty ? const Icon(Icons.person) : null,
                          ),
                          if (player.isDisconnected)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: AppColors.disabled,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isMe ? '${player.username} (أنت)' : player.username,
                          style: TextStyle(fontWeight: isMe ? FontWeight.bold : FontWeight.normal),
                        ),
                      ),
                      if (player.hasLeft)
                        const Text('منسحب', style: TextStyle(color: AppColors.error, fontSize: 12))
                      else if (player.isDisconnected)
                        const Text('غير متصل', style: TextStyle(color: AppColors.disabled, fontSize: 12))
                      else
                        const Icon(Icons.circle, size: 8, color: AppColors.success),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: _canJoin
                ? ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _actionInProgress ? null : _handleJoin,
                    icon: _actionInProgress
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.login),
                    label: const Text('انضمام للعبة'),
                  )
                : _canLeave
                    ? OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _actionInProgress ? null : _handleLeave,
                        icon: const Icon(Icons.logout),
                        label: const Text('خروج من الغرفة'),
                      )
                    : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}