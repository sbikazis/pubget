import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/network_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../groups/providers/group_provider.dart';
import '../models/game_models.dart';
import '../models/game_type_registry.dart';
import '../providers/game_providers.dart';
import '../widgets/game_widgets.dart';
import 'mafia_models.dart';
import 'mafia_phase.dart';
import 'mafia_provider.dart';
import 'mafia_roles.dart';

class MafiaGameScreen extends StatefulWidget {
  const MafiaGameScreen({required this.gameId, super.key});

  final String gameId;

  @override
  State<MafiaGameScreen> createState() => _MafiaGameScreenState();
}

class _MafiaGameScreenState extends State<MafiaGameScreen> {
  bool _opened = false;
  String? _selectedTarget;
  String? _loadedGroupId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) return;
    _opened = true;
    final uid = context.read<AuthProvider>().currentUser?.id;
    final games = context.read<GameProvider>();
    final mafia = context.read<MafiaProvider>();
    Future<void>.microtask(() async {
      await games.open(widget.gameId);
      if (uid != null) {
        await mafia.open(gameId: widget.gameId, userId: uid);
      }
    });
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
    final games = context.watch<GameProvider>();
    final mafia = context.watch<MafiaProvider>();
    final game = games.game;
    if (game != null) {
      _maybeLoadGroup(game);
      mafia.noteGame(game);
    }
    final uid = context.watch<AuthProvider>().currentUser?.id;
    final online = context.watch<NetworkService>().isOnline;
    final publicState = MafiaPublicState.fromMap(
      game?.mafia == null ? null : Map<String, Object?>.from(game!.mafia!),
    );
    final remaining = mafia.remaining(publicState);
    if (game?.status == GameStatus.active &&
        publicState.phaseEndsAt != null &&
        remaining == Duration.zero &&
        !mafia.busy) {
      Future<void>.microtask(() => mafia.advanceIfExpired(publicState));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(game?.title ?? 'Mafia'),
        actions: [
          IconButton(
            tooltip: GameStrings.copyLink,
            onPressed: () => GameLinks.copy(context, widget.gameId),
            icon: const Icon(Icons.copy_outlined),
          ),
        ],
      ),
      body: PubgetLoadingStateView(
        state: games.state,
        onRetry: () => games.open(widget.gameId),
        empty: const PubgetEmptyState(
          title: GameStrings.missing,
          message: GameStrings.missing,
        ),
        error: GameErrorState(
          message: games.failure?.message ?? mafia.failure?.message,
          onRetry: () => games.open(widget.gameId),
        ),
        offline: PubgetOfflineState(
          onRetry: () => games.open(widget.gameId),
        ),
        child: game == null
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: <Widget>[
                  GameHeader(game: game),
                  const SizedBox(height: AppSpacing.md),
                  if (!online)
                    const Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.md),
                      child: PubgetBadge(label: 'Offline'),
                    ),
                  _PhaseCard(publicState: publicState, remaining: remaining),
                  const SizedBox(height: AppSpacing.md),
                  if (mafia.role != null)
                    _RoleCard(role: mafia.role!, privateState: mafia.privateState),
                  const SizedBox(height: AppSpacing.md),
                  _PlayerBoard(
                    participants: games.participants,
                    publicState: publicState,
                    selectedId: _selectedTarget,
                    onSelect: game.status == GameStatus.active
                        ? (id) => setState(() => _selectedTarget = id)
                        : null,
                    revealRoles: game.status == GameStatus.completed
                        ? MafiaResult.fromSummary(game.result?.summary).roles
                        : const <String, String>{},
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (publicState.lastNight != null)
                    _PublicResultCard(
                      title: GameStrings.nightResult,
                      userId: publicState.lastNight!['eliminatedUserId']?.toString(),
                      saved: publicState.lastNight!['saved'] == true,
                      participants: games.participants,
                    ),
                  if (publicState.lastVote != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    _PublicResultCard(
                      title: GameStrings.voteResult,
                      userId: publicState.lastVote!['eliminatedUserId']?.toString(),
                      tied: publicState.lastVote!['tied'] == true,
                      participants: games.participants,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  if (uid != null)
                    ..._lobbyActions(context, game, uid, games, online),
                  if (game.status == GameStatus.active && uid != null)
                    _ActionPanel(
                      game: game,
                      publicState: publicState,
                      self: games.participants.cast<GameParticipant?>().firstWhere(
                        (item) => item?.userId == uid,
                        orElse: () => null,
                      ),
                      selectedTarget: _selectedTarget,
                      online: online,
                    ),
                  if (game.status == GameStatus.completed)
                    _FinalResultCard(game: game),
                  GameActionFeedback(message: mafia.feedback ?? games.actionFeedback),
                  if (mafia.failure != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(mafia.failure!.message),
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
    GameProvider provider,
    bool online,
  ) {
    final canManage =
        game.creatorId == uid ||
        context.watch<GroupProvider>().membership?.canManageGames == true;
    final joined = provider.isParticipant(uid);
    final widgets = <Widget>[];
    if (game.isJoinable && !joined) {
      widgets.add(
        PubgetPrimaryButton(
          onPressed: !online || provider.busy
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
          onPressed: !online || provider.busy
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
          onPressed: !online || provider.busy
              ? null
              : () => provider.start(widget.gameId),
          semanticLabel: GameStrings.start,
          child: const Text(GameStrings.start),
        ),
      );
    }
    if (canManage && !game.isTerminal) {
      widgets.add(
        PubgetTextButton(
          onPressed: !online || provider.busy
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

class _PhaseCard extends StatelessWidget {
  const _PhaseCard({required this.publicState, required this.remaining});

  final MafiaPublicState publicState;
  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final seconds = remaining.inSeconds;
    return PubgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Phase', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              PubgetBadge(label: publicState.phase.name),
              PubgetBadge(label: 'Round ${publicState.roundNumber}'),
              if (publicState.phaseEndsAt != null)
                PubgetBadge(label: seconds <= 0 ? 'Resolving…' : '${seconds}s'),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role, required this.privateState});

  final MafiaRole role;
  final MafiaPrivateState? privateState;

  @override
  Widget build(BuildContext context) {
    return PubgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(GameStrings.yourRole, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          PubgetBadge(label: role.name),
          if (role == MafiaRole.mafia &&
              (privateState?.teammates.isNotEmpty ?? false)) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Teammates: ${privateState!.teammates.join(', ')}'),
          ],
          if (privateState?.investigationIsMafia != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              privateState!.investigationIsMafia!
                  ? 'Investigation: that player is Mafia.'
                  : 'Investigation: that player is not Mafia.',
            ),
          ],
        ],
      ),
    );
  }
}

class _PlayerBoard extends StatelessWidget {
  const _PlayerBoard({
    required this.participants,
    required this.publicState,
    required this.revealRoles,
    this.selectedId,
    this.onSelect,
  });

  final List<GameParticipant> participants;
  final MafiaPublicState publicState;
  final Map<String, String> revealRoles;
  final String? selectedId;
  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context) {
    final people = participants.where((item) => item.isActive).toList();
    if (people.isEmpty) {
      return const PubgetEmptyState(
        title: 'No players yet',
        message: 'Join to be the first.',
      );
    }
    return PubgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Players', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (final person in people)
            ListTile(
              contentPadding: EdgeInsets.zero,
              selected: selectedId == person.userId,
              onTap: onSelect == null || !person.isAlive
                  ? null
                  : () => onSelect!(person.userId),
              leading: Icon(
                person.isAlive ? Icons.person_outline : Icons.person_off_outlined,
              ),
              title: Text(
                person.displayName.isEmpty ? person.userId : person.displayName,
              ),
              subtitle: revealRoles[person.userId] == null
                  ? null
                  : Text(revealRoles[person.userId]!),
              trailing: PubgetBadge(
                label: person.isAlive ? GameStrings.alive : GameStrings.eliminated,
              ),
            ),
        ],
      ),
    );
  }
}

class _PublicResultCard extends StatelessWidget {
  const _PublicResultCard({
    required this.title,
    required this.participants,
    this.userId,
    this.saved = false,
    this.tied = false,
  });

  final String title;
  final List<GameParticipant> participants;
  final String? userId;
  final bool saved;
  final bool tied;

  @override
  Widget build(BuildContext context) {
    String body = GameStrings.noKill;
    if (saved) body = GameStrings.saved;
    if (tied) body = 'The vote was tied. Nobody was eliminated.';
    if (userId != null && userId!.isNotEmpty) {
      final person = participants.cast<GameParticipant?>().firstWhere(
        (item) => item?.userId == userId,
        orElse: () => null,
      );
      body = '${person?.displayName ?? userId} was eliminated.';
    }
    return PubgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(body),
        ],
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.game,
    required this.publicState,
    required this.self,
    required this.selectedTarget,
    required this.online,
  });

  final PubgetGame game;
  final MafiaPublicState publicState;
  final GameParticipant? self;
  final String? selectedTarget;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final mafia = context.watch<MafiaProvider>();
    final actions = mafia.availableActionTypes(
      game: game,
      publicState: publicState,
      self: self,
    );
    if (self != null && !self!.isAlive) {
      return const PubgetCard(child: Text(GameStrings.spectating));
    }
    if (actions.isEmpty) {
      return const PubgetCard(child: Text(GameStrings.waitingNight));
    }
    final type = actions.first;
    final submitted = type == 'mafia_vote'
        ? mafia.currentVote(publicState) != null
        : mafia.hasSubmittedNight(publicState);
    final label = switch (type) {
      'mafia_kill' => GameStrings.kill,
      'mafia_investigate' => GameStrings.investigate,
      'mafia_protect' => GameStrings.protect,
      _ => GameStrings.vote,
    };
    return PubgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            selectedTarget == null
                ? GameStrings.selectTarget
                : 'Selected: $selectedTarget',
          ),
          const SizedBox(height: AppSpacing.sm),
          PubgetPrimaryButton(
            onPressed: !online ||
                    mafia.busy ||
                    mafia.pending ||
                    selectedTarget == null ||
                    (submitted && type != 'mafia_vote')
                ? null
                : () => mafia.submit(type: type, targetId: selectedTarget!),
            semanticLabel: label,
            child: Text(
              mafia.pending
                  ? 'Submitting…'
                  : (submitted && type != 'mafia_vote'
                      ? 'Submitted'
                      : label),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinalResultCard extends StatelessWidget {
  const _FinalResultCard({required this.game});

  final PubgetGame game;

  @override
  Widget build(BuildContext context) {
    final result = MafiaResult.fromSummary(game.result?.summary);
    final winner = result.winner == 'mafia'
        ? GameStrings.mafiaWins
        : GameStrings.townWins;
    return PubgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(GameStrings.resultTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(winner),
          if (result.roles.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            for (final entry in result.roles.entries)
              Text('${entry.key}: ${entry.value}'),
          ],
        ],
      ),
    );
  }
}
