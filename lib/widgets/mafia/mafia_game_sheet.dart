import 'package:flutter/material.dart';
import '../../models/mafia/mafia_player_model.dart';
import 'mafia_phase_banner.dart';

class MafiaGameSheet extends StatelessWidget {
  final String groupId;
  final List<MafiaPlayerModel> players;
  final String status;
  final int minPlayers;
  final int maxPlayers;
  final VoidCallback onJoin;
  final VoidCallback onStart;

  const MafiaGameSheet({
    super.key,
    required this.groupId,
    required this.players,
    required this.status,
    required this.minPlayers,
    required this.maxPlayers,
    required this.onJoin,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MafiaPhaseBanner(
            phase: 'مرحلة: ${status.toUpperCase()}',
            subtitle: 'في مجموعة $groupId',
          ),
          const SizedBox(height: 16),
          Text('الحد الأدنى: $minPlayers لاعبين'),
          const SizedBox(height: 8),
          Text('الحد الأقصى: $maxPlayers لاعبين'),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: ListView.builder(
              itemCount: players.length,
              itemBuilder: (context, index) {
                final player = players[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: player.avatar.isNotEmpty
                        ? NetworkImage(player.avatar)
                        : null,
                    child: player.avatar.isEmpty ? const Icon(Icons.person) : null,
                  ),
                  title: Text(player.username),
                  subtitle: Text(player.isAlive ? 'على قيد الحياة' : 'خارج'),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onJoin,
                  child: const Text('انضم الآن'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onStart,
                  child: const Text('ابدأ اللعبة'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
