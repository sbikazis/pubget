import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/network_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../models/game_models.dart';
import '../models/game_type_registry.dart';
import '../providers/game_providers.dart';
import 'catalog_search_picker.dart';
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
      return PubgetCard(child: Text('This game is ${game.status.name}.'));
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
          for (final entry in scores.entries)
            Text('${entry.key}: ${entry.value}'),
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

/// Plays the real `guessCharacter` engine: `selection` -> `ask` <-> `answer`.
///
/// The engine is strictly turn based and only accepts real catalog IDs, so the
/// panel mirrors those phases exactly instead of guessing a shape the server
/// never writes.
class GuessCharacterPlay extends StatefulWidget {
  const GuessCharacterPlay({
    required this.game,
    required this.userId,
    super.key,
  });

  final PubgetGame game;
  final String userId;

  @override
  State<GuessCharacterPlay> createState() => _GuessCharacterPlayState();
}

class _GuessCharacterPlayState extends State<GuessCharacterPlay> {
  final _question = TextEditingController();

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  void _submit(String actionType, Map<String, dynamic> payload) {
    final game = widget.game;
    context.read<GameProvider>().submitAction(
      gameId: game.id,
      actionType: actionType,
      payload: <String, dynamic>{...payload, 'stateVersion': game.stateVersion},
      clientActionId: '${game.id}-${game.stateVersion}-${widget.userId}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final game = widget.game;
    final state = game.publicState;
    final phase = state['phase'] as String? ?? 'selection';
    final players = state['players'] is Map
        ? Map<String, dynamic>.from(state['players'] as Map)
        : const <String, dynamic>{};
    final myEntry = players[widget.userId] is Map
        ? Map<String, dynamic>.from(players[widget.userId] as Map)
        : const <String, dynamic>{};
    final alreadySelected = myEntry['selected'] == true;
    final currentPlayerId = state['currentPlayerId'] as String?;
    final answeringPlayerId = state['answeringPlayerId'] as String?;
    final question = state['question'] as String?;
    final lastAction = state['lastAction'] is Map
        ? Map<String, dynamic>.from(state['lastAction'] as Map)
        : null;
    final online = _online(context);
    final locked = provider.busy || !online;

    Widget body;
    if (phase == 'selection') {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(GameStrings.chooseSecret, style: _title(context)),
          const SizedBox(height: AppSpacing.sm),
          if (alreadySelected)
            Text(GameStrings.secretLocked)
          else
            CatalogSearchPicker(
              hint: GameStrings.searchSecretCharacter,
              enabled: online,
              onSelected: (item) => _submit(
                GameActionTypes.select,
                <String, dynamic>{'characterId': item.id},
              ),
            ),
        ],
      );
    } else if (phase == 'ask') {
      final mine = currentPlayerId == widget.userId;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(mine ? GameStrings.yourTurn : GameStrings.waitingTurn),
          const SizedBox(height: AppSpacing.sm),
          if (question != null) Text(question),
          if (lastAction != null) _lastActionLine(context, lastAction),
          if (mine) ...[
            const SizedBox(height: AppSpacing.md),
            PubgetTextField(
              controller: _question,
              label: GameStrings.askAQuestion,
              enabled: !locked,
            ),
            const SizedBox(height: AppSpacing.sm),
            PubgetPrimaryButton(
              onPressed: locked
                  ? null
                  : () => _submit(GameActionTypes.ask, <String, dynamic>{
                      'question': _question.text,
                    }),
              semanticLabel: GameStrings.ask,
              child: Text(
                provider.busy ? GameStrings.submitting : GameStrings.ask,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(GameStrings.guessInstead),
            const SizedBox(height: AppSpacing.sm),
            CatalogSearchPicker(
              hint: GameStrings.searchSecretCharacter,
              enabled: online,
              emptyLabel: GameStrings.noCatalogMatch,
              onSelected: (item) => _submit(
                GameActionTypes.guess,
                <String, dynamic>{'characterId': item.id},
              ),
            ),
          ],
        ],
      );
    } else if (phase == 'answer') {
      final mine = answeringPlayerId == widget.userId;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(mine ? GameStrings.yourTurn : GameStrings.waitingTurn),
          const SizedBox(height: AppSpacing.sm),
          if (question != null) Text(question),
          if (mine) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: PubgetPrimaryButton(
                    onPressed: locked
                        ? null
                        : () => _submit(
                            GameActionTypes.answer,
                            <String, dynamic>{'answer': 'yes'},
                          ),
                    semanticLabel: GameStrings.yes,
                    child: const Text('Yes'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: PubgetSecondaryButton(
                    onPressed: locked
                        ? null
                        : () => _submit(
                            GameActionTypes.answer,
                            <String, dynamic>{'answer': 'no'},
                          ),
                    semanticLabel: GameStrings.no,
                    child: const Text('No'),
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    } else {
      body = Text(GameStrings.comingSoon);
    }

    return PubgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(GameStrings.guessCharacter),
              const Spacer(),
              GameDeadlineTimer(deadlineAt: game.deadlineAt),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          body,
          if (!online) const Text(GameStrings.offlineAction),
          GameActionFeedback(message: provider.actionFeedback),
        ],
      ),
    );
  }

  TextStyle? _title(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium;

  Widget _lastActionLine(
    BuildContext context,
    Map<String, dynamic> lastAction,
  ) {
    final type = lastAction['type'];
    return Text(switch (type) {
      'answer' => '${GameStrings.answered}: ${lastAction['answer']}',
      'wrong_guess' => GameStrings.wrongGuess,
      'timeout' => GameStrings.turnTimedOut,
      _ => '',
    }, style: Theme.of(context).textTheme.bodySmall);
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
        Text(parsed.attribution, style: Theme.of(context).textTheme.bodySmall),
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
  int _chainLength = -1;

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
    if (chain.length != _chainLength) {
      // The chain advanced, so the submitted title must not be resubmitted.
      _chainLength = chain.length;
      _title.clear();
    }
    final scores = _scoreMap(state['scores']);
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
              label: GameStrings.nextTitle,
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
          Text('${GameStrings.you} ${scores[widget.userId] ?? 0}'),
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
  int _turnIndex = -1;

  @override
  void dispose() {
    _guess.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final game = widget.game;
    final state = game.publicState;
    final turnIndex = (state['turnIndex'] as num?)?.toInt() ?? 0;
    if (turnIndex != _turnIndex) {
      // A new round must not inherit the previous guess, which the engine
      // would reject as a duplicate.
      _turnIndex = turnIndex;
      _guess.clear();
    }
    final current = state['currentPlayerId'] as String?;
    final mine = current == widget.userId;
    final answered =
        (state['answeredPlayerIds'] as List<Object?>? ?? const <Object?>[])
            .whereType<String>()
            .toList();
    final already = answered.contains(widget.userId);
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
                '${GameStrings.turn} ${turnIndex + 1}'
                '/${state['totalTurns'] ?? '?'}',
              ),
              const Spacer(),
              GameDeadlineTimer(deadlineAt: game.deadlineAt),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            mine ? GameStrings.clueOwnerTurn : GameStrings.guessTheAnime,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (emojis.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              emojis.join('  '),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (!mine) ...[
            if (already)
              const Text(GameStrings.alreadyGuessed)
            else ...[
              PubgetTextField(
                controller: _guess,
                label: GameStrings.animeTitle,
                enabled: !provider.busy && online,
              ),
              const SizedBox(height: AppSpacing.sm),
              PubgetPrimaryButton(
                onPressed: provider.busy || !online
                    ? null
                    : () => provider.submitAction(
                        gameId: game.id,
                        actionType: GameActionTypes.guess,
                        payload: <String, dynamic>{
                          'title': _guess.text,
                          'stateVersion': game.stateVersion,
                        },
                        clientActionId:
                            '${game.id}-${game.stateVersion}-${widget.userId}',
                      ),
                semanticLabel: GameStrings.submitGuess,
                child: const Text(GameStrings.submitGuess),
              ),
            ],
          ],
          Text('${GameStrings.you} ${scores[widget.userId] ?? 0}'),
          if (lastReveal != null && lastReveal['title'] is String) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('${GameStrings.lastTitle}: ${lastReveal['title']}'),
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
