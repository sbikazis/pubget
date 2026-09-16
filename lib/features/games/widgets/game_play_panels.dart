import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/network_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../models/game_models.dart';
import '../models/game_type_registry.dart';
import '../providers/game_providers.dart';
import 'game_widgets.dart';

class GameDeadlineTimer extends StatefulWidget {
  const GameDeadlineTimer({required this.deadlineAt, super.key});

  final DateTime? deadlineAt;

  @override
  State<GameDeadlineTimer> createState() => _GameDeadlineTimerState();
}

class _GameDeadlineTimerState extends State<GameDeadlineTimer> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deadline = widget.deadlineAt;
    if (deadline == null) return const SizedBox.shrink();
    final remaining = deadline.difference(DateTime.now());
    final expired = remaining.isNegative || remaining == Duration.zero;
    final label = expired
        ? GameStrings.timedOut
        : '${remaining.inSeconds.clamp(0, 999)}s';
    return PubgetBadge(label: label);
  }
}

class GamePlayArea extends StatelessWidget {
  const GamePlayArea({required this.game, required this.userId, super.key});

  final PubgetGame game;
  final String userId;

  @override
  Widget build(BuildContext context) {
    if (game.isTerminal) {
      return GameResultPanel(game: game, userId: userId);
    }
    if (game.status == GameStatus.waiting) {
      return const SizedBox.shrink();
    }
    if (!game.isPlayable) {
      return PubgetCard(
        child: Text('This game is ${game.status.name}.'),
      );
    }
    return switch (game.type) {
      GameType.guessCharacter => GuessCharacterPlay(game: game, userId: userId),
      GameType.animeChain => AnimeChainPlay(game: game, userId: userId),
      GameType.emojiAnimeGuess => EmojiGuessPlay(game: game, userId: userId),
      GameType.mafia => const SizedBox.shrink(),
    };
  }
}

class GameResultPanel extends StatelessWidget {
  const GameResultPanel({required this.game, required this.userId, super.key});

  final PubgetGame game;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final result = game.result;
    final scores = result?.scores ?? const <String, int>{};
    final won = result?.winnerIds.contains(userId) == true;
    final draw = result?.summary['draw'] == true;
    return PubgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            draw
                ? 'Draw'
                : won
                ? 'You won'
                : 'Result',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (result != null && result.winnerIds.isNotEmpty)
            Text('Winners: ${result.winnerIds.join(', ')}'),
          for (final entry in scores.entries) Text('${entry.key}: ${entry.value}'),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            children: <Widget>[
              PubgetSecondaryButton(
                onPressed: () => GameLinks.open(context, game.id),
                semanticLabel: GameStrings.viewHistory,
                child: const Text(GameStrings.viewHistory),
              ),
              if (game.groupId != null)
                PubgetPrimaryButton(
                  onPressed: () =>
                      GameLinks.openCreate(context, groupId: game.groupId),
                  semanticLabel: GameStrings.playAgain,
                  child: const Text(GameStrings.playAgain),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class GuessCharacterPlay extends StatelessWidget {
  const GuessCharacterPlay({
    required this.game,
    required this.userId,
    super.key,
  });

  final PubgetGame game;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final state = game.publicState;
    final prompt = state['prompt'] is Map
        ? Map<String, dynamic>.from(state['prompt'] as Map)
        : const <String, dynamic>{};
    final choices = (prompt['choices'] as List<Object?>? ?? const <Object?>[])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final answered =
        (state['answeredPlayerIds'] as List<Object?>? ?? const <Object?>[])
            .whereType<String>()
            .toList();
    final already = answered.contains(userId);
    final scores = _scoreMap(state['scores']);
    final lastReveal = state['lastReveal'] is Map
        ? Map<String, dynamic>.from(state['lastReveal'] as Map)
        : null;
    final online = _online(context);
    return PubgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'Round ${state['roundNumber'] ?? game.currentRoundNumber ?? 1}'
                '/${state['totalRounds'] ?? game.configuration.roundCount}',
              ),
              const Spacer(),
              GameDeadlineTimer(deadlineAt: game.deadlineAt),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            prompt['question'] as String? ?? 'Who is this character?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          CharacterArtworkView(
            artwork: prompt['artwork'],
            fallbackClue: prompt['clue'] as String?,
          ),
          const SizedBox(height: AppSpacing.md),
          if (already)
            const Text('Answer locked in. Waiting for the round to resolve.'),
          if (!already && !online)
            const Text(GameStrings.offlineAction),
          for (final choice in choices)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: PubgetSecondaryButton(
                onPressed: provider.busy || already || !online
                    ? null
                    : () => provider.submitAction(
                        gameId: game.id,
                        actionType: GameActionTypes.guess,
                        payload: <String, dynamic>{
                          'choiceId': choice['id'],
                          'stateVersion': game.stateVersion,
                        },
                        clientActionId:
                            '${game.id}-${game.stateVersion}-$userId',
                      ),
                semanticLabel: choice['name'] as String? ?? 'choice',
                child: Text(choice['name'] as String? ?? 'Unknown'),
              ),
            ),
          Text('You ${scores[userId] ?? 0} · Opponent ${_opponentScore(scores, userId)}'),
          if (lastReveal != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Last answer: ${lastReveal['correctName'] ?? ''}'),
          ],
          GameActionFeedback(message: provider.actionFeedback),
        ],
      ),
    );
  }
}

class CharacterArtworkView extends StatelessWidget {
  const CharacterArtworkView({
    required this.artwork,
    this.fallbackClue,
    super.key,
  });

  final Object? artwork;
  final String? fallbackClue;

  @override
  Widget build(BuildContext context) {
    final parsed = _parseArtwork(artwork);
    if (parsed == null) {
      if (fallbackClue == null || fallbackClue!.isEmpty) {
        return const SizedBox.shrink();
      }
      return Text(fallbackClue!);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          label: 'Character portrait',
          child: SizedBox(
            height: 180,
            width: double.infinity,
            child: CustomPaint(
              painter: _SilhouettePainter(parsed),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          parsed.attribution,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (fallbackClue != null && fallbackClue!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(fallbackClue!),
        ],
      ],
    );
  }
}

final class _ArtworkPortrait {
  const _ArtworkPortrait({
    required this.background,
    required this.shapes,
    required this.attribution,
  });

  final Color background;
  final List<Map<String, dynamic>> shapes;
  final String attribution;
}

_ArtworkPortrait? _parseArtwork(Object? raw) {
  if (raw is! Map) return null;
  final map = Map<String, dynamic>.from(raw);
  final portrait = map['portrait'];
  if (portrait is! Map) return null;
  final portraitMap = Map<String, dynamic>.from(portrait);
  final background = _colorOf(portraitMap['background']);
  final shapesRaw = portraitMap['shapes'];
  if (background == null || shapesRaw is! List || shapesRaw.isEmpty) {
    return null;
  }
  final shapes = <Map<String, dynamic>>[];
  for (final item in shapesRaw) {
    if (item is Map) shapes.add(Map<String, dynamic>.from(item));
  }
  if (shapes.isEmpty) return null;
  return _ArtworkPortrait(
    background: background,
    shapes: shapes,
    attribution: map['attribution'] as String? ?? 'Original Pubget silhouette',
  );
}

Color? _colorOf(Object? value) {
  if (value is! String || !value.startsWith('#') || value.length < 7) {
    return null;
  }
  final hex = int.tryParse(value.substring(1), radix: 16);
  if (hex == null) return null;
  return Color(0xFF000000 | hex);
}

class _SilhouettePainter extends CustomPainter {
  const _SilhouettePainter(this.portrait);

  final _ArtworkPortrait portrait;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = portrait.background);
    final sx = size.width / 100;
    final sy = size.height / 100;
    for (final shape in portrait.shapes) {
      final color = _colorOf(shape['color']) ?? Colors.white;
      final paint = Paint()..color = color;
      final type = shape['type'] as String? ?? 'rect';
      if (type == 'circle') {
        canvas.drawCircle(
          Offset(_num(shape['x']) * sx, _num(shape['y']) * sy),
          _num(shape['r']) * sx,
          paint,
        );
      } else if (type == 'ellipse') {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(_num(shape['x']) * sx, _num(shape['y']) * sy),
            width: _num(shape['rx']) * 2 * sx,
            height: _num(shape['ry']) * 2 * sy,
          ),
          paint,
        );
      } else {
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            _num(shape['x']) * sx,
            _num(shape['y']) * sy,
            _num(shape['w']) * sx,
            _num(shape['h']) * sy,
          ),
          Radius.circular(_num(shape['r']) * sx),
        );
        canvas.drawRRect(rect, paint);
      }
    }
  }

  double _num(Object? value) {
    if (value is num) return value.toDouble();
    return 0;
  }

  @override
  bool shouldRepaint(covariant _SilhouettePainter oldDelegate) =>
      oldDelegate.portrait != portrait;
}

class AnimeChainPlay extends StatefulWidget {
  const AnimeChainPlay({required this.game, required this.userId, super.key});

  final PubgetGame game;
  final String userId;

  @override
  State<AnimeChainPlay> createState() => _AnimeChainPlayState();
}

class _AnimeChainPlayState extends State<AnimeChainPlay> {
  final _title = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final state = widget.game.publicState;
    final chain = (state['chain'] as List<Object?>? ?? const <Object?>[])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final current = state['currentPlayerId'] as String?;
    final mine = current == widget.userId;
    final online = _online(context);
    return PubgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  state['rule'] as String? ?? 'Keep the chain valid.',
                ),
              ),
              GameDeadlineTimer(deadlineAt: widget.game.deadlineAt),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(mine ? GameStrings.yourTurn : GameStrings.waitingTurn),
          const SizedBox(height: AppSpacing.sm),
          for (final link in chain) Text(link['title'] as String? ?? ''),
          if (mine) ...[
            const SizedBox(height: AppSpacing.md),
            PubgetTextField(
              controller: _title,
              label: 'Next title',
              enabled: !provider.busy && online,
            ),
            const SizedBox(height: AppSpacing.sm),
            PubgetPrimaryButton(
              onPressed: provider.busy || !online
                  ? null
                  : () => provider.submitAction(
                      gameId: widget.game.id,
                      actionType: GameActionTypes.submit,
                      payload: <String, dynamic>{
                        'title': _title.text,
                        'stateVersion': widget.game.stateVersion,
                      },
                      clientActionId:
                          '${widget.game.id}-${widget.game.stateVersion}-${widget.userId}',
                    ),
              semanticLabel: GameStrings.submit,
              child: Text(
                provider.busy ? GameStrings.submitting : GameStrings.submit,
              ),
            ),
            if (!online) const Text(GameStrings.offlineAction),
          ],
          GameActionFeedback(message: provider.actionFeedback),
        ],
      ),
    );
  }
}

class EmojiGuessPlay extends StatefulWidget {
  const EmojiGuessPlay({required this.game, required this.userId, super.key});

  final PubgetGame game;
  final String userId;

  @override
  State<EmojiGuessPlay> createState() => _EmojiGuessPlayState();
}

class _EmojiGuessPlayState extends State<EmojiGuessPlay> {
  final _guess = TextEditingController();

  @override
  void dispose() {
    _guess.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final state = widget.game.publicState;
    final current = state['currentPlayerId'] as String?;
    final mine = current == widget.userId;
    final emojis = (state['emojis'] as List<Object?>? ?? const <Object?>[])
        .whereType<String>()
        .toList();
    final lastReveal = state['lastReveal'] is Map
        ? Map<String, dynamic>.from(state['lastReveal'] as Map)
        : null;
    final scores = _scoreMap(state['scores']);
    final online = _online(context);
    return PubgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'Turn ${((state['turnIndex'] as num?)?.toInt() ?? 0) + 1}'
                '/${state['totalTurns'] ?? '?'}',
              ),
              const Spacer(),
              GameDeadlineTimer(deadlineAt: widget.game.deadlineAt),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(mine ? GameStrings.yourTurn : GameStrings.waitingTurn),
          if (emojis.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              emojis.join('  '),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (mine) ...[
            PubgetTextField(
              controller: _guess,
              label: 'Anime title',
              enabled: !provider.busy && online,
            ),
            const SizedBox(height: AppSpacing.sm),
            PubgetPrimaryButton(
              onPressed: provider.busy || !online
                  ? null
                  : () => provider.submitAction(
                      gameId: widget.game.id,
                      actionType: GameActionTypes.guess,
                      payload: <String, dynamic>{
                        'title': _guess.text,
                        'stateVersion': widget.game.stateVersion,
                      },
                      clientActionId:
                          '${widget.game.id}-${widget.game.stateVersion}-guess',
                    ),
              semanticLabel: 'Submit guess',
              child: const Text('Submit guess'),
            ),
          ],
          Text('You ${scores[widget.userId] ?? 0}'),
          if (lastReveal != null && lastReveal['title'] is String) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Last title: ${lastReveal['title']}'),
          ],
          if (!online) const Text(GameStrings.offlineAction),
          GameActionFeedback(message: provider.actionFeedback),
        ],
      ),
    );
  }
}

bool _online(BuildContext context) {
  try {
    return context.read<NetworkService>().isOnline;
  } on ProviderNotFoundException {
    return true;
  }
}

Map<String, int> _scoreMap(dynamic raw) {
  if (raw is! Map) return const <String, int>{};
  final scores = <String, int>{};
  for (final entry in raw.entries) {
    if (entry.key is String && entry.value is num) {
      scores[entry.key as String] = (entry.value as num).toInt();
    }
  }
  return scores;
}

int _opponentScore(Map<String, int> scores, String userId) {
  for (final entry in scores.entries) {
    if (entry.key != userId) return entry.value;
  }
  return 0;
}
