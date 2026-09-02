import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../groups/providers/group_provider.dart';
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
    final game = state.game;
    if (game != null) _maybeLoadGroup(game);
    final uid = context.watch<AuthProvider>().currentUser?.id;
    final spec = game == null ? null : GameTypeRegistry.of(game.type);
    final canManage =
        uid != null &&
        game != null &&
        (game.creatorId == uid ||
            context.watch<GroupProvider>().membership?.canManageGames == true);
    return Scaffold(
      appBar: AppBar(
        title: Text(game?.title ?? 'Game'),
        actions: [
          IconButton(
            tooltip: GameStrings.share,
            onPressed: () => GameLinks.share(
              context,
              widget.gameId,
              title: game?.title,
            ),
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            tooltip: GameStrings.copyLink,
            onPressed: () => GameLinks.copy(context, widget.gameId),
            icon: const Icon(Icons.copy_outlined),
          ),
        ],
      ),
      body: PubgetLoadingStateView(
        state: state.state,
        onRetry: () => context.read<GameProvider>().open(
          widget.gameId,
          userId: uid,
        ),
        empty: const PubgetEmptyState(
          title: GameStrings.missing,
          message: GameStrings.missing,
        ),
        error: GameErrorState(
          message: state.failure?.message,
          onRetry: () => context.read<GameProvider>().open(
            widget.gameId,
            userId: uid,
          ),
        ),
        offline: PubgetOfflineState(
          onRetry: () => context.read<GameProvider>().open(
            widget.gameId,
            userId: uid,
          ),
        ),
        child: game == null
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: <Widget>[
                  GameHeader(game: game),
                  const SizedBox(height: AppSpacing.sm),
                  if (spec != null)
                    Text(
                      '${spec.name} · ${game.participantsCount}/${game.configuration.maxPlayers} players'
                      ' · ${game.configuration.timerSeconds}s'
                      '${game.configuration.usesRounds ? ' · ${game.configuration.roundCount} rounds' : ''}',
                    ),
                  const SizedBox(height: AppSpacing.md),
                  ParticipantList(participants: state.participants),
                  const SizedBox(height: AppSpacing.md),
                  if (uid != null) ..._lobbyActions(context, game, uid, canManage),
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

  List<Widget> _lobbyActions(
    BuildContext context,
    PubgetGame game,
    String uid,
    bool canManage,
  ) {
    final provider = context.read<GameProvider>();
    final joined = provider.isParticipant(uid);
    final spec = GameTypeRegistry.of(game.type);
    final widgets = <Widget>[];
    if (game.isJoinable && !joined) {
      widgets.add(
        PubgetPrimaryButton(
          onPressed: provider.busy
              ? null
              : () => provider.join(widget.gameId),
          semanticLabel: GameStrings.join,
          child: const Text(GameStrings.join),
        ),
      );
    }
    if (game.isJoinable && joined && game.creatorId != uid) {
      widgets.add(
        PubgetSecondaryButton(
          onPressed: provider.busy
              ? null
              : () => provider.leave(widget.gameId),
          semanticLabel: GameStrings.leave,
          child: const Text(GameStrings.leave),
        ),
      );
    }
    if (canManage && game.status == GameStatus.waiting) {
      final canStart =
          game.participantsCount >= game.configuration.minPlayers;
      widgets.add(
        PubgetPrimaryButton(
          onPressed: provider.busy || !canStart
              ? null
              : () => provider.start(widget.gameId),
          semanticLabel: GameStrings.start,
          child: const Text(GameStrings.start),
        ),
      );
      if (!canStart) {
        widgets.add(
          Text(
            'Need ${spec.capabilities.minPlayers} players to start. '
            '${game.participantsCount} joined.',
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
                      title: const Text('Cancel this game?'),
                      content: const Text(
                        'Players will be returned to the lobby list. This cannot be undone.',
                      ),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Keep playing'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(GameStrings.cancel),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    await provider.cancel(widget.gameId);
                  }
                },
          semanticLabel: GameStrings.cancel,
          child: const Text(GameStrings.cancel),
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
