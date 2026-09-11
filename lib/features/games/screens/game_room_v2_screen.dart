import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/games_schema_v2.dart';
import '../providers/games_session_provider_v2.dart';
import '../widgets/v2_game_theme.dart';

class GameRoomV2Screen extends StatefulWidget {
  const GameRoomV2Screen({required this.gameId, required this.userId, super.key});
  final String gameId;
  final String userId;
  @override
  State<GameRoomV2Screen> createState() => _GameRoomV2ScreenState();
}

class _GameRoomV2ScreenState extends State<GameRoomV2Screen> {
  Timer? _ticker;
  DateTime _now = DateTime.now();
  final _answer = TextEditingController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<GamesSessionProviderV2>().open(widget.gameId);
      }
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _now = DateTime.now()));
  }
  @override
  void dispose() { _ticker?.cancel(); _answer.dispose(); super.dispose(); }

  Future<bool> _confirmExit() async {
    final game = context.read<GamesSessionProviderV2>().session;
    if (game?.status != GameLifecycleStatusV2.inProgress) return true;
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الجولة مستمرة'),
        content: const Text('الخروج الآن قد يحسب كاستسلام. هل تريد مغادرة غرفة اللعب؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('البقاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('مغادرة')),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<GamesSessionProviderV2>().session;
    if (session == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final seconds = session.deadlineAt?.difference(_now).inSeconds.clamp(0, 999);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: session.status != GameLifecycleStatusV2.inProgress,
        onPopInvokedWithResult: (didPop, _) async {
          if (!didPop && await _confirmExit() && context.mounted) Navigator.pop(context);
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(gameTypeArabic(session.type)),
            actions: [if (seconds != null) Padding(padding: const EdgeInsets.all(16), child: Text('$seconds ث', style: const TextStyle(fontWeight: FontWeight.bold)))],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _ScoreStrip(session: session),
              const SizedBox(height: 18),
              _PromptCard(session: session),
              const SizedBox(height: 16),
              TextField(controller: _answer, textInputAction: TextInputAction.done, decoration: const InputDecoration(labelText: 'اكتب إجابتك')),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _submit(session),
                icon: const Icon(Icons.send),
                label: const Text('إرسال الإجابة'),
              ),
              const SizedBox(height: 20),
              Text('كل لاعب يلعب دوره. ركّز على الشاشة، فالوقت لا ينتظر.', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(GameSessionV2 session) async {
    final value = _answer.text.trim();
    if (value.isEmpty) return;
    final result = await context.read<GamesSessionProviderV2>().send(GameCommandRequest(
      requestId: '${widget.userId}-${DateTime.now().microsecondsSinceEpoch}',
      gameId: session.id,
      expectedVersion: session.version,
      command: switch (session.type) {
        GameTypeV2.guessCharacter => 'guess',
        GameTypeV2.animeChain => 'chain',
        GameTypeV2.emojiAnimeGuess => 'guess',
      },
      payload: {'answer': value},
    ));
    if (!mounted) return;
    if (!result.isSuccess) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.failureOrNull!.message)));
    } else {
      _answer.clear();
    }
  }
}

class _ScoreStrip extends StatelessWidget {
  const _ScoreStrip({required this.session});
  final GameSessionV2 session;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        const Icon(Icons.emoji_events_outlined, color: GameV2Palette.gold),
        const SizedBox(width: 10),
        Expanded(child: Text('لوحة النتائج', style: Theme.of(context).textTheme.titleMedium)),
        ...session.players.take(3).map((player) => Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Text('${player.displayName.isEmpty ? player.userId : player.displayName}: ${player.score}'),
        )),
      ]),
    ),
  );
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({required this.session});
  final GameSessionV2 session;
  @override
  Widget build(BuildContext context) {
    final state = session.state;
    final prompt = state['question']?.toString() ?? state['prompt']?.toString();
    final chain = (state['chain'] as List?)?.whereType<String>().toList() ?? const <String>[];
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: GameV2Palette.gold.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: GameV2Palette.gold.withValues(alpha: .45)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('الجولة ${state['round'] ?? state['questionCount'] ?? 1}', style: const TextStyle(color: GameV2Palette.purple, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        Text(prompt ?? (chain.isEmpty ? 'استعد للسؤال التالي…' : chain.join('  ←  ')), style: Theme.of(context).textTheme.headlineSmall),
      ]),
    );
  }
}