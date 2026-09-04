import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../games/models/game_type_registry.dart';
import '../../games/widgets/game_play_panels.dart';
import '../../games/widgets/game_widgets.dart';
import '../models/mafia_models.dart';
import '../providers/mafia_provider.dart';

class MafiaGameScreen extends StatefulWidget {
  const MafiaGameScreen({required this.gameId, super.key});

  final String gameId;

  @override
  State<MafiaGameScreen> createState() => _MafiaGameScreenState();
}

class _MafiaGameScreenState extends State<MafiaGameScreen> {
  bool _opened = false;
  String? _openedForUser;
  final _chat = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.read<AuthProvider>().currentUser?.id;
    if (uid == null) return;
    if (_opened && _openedForUser == uid) return;
    _opened = true;
    _openedForUser = uid;
    final messenger = context.read<MafiaProvider>();
    Future<void>.microtask(
      () => messenger.open(gameId: widget.gameId, userId: uid),
    );
  }

  @override
  void dispose() {
    _chat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MafiaProvider>();
    final game = state.game;
    final uid = context.watch<AuthProvider>().currentUser?.id;
    return Scaffold(
      appBar: AppBar(title: const Text('Mafia')),
      body: PubgetLoadingStateView(
        state: state.state,
        onRetry: uid == null
            ? null
            : () => context.read<MafiaProvider>().open(
                gameId: widget.gameId,
                userId: uid,
              ),
        empty: const PubgetEmptyState(
          title: GameStrings.missing,
          message: GameStrings.missing,
        ),
        error: PubgetErrorState(
          title: 'Could not load Mafia',
          message: state.failure?.message ?? 'Please try again.',
          onRetry: uid == null
              ? null
              : () => context.read<MafiaProvider>().open(
                  gameId: widget.gameId,
                  userId: uid,
                ),
        ),
        child: game == null
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: <Widget>[
                  _LobbyHeader(game: game),
                  const SizedBox(height: AppSpacing.md),
                  _PlayerStrip(players: state.players, userId: uid),
                  const SizedBox(height: AppSpacing.md),
                  if (game.isLobby) _LobbyActions(game: game, userId: uid),
                  if (!game.isLobby && !game.isFinished)
                    _PlayActions(game: game, userId: uid),
                  if (game.isFinished) _Result(game: game),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Events', style: Theme.of(context).textTheme.titleMedium),
                  for (final event in state.events.take(8))
                    ListTile(
                      dense: true,
                      title: Text(event['message'] as String? ?? event['type'] as String? ?? ''),
                    ),
                  if (_canChat(game, state.self)) ...[
                    PubgetTextField(controller: _chat, label: 'Discussion'),
                    PubgetSecondaryButton(
                      onPressed: state.busy
                          ? null
                          : () {
                              context.read<MafiaProvider>().sendChat(_chat.text);
                              _chat.clear();
                            },
                      semanticLabel: 'Send',
                      child: const Text('Send'),
                    ),
                    for (final line in state.chat.take(12))
                      Text('${line['sender']}: ${line['text']}'),
                  ],
                  if (state.failure != null) Text(state.failure!.message),
                ],
              ),
      ),
    );
  }

  bool _canChat(MafiaGame game, MafiaPlayer? self) {
    return self != null &&
        self.isAlive &&
        self.canSpeak &&
        (game.currentPhase == 'day' ||
            game.currentPhase == 'discussion' ||
            game.currentPhase == 'voting');
  }
}

class _LobbyHeader extends StatelessWidget {
  const _LobbyHeader({required this.game});

  final MafiaGame game;

  @override
  Widget build(BuildContext context) {
    return PubgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Mafia', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text('Phase: ${game.currentPhase}'),
          Text('${game.playersCount}/${game.maxPlayers} players · min ${game.minPlayers}'),
          GameDeadlineTimer(deadlineAt: game.phaseEndsAt ?? game.countdownEndsAt),
        ],
      ),
    );
  }
}

class _PlayerStrip extends StatelessWidget {
  const _PlayerStrip({required this.players, required this.userId});

  final List<MafiaPlayer> players;
  final String? userId;

  @override
  Widget build(BuildContext context) {
    final private = context.watch<MafiaProvider>().privateState;
    return PubgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (userId != null && private.assigned)
            Text('Your role: ${private.role} · ${private.team}'),
          const SizedBox(height: AppSpacing.sm),
          for (final player in players)
            ListTile(
              dense: true,
              leading: Icon(
                player.isAlive ? Icons.person_outline : Icons.person_off_outlined,
              ),
              title: Text(player.username),
              subtitle: Text(
                [
                  if (!player.isAlive) 'eliminated',
                  if (player.isDisconnected) 'away',
                  if (player.userId == userId) 'you',
                ].join(' · '),
              ),
            ),
        ],
      ),
    );
  }
}

class _LobbyActions extends StatelessWidget {
  const _LobbyActions({required this.game, required this.userId});

  final MafiaGame game;
  final String? userId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MafiaProvider>();
    final joined = provider.players.any((item) => item.userId == userId);
    final canStart = userId == game.createdBy &&
        game.playersCount >= game.minPlayers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (!joined)
          PubgetPrimaryButton(
            onPressed: provider.busy ? null : () => provider.join(),
            semanticLabel: GameStrings.join,
            child: const Text(GameStrings.join),
          ),
        if (userId == game.createdBy)
          PubgetPrimaryButton(
            onPressed: provider.busy || !canStart ? null : () => provider.start(),
            semanticLabel: GameStrings.start,
            child: const Text(GameStrings.start),
          ),
        if (userId == game.createdBy && !canStart)
          Text(
            'Need ${game.minPlayers} players to start. ${game.playersCount} joined.',
          ),
      ],
    );
  }
}

class _PlayActions extends StatelessWidget {
  const _PlayActions({required this.game, required this.userId});

  final MafiaGame game;
  final String? userId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MafiaProvider>();
    final self = provider.self;
    final alive = provider.players.where((item) => item.isAlive && !item.hasLeft);
    if (self == null || !self.isAlive) {
      return const Text('You are spectating.');
    }
    if (game.currentPhase == 'night' && self.canUseAbility) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Choose a night target. The server validates your role.'),
          for (final player in alive)
            if (player.userId != userId)
              ListTile(
                title: Text(player.username),
                onTap: provider.busy
                    ? null
                    : () => provider.nightAction(player.userId),
              ),
        ],
      );
    }
    if (game.currentPhase == 'voting' && self.canVote) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Vote. Ties spare everyone.'),
          for (final player in alive)
            if (player.userId != userId)
              ListTile(
                title: Text(player.username),
                onTap: provider.busy ? null : () => provider.vote(player.userId),
              ),
        ],
      );
    }
    return Text('Current phase: ${game.currentPhase}');
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.game});

  final MafiaGame game;

  @override
  Widget build(BuildContext context) {
    final label = switch (game.winner) {
      'mafias' => 'Mafia wins',
      'citizens' => 'Town wins',
      _ => 'Game over',
    };
    return PubgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          PubgetSecondaryButton(
            onPressed: game.groupId.isEmpty
                ? null
                : () => GameLinks.openCreate(context, groupId: game.groupId),
            semanticLabel: GameStrings.playAgain,
            child: const Text(GameStrings.playAgain),
          ),
        ],
      ),
    );
  }
}
