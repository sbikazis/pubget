import 'package:flutter/material.dart';
import '../../models/mafia/mafia_player_model.dart';

class MafiaWaitingRoom extends StatelessWidget {
  final List<MafiaPlayerModel> players;
  final int minPlayers;
  final int maxPlayers;

  const MafiaWaitingRoom({
    super.key,
    required this.players,
    required this.minPlayers,
    required this.maxPlayers,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'غرفة انتظار المافيا',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Text('عدد اللاعبين: ${players.length} / $maxPlayers'),
        const SizedBox(height: 12),
        Expanded(
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
                subtitle: Text(player.isAlive ? 'في الانتظار' : 'خارج'),
              );
            },
          ),
        ),
      ],
    );
  }
}
