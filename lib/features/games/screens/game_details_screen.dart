import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../groups/providers/group_provider.dart';
import '../../mafia/screens/mafia_game_screen.dart';
import '../l10n/game_copy.dart';
import '../models/game_models.dart';
import '../models/game_type_registry.dart';
import '../providers/game_providers.dart';
import '../widgets/game_play_panels.dart';
import '../widgets/game_widgets.dart';

class GameDetailsScreen extends StatefulWidget {
  const GameDetailsScreen({required this.gameId, super.key});

  final String gameId;

  @override
  State<GameDetailsScreen> createState() => _GameDetailsScreenState();
}

class _GameDetailsScreenState extends State<GameDetailsScreen> {
  bool _opened = false;
  String? _openedForUser;
  String? _loadedGroupId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.read<AuthProvider>().currentUser?.id;
    if (_opened && _openedForUser == uid) return;
    _opened = true;
    _openedForUser = uid;
    final messenger = context.read<GameProvider>();
    Future<void>.microtask(() => messenger.open(widget.gameId, userId: uid));
  }

  void _maybeLoadGroup(PubgetGame game) {
    final groupId = game.groupId;
    final uid = context.read<AuthProvider>().currentUser?.id;
    if (groupId == null || groupId.isEmpty || uid == null) return;
    if (_loadedGroupId == groupId) return;
    _loadedGroupId = groupId;
    final groups = context.read<GroupProvider>();
    Future<void>.microtask(() => groups.load(groupId: groupId, userId: uid));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameProvider>();
    final copy = GameCopy.of(context);
    final game = state.game;
    if (game != null) _maybeLoadGroup(game);
    final uid = context.watch<AuthProvider>().currentUser?.id;
    final spec = game == null ? null : GameTypeRegistry.of(game.type);
    final canManage =
        uid != null &&
        game != null &&
        (game.creatorId == uid ||
            context.watch<GroupProvider>().membership?.canManageGames == true);
    if (game != null && game.type == GameType.mafia) {
      return MafiaGameScreen(gameId: widget.gameId);
    }
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(game?.title ?? copy.gameTitleFallback),
        actions: [
          IconButton(
            tooltip: copy.share,
            onPressed: () =>
                GameLinks.share(context, widget.gameId, title: game?.title),
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            tooltip: copy.copyLink,
            onPressed: () => GameLinks.copy(context, widget.gameId),
            icon: const Icon(Icons.copy_outlined),
          ),
        ],
      ),
      body: PubgetLoadingStateView(
        state: state.state,
        onRetry: () =>
            context.read<GameProvider>().open(widget.gameId, userId: uid),
        empty: PubgetEmptyState(
          title: copy.missing,
          message: copy.missing,
        ),
        error: GameErrorState(
          message: state.failure?.message,
          onRetry: () =>
              context.read<GameProvider>().open(widget.gameId, userId: uid),
        ),
        offline: PubgetOfflineState(
          onRetry: () =>
              context.read<GameProvider>().open(widget.gameId, userId: uid),
        ),
        child: game == null
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: <Widget>[
                  GameHeader(game: game),
                  const SizedBox(height: AppSpacing.sm),
                  if (spec != null) ...[
                    Text(_infoLine(context, game, spec)),
                    const SizedBox(height: AppSpacing.xs),
                    // The Game Center has to show each game's duration,
                    // difficulty, win condition, and type.
                    Text(
                      '${copy.difficultyTitle}: '
                      '${copy.difficulty(game.configuration.difficulty)}'
                      ' · ${copy.winCondition}: ${copy.winConditionFor(spec.type)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (game.status == GameStatus.waiting &&
                      game.waitingDeadlineAt != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    WaitingRoomCountdown(deadline: game.waitingDeadlineAt!),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  ParticipantList(participants: state.participants),
                  const SizedBox(height: AppSpacing.md),
                  if (uid != null)
                    ..._lobbyActions(context, game, uid, canManage),
                  if (uid != null && (game.isPlayable || game.isTerminal))
                    GamePlayArea(game: game, userId: uid),
                  if (state.failure != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(state.failure!.message),
                    ),
                ],
              ),
      ),
    );
  }

  /// Spec 12.1: type · players · duration · timer/rounds on one line.
  String _infoLine(BuildContext context, PubgetGame game, GameTypeSpec spec) {
    final copy = GameCopy.of(context);
    final caps = spec.capabilities;
    final players = game.configuration.maxPlayers == caps.minPlayers
        ? copy.playerCount(game.participantsCount)
        : copy.playerCountOf(game.participantsCount, game.configuration.maxPlayers);
    return '$players · ${copy.durationMinutes(spec.durationMinutes)}'
        ' · ${copy.timerSeconds(game.configuration.timerSeconds)}'
        '${game.configuration.usesRounds ? ' · ${copy.roundCount(game.configuration.roundCount)}' : ''}';
  }

  List<Widget> _lobbyActions(
    BuildContext context,
    PubgetGame game,
    String uid,
    bool canManage,
  ) {
    final provider = context.read<GameProvider>();
    final copy = GameCopy.of(context);
    final joined = provider.isParticipant(uid);
    final spec = GameTypeRegistry.of(game.type);
    final widgets = <Widget>[];
    if (game.isJoinable && !joined) {
      widgets.add(
        PubgetPrimaryButton(
          onPressed: provider.busy ? null : () => provider.join(widget.gameId),
          semanticLabel: copy.join,
          child: Text(copy.join),
        ),
      );
    }
    if (game.isJoinable && joined && game.creatorId != uid) {
      widgets.add(
        PubgetSecondaryButton(
          onPressed: provider.busy ? null : () => provider.leave(widget.gameId),
          semanticLabel: copy.leave,
          child: Text(copy.leave),
        ),
      );
    }
    if (canManage && game.status == GameStatus.waiting) {
      final canStart = game.participantsCount >= game.configuration.minPlayers;
      widgets.add(
        PubgetPrimaryButton(
          onPressed: provider.busy || !canStart
              ? null
              : () => provider.start(widget.gameId),
          semanticLabel: copy.start,
          child: Text(copy.start),
        ),
      );
      if (!canStart) {
        widgets.add(
          Text(
            copy.needPlayersToStartCount(
              spec.capabilities.minPlayers,
              game.participantsCount,
            ),
          ),
        );
      }
    }
    if (canManage && !game.isTerminal) {
      widgets.add(
        PubgetTextButton(
          onPressed: provider.busy
              ? null
              : () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(copy.cancelTitle),
                      content: Text(copy.cancelBody),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(copy.keepPlaying),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(copy.cancel),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    await provider.cancel(widget.gameId);
                  }
                },
          semanticLabel: copy.cancel,
          child: Text(copy.cancel),
        ),
      );
    }
    return [
      for (final widget in widgets) ...[
        widget,
        const SizedBox(height: AppSpacing.sm),
      ],
    ];
  }
}
