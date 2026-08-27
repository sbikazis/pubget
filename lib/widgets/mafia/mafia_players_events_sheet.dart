// lib/widgets/mafia/mafia_players_events_sheet.dart
//
// DraggableScrollableSheet قابل للسحب — مقبض صغير عند الطي (0.09
// من ارتفاع الشاشة) لا يحجب الدردشة، يتمدد لتبويبين: اللاعبون
// والأحداث. يُستخدم داخل Stack في mafia_game_screen.dart مباشرة،
// وليس عبر showModalBottomSheet.

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/mafia/mafia_player_model.dart';
import '../../models/mafia/mafia_event_model.dart';

class MafiaPlayersEventsSheet extends StatelessWidget {
  final List<MafiaPlayerModel> players;
  final List<MafiaEventModel> events;
  final String currentUserId;

  const MafiaPlayersEventsSheet({
    super.key,
    required this.players,
    required this.events,
    required this.currentUserId,
  });

  IconData _eventIcon(String type) {
    switch (type) {
      case 'PlayerKilled': return Icons.dangerous_rounded;
      case 'PlayerSaved': return Icons.shield_rounded;
      case 'PlayerExecuted': return Icons.gavel_rounded;
      case 'RolesAssigned': return Icons.style_rounded;
      case 'PhaseChanged': return Icons.autorenew_rounded;
      case 'GameFinished': return Icons.emoji_events_rounded;
      case 'ExecutionSkipped': return Icons.remove_circle_outline_rounded;
      case 'SniperMissed': return Icons.gps_off_rounded;
      default: return Icons.info_outline_rounded;
    }
  }

  Color _eventColor(String type) {
    switch (type) {
      case 'PlayerKilled':
      case 'PlayerExecuted':
        return AppColors.error;
      case 'PlayerSaved':
        return const Color(0xFF10B981);
      case 'GameFinished':
        return AppColors.goldAccent;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.09,
      minChildSize: 0.09,
      maxChildSize: 0.75,
      snap: true,
      snapSizes: const [0.09, 0.45, 0.75],
      builder: (context, scrollController) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return DefaultTabController(
          length: 2,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, -4)),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 10),
                TabBar(
                  labelColor: AppColors.primary,
                  unselectedLabelColor: isDark ? Colors.white54 : Colors.black45,
                  indicatorColor: AppColors.primary,
                  tabs: [
                    Tab(text: 'اللاعبون (${players.length})', icon: const Icon(Icons.groups_rounded, size: 20)),
                    const Tab(text: 'الأحداث', icon: Icon(Icons.timeline_rounded, size: 20)),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildPlayersList(context, scrollController, isDark),
                      _buildEventsList(scrollController, isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayersList(BuildContext context, ScrollController controller, bool isDark) {
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: players.length,
      itemBuilder: (context, index) {
        final player = players[index];
        final isMe = player.id == currentUserId;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isMe ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Row(
            children: [
              Stack(children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: player.avatar.isNotEmpty ? NetworkImage(player.avatar) : null,
                  child: player.avatar.isEmpty ? const Icon(Icons.person) : null,
                ),
                if (player.isDisconnected)
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.disabled, shape: BoxShape.circle,
                        border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(width: 10),
              Expanded(
                child: Text(isMe ? '${player.username} (أنت)' : player.username,
                    style: TextStyle(fontWeight: isMe ? FontWeight.bold : FontWeight.normal)),
              ),
              if (player.hasLeft)
                const Text('منسحب', style: TextStyle(color: AppColors.error, fontSize: 12))
              else if (!player.isAlive)
                const Text('ميت', style: TextStyle(color: AppColors.disabled, fontSize: 12))
              else
                const Icon(Icons.circle, size: 8, color: AppColors.success),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEventsList(ScrollController controller, bool isDark) {
    return ListView.builder(
      controller: controller,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[events.length - 1 - index];
        final color = _eventColor(event.type);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                child: Icon(_eventIcon(event.type), size: 14, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(event.message, style: const TextStyle(fontSize: 13.5))),
            ],
          ),
        );
      },
    );
  }
}