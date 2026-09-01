import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../groups/providers/group_provider.dart';
import '../mafia/mafia_game_screen.dart';
import '../models/game_models.dart';
import '../models/game_type_registry.dart';
import '../providers/game_providers.dart';
import '../widgets/game_widgets.dart';

class GameDetailsScreen extends StatefulWidget {
  const GameDetailsScreen({required this.gameId, super.key});

  final String gameId;

  @override
  State<GameDetailsScreen> createState() => _GameDetailsScreenState();
}

class _GameDetailsScreenState extends State<GameDetailsScreen> {
  bool _opened = false;
  String? _loadedGroupId;
  String _actionType = GameActionTypes.submit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) return;
    _opened = true;
    final messenger = context.read<GameProvider>();
    Future<void>.microtask(() => messenger.open(widget.gameId));
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
        title: Text(game?.title ?? 'Game'),
        actions: [
          IconButton(
            tooltip: GameStrings.copyLink,
            onPressed: () => GameLinks.copy(context, widget.gameId),
            icon: const Icon(Icons.copy_outlined),
          ),
        ],
      ),
      body: PubgetLoadingStateView(
        state: state.state,
        onRetry: () => context.read<GameProvider>().open(widget.gameId),
        empty: const PubgetEmptyState(
          title: GameStrings.missing,
          message: GameStrings.missing,
        ),
        error: GameErrorState(
          message: state.failure?.message,
          onRetry: () => context.read<GameProvider>().open(widget.gameId),
        ),
        offline: PubgetOfflineState(
          onRetry: () => context.read<GameProvider>().open(widget.gameId),
        ),
        child: game == null
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: <Widget>[
                  GameHeader(game: game),
                  const SizedBox(height: AppSpacing.md),
                  GameResultCard(game: game),
                  const SizedBox(height: AppSpacing.md),
                  ParticipantList(participants: state.participants),
                  const SizedBox(height: AppSpacing.md),
                  if (uid != null) ..._actions(context, game, uid, canManage),
                  GameActionFeedback(message: state.actionFeedback),
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

  List<Widget> _actions(
    BuildContext context,
    PubgetGame game,
    String uid,
    bool canManage,
  ) {
    final provider = context.read<GameProvider>();
    final joined = provider.isParticipant(uid);
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
      widgets.add(
        PubgetPrimaryButton(
          onPressed: provider.busy
              ? null
              : () => provider.start(widget.gameId),
          semanticLabel: GameStrings.start,
          child: const Text(GameStrings.start),
        ),
      );
    }
    if (canManage && game.status == GameStatus.active) {
      widgets.add(
        PubgetSecondaryButton(
          onPressed: provider.busy
              ? null
              : () => provider.pause(widget.gameId),
          semanticLabel: GameStrings.pause,
          child: const Text(GameStrings.pause),
        ),
      );
    }
    if (canManage && game.status == GameStatus.paused) {
      widgets.add(
        PubgetPrimaryButton(
          onPressed: provider.busy
              ? null
              : () => provider.resume(widget.gameId),
          semanticLabel: GameStrings.resume,
          child: const Text(GameStrings.resume),
        ),
      );
    }
    if (game.isPlayable && joined) {
      widgets.add(const SizedBox(height: AppSpacing.md));
      widgets.add(
        DropdownButton<String>(
          value: _actionType,
          items: const <DropdownMenuItem<String>>[
            DropdownMenuItem(value: GameActionTypes.submit, child: Text('submit')),
            DropdownMenuItem(value: GameActionTypes.guess, child: Text('guess')),
            DropdownMenuItem(value: GameActionTypes.select, child: Text('select')),
            DropdownMenuItem(value: GameActionTypes.vote, child: Text('vote')),
            DropdownMenuItem(value: GameActionTypes.choose, child: Text('choose')),
            DropdownMenuItem(value: GameActionTypes.pass, child: Text('pass')),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _actionType = value);
          },
        ),
      );
      widgets.add(
        PubgetSecondaryButton(
          onPressed: provider.busy
              ? null
              : () => provider.submitAction(
                  gameId: widget.gameId,
                  actionType: _actionType,
                ),
          semanticLabel: GameStrings.submit,
          child: const Text(GameStrings.submit),
        ),
      );
    }
    if (canManage &&
        (game.status == GameStatus.active || game.status == GameStatus.paused)) {
      widgets.add(
        PubgetSecondaryButton(
          onPressed: provider.busy ? null : () => provider.end(widget.gameId),
          semanticLabel: GameStrings.end,
          child: const Text(GameStrings.end),
        ),
      );
    }
    if (canManage && !game.isTerminal) {
      widgets.add(
        PubgetTextButton(
          onPressed: provider.busy
              ? null
              : () => provider.cancel(widget.gameId),
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
