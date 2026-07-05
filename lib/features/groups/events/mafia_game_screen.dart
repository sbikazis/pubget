import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../widgets/mafia/mafia_phase_banner.dart';
import '../../widgets/mafia/mafia_waiting_room.dart';
import '../../../models/mafia/mafia_player_model.dart';
import '../../../models/mafia/mafia_chat_message_model.dart';
import '../../../providers/mafia_game_provider.dart';
import '../../../models/mafia/mafia_game_model.dart';

class MafiaGameScreen extends StatefulWidget {
  final String gameId;

  const MafiaGameScreen({super.key, required this.gameId});

  @override
  State<MafiaGameScreen> createState() => _MafiaGameScreenState();
}

class _MafiaGameScreenState extends State<MafiaGameScreen> {
  MafiaGameProvider? _provider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<MafiaGameProvider>();
    if (_provider != provider) {
      _provider = provider;
      provider.subscribeToGame(gameId: widget.gameId);
    }
  }

  @override
  void dispose() {
    _provider?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MafiaGameProvider>(
      builder: (context, provider, child) {
        final game = provider.currentGame;
        final players = provider.players;
        final events = provider.events;
        final chatMessages = provider.chatMessages;

        if (game == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('لعبة المافيا'),
            centerTitle: true,
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: MafiaPhaseBanner(
                  phase: 'المرحلة: ${game.currentPhase}',
                  subtitle: 'اليوم ${game.currentDay} - الليل ${game.currentNight}',
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          Expanded(
                            child: MafiaWaitingRoom(
                              players: players,
                              minPlayers: game.minPlayers,
                              maxPlayers: game.maxPlayers,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _buildEventTimeline(events),
                          ),
                        ],
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 1,
                      child: _buildChatList(chatMessages),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEventTimeline(List<MafiaEventModel> events) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('أحداث المباراة', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                return ListTile(
                  dense: true,
                  title: Text(event.message),
                  subtitle: Text(event.type),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList(List<MafiaChatMessageModel> messages) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('دردشة المافيا', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return ListTile(
                  dense: true,
                  title: Text(message.sender),
                  subtitle: Text(message.text),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
