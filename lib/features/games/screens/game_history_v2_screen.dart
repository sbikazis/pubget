import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/games_schema_v2.dart';
import '../repositories/games_repository_v2.dart';
import '../providers/games_session_provider_v2.dart';
import '../widgets/v2_game_theme.dart';

class GameHistoryV2Screen extends StatefulWidget {
  const GameHistoryV2Screen({required this.groupId, required this.userId, super.key});
  final String groupId;
  final String userId;
  @override
  State<GameHistoryV2Screen> createState() => _GameHistoryV2ScreenState();
}
class _GameHistoryV2ScreenState extends State<GameHistoryV2Screen> {
  final _games = <GameSessionV2>[];
  String? _cursor;
  bool _loading = true;
  String? _error;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final result = await context.read<GamesRepositoryV2>().groupHistory(groupId: widget.groupId, cursor: _cursor);
    if (!mounted) return;
    if (result.valueOrNull == null) {
      setState(() => _error = result.failureOrNull?.message ?? 'تعذر التحميل');
    } else {
      setState(() {
        _games.addAll(result.valueOrNull!.games);
        _cursor = result.valueOrNull!.nextCursor;
      });
    }
    setState(() => _loading = false);
  }
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('أرشيف المباريات')),
      body: _error != null
          ? Center(child: _StateError(message: _error!, onRetry: _load))
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _games.length + (_cursor != null ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _games.length) {
                  return _loading
                      ? const Center(child: CircularProgressIndicator())
                      : TextButton(
                          onPressed: _load,
                          child: const Text('تحميل المزيد'),
                        );
                }
                final game = _games[index];
                return Card(child: ListTile(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: context.read<GamesSessionProviderV2>(), child: GameHistoryDetailV2Screen(gameId: game.id, userId: widget.userId)))),
                  title: Text(gameTypeArabic(game.type)),
                  subtitle: Text('${game.players.length} لاعبين · ${gameStatusArabic(game.status)}'),
                  trailing: const Icon(Icons.chevron_left),
                ));
              },
            ),
    ),
  );
}
class _StateError extends StatelessWidget {
  const _StateError({required this.message, required this.onRetry});
  final String message; final VoidCallback onRetry;
  @override Widget build(BuildContext context) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(message), TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة'))]);
}

class GameHistoryDetailV2Screen extends StatefulWidget {
  const GameHistoryDetailV2Screen({required this.gameId, required this.userId, super.key});
  final String gameId; final String userId;
  @override State<GameHistoryDetailV2Screen> createState() => _GameHistoryDetailV2ScreenState();
}
class _GameHistoryDetailV2ScreenState extends State<GameHistoryDetailV2Screen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<GamesSessionProviderV2>().open(widget.gameId);
      }
    });
  }
  @override Widget build(BuildContext context) {
    final game = context.watch<GamesSessionProviderV2>().session;
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(appBar: AppBar(title: const Text('تفاصيل المباراة')), body: game == null ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(20), children: [
      Text(gameTypeArabic(game.type), style: Theme.of(context).textTheme.headlineMedium),
      Text(gameStatusArabic(game.status)),
      const SizedBox(height: 22),
      for (final player in [...game.players]..sort((a, b) => b.score.compareTo(a.score))) Card(child: ListTile(leading: Text('${player.score}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), title: Text(player.displayName.isEmpty ? player.userId : player.displayName))),
    ])));
  }
}