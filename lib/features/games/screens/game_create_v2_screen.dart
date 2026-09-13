import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/games_schema_v2.dart';
import '../repositories/games_repository_v2.dart';
import '../widgets/v2_game_theme.dart';
import 'game_waiting_v2_screen.dart';

class GamesCreateV2Screen extends StatefulWidget {
  const GamesCreateV2Screen({required this.groupId, required this.userId, super.key});
  final String groupId;
  final String userId;
  @override
  State<GamesCreateV2Screen> createState() => _GamesCreateV2ScreenState();
}

class _GamesCreateV2ScreenState extends State<GamesCreateV2Screen> {
  GameTypeV2 _type = GameTypeV2.guessCharacter;
  bool _busy = false;
  String? _error;

  Future<void> _create() async {
    setState(() { _busy = true; _error = null; });
    final result = await context.read<GamesRepositoryV2>().create(
      groupId: widget.groupId,
      type: _type,
      requestId: '${widget.userId}-${DateTime.now().microsecondsSinceEpoch}',
    );
    if (!mounted) return;
    final game = result.valueOrNull;
    if (game == null) {
      setState(() {
        _busy = false;
        _error = result.failureOrNull?.message ?? 'تعذر إنشاء اللعبة';
      });
      return;
    }
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameWaitingV2Screen(gameId: game.id, userId: widget.userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('بطولة جديدة')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('اختر ساحة اللعب', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text('الألعاب الثلاث متاحة من مركز الألعاب. Mafia ستصل في Prompt 2.'),
          const SizedBox(height: 22),
          for (final type in GameTypeV2.values)
            _TypeCard(type: type, selected: type == _type, onTap: () => setState(() => _type = type)),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _create,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sports_esports),
            label: Text(_busy ? 'جاري تجهيز الساحة…' : 'ابدأ إنشاء اللعبة'),
          ),
        ],
      ),
    ),
  );
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({required this.type, required this.selected, required this.onTap});
  final GameTypeV2 type;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    color: selected ? GameV2Palette.purple.withValues(alpha: .12) : null,
    child: InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          Icon(switch (type) {
            GameTypeV2.guessCharacter => Icons.face,
            GameTypeV2.animeChain => Icons.account_tree,
            GameTypeV2.emojiAnimeGuess => Icons.lightbulb_outline,
          }, color: GameV2Palette.purple),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(gameTypeArabic(type), style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(switch (type) {
              GameTypeV2.guessCharacter => 'تحدٍّ فردي سريع',
              GameTypeV2.animeChain => 'أدوار متناوبة',
              GameTypeV2.emojiAnimeGuess => 'جولات تخمين',
            }),
          ])),
          Radio<bool>(value: true, groupValue: selected ? true : null, onChanged: (_) => onTap()),
        ]),
      ),
    ),
  );
}