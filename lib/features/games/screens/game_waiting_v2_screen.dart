import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/games_schema_v2.dart';
import '../providers/games_session_provider_v2.dart';
import '../widgets/v2_game_theme.dart';
import 'game_room_v2_screen.dart';

class GameWaitingV2Screen extends StatefulWidget {
  const GameWaitingV2Screen({required this.gameId, required this.userId, super.key});
  final String gameId;
  final String userId;
  @override
  State<GameWaitingV2Screen> createState() => _GameWaitingV2ScreenState();
}

class _GameWaitingV2ScreenState extends State<GameWaitingV2Screen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<GamesSessionProviderV2>().open(widget.gameId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GamesSessionProviderV2>();
    final game = provider.session;
    if (game != null &&
        (game.status == GameLifecycleStatusV2.starting ||
            game.status == GameLifecycleStatusV2.inProgress)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => GameRoomV2Screen(
                gameId: widget.gameId,
                userId: widget.userId,
              ),
            ),
          );
        }
      });
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('غرفة الانتظار')),
        body: game == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(20), children: [
                _WaitingHeader(game: game),
                const SizedBox(height: 18),
                Text('المشاركون (${game.players.length})', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                for (final player in game.players) Card(child: ListTile(
                  leading: CircleAvatar(child: Text(player.displayName.isEmpty ? '?' : player.displayName.substring(0, 1))),
                  title: Text(player.displayName.isEmpty ? player.userId : player.displayName),
                  trailing: player.connected ? const Icon(Icons.check_circle_outline, color: Colors.green) : const Icon(Icons.cloud_off),
                )),
                const SizedBox(height: 18),
                if (game.creatorId == widget.userId)
                  FilledButton.icon(
                    onPressed: game.players.length < 2 ? null : () => _send('start', game),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(game.players.length < 2 ? 'بانتظار لاعب آخر' : 'ابدأ الجولة'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: _isJoined(game) ? null : () => _send('join', game),
                    icon: const Icon(Icons.login),
                    label: Text(_isJoined(game) ? 'أنت داخل الغرفة' : 'انضم إلى الغرفة'),
                  ),
                if (game.creatorId == widget.userId)
                  TextButton(onPressed: () => _send('cancel', game), child: const Text('إلغاء اللعبة')),
              ]),
      ),
    );
  }

  bool _isJoined(GameSessionV2 game) => game.players.any((p) => p.userId == widget.userId);
  Future<void> _send(String command, GameSessionV2 game) async {
    await context.read<GamesSessionProviderV2>().send(GameCommandRequest(
      requestId: '${widget.userId}-${DateTime.now().microsecondsSinceEpoch}',
      gameId: game.id,
      expectedVersion: game.version,
      command: command,
    ));
  }
}

class _WaitingHeader extends StatelessWidget {
  const _WaitingHeader({required this.game});
  final GameSessionV2 game;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(color: GameV2Palette.purple, borderRadius: BorderRadius.circular(26)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(gameTypeArabic(game.type), style: const TextStyle(color: Colors.white70)),
      const SizedBox(height: 8),
      const Text('الساحة جاهزة.', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Text('شارك الرابط مع أصدقائك ثم ابدأ الجولة.', style: TextStyle(color: Colors.white.withValues(alpha: .8))),
    ]),
  );
}