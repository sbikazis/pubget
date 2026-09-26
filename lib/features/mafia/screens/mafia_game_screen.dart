import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../games/models/game_type_registry.dart';
import '../../games/widgets/game_play_panels.dart';
import '../../games/widgets/game_widgets.dart';
import '../models/mafia_leave_copy.dart';
import '../models/mafia_models.dart';
import '../providers/mafia_provider.dart';

/// Master Spec 13.3: only these five roles exist. `canUseAbility` is true for
/// every living player, so the night UI has to gate on the role itself —
/// otherwise a Citizen is offered a night action the server will reject.
const Set<String> _abilityRoles = <String>{
  'mafia',
  'don',
  'detective',
  'doctor',
};

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
  final _mafiaChat = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.read<AuthProvider>().currentUser?.id;
    if (uid == null) return;
    if (_opened && _openedForUser == uid) return;
    _opened = true;
    _openedForUser = uid;
    _mafiaChat.addListener(_refresh);
    final messenger = context.read<MafiaProvider>();
    Future<void>.microtask(
      () => messenger.open(gameId: widget.gameId, userId: uid),
    );
  }

  @override
  void dispose() {
    _mafiaChat.removeListener(_refresh);
    _chat.dispose();
    _mafiaChat.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final state = context.watch<MafiaProvider>();
    final game = state.game;
    final uid = context.watch<AuthProvider>().currentUser?.id;
    final canLeave =
        game != null &&
        game.canLeaveViaServer &&
        state.self != null &&
        !state.self!.hasLeft;
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(copy.mafiaTitle),
        actions: <Widget>[
          if (canLeave)
            TextButton(
              onPressed: state.busy
                  ? null
                  : () => _confirmLeave(context, game.status),
              child: Text(copy.mafiaLeave),
            ),
        ],
      ),
      body: PubgetLoadingStateView(
        state: state.state,
        onRetry: uid == null
            ? null
            : () => context.read<MafiaProvider>().open(
                gameId: widget.gameId,
                userId: uid,
              ),
        empty: PubgetEmptyState(
          title: GameStrings.missing,
          message: GameStrings.missing,
        ),
        error: PubgetErrorState(
          title: copy.mafiaCouldNotLoad,
          message: state.failure?.message ?? copy.tryLoadingProfileAgain,
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
                  if (game.isFinished)
                    _Result(game: game, players: state.players),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    copy.mafiaLog,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final event in state.events.take(8))
                    ListTile(
                      dense: true,
                      title: Text(
                        event['message'] as String? ??
                            event['type'] as String? ??
                            '',
                      ),
                    ),
                  if (_canChat(game, state.self)) ...<Widget>[
                    PubgetTextField(
                      controller: _chat,
                      label: copy.mafiaDiscussionLabel,
                    ),
                    PubgetSecondaryButton(
                      onPressed: state.busy || _chat.text.trim().isEmpty
                          ? null
                          : () {
                              context.read<MafiaProvider>().sendChat(
                                _chat.text,
                              );
                              _chat.clear();
                            },
                      semanticLabel: copy.mafiaLastWordsSend,
                      child: Text(copy.mafiaLastWordsSend),
                    ),
                    for (final line in state.chat.take(12))
                      Text('${line['sender']}: ${line['text']}'),
                  ],
                  if (state.privateState.assigned &&
                      state.privateState.team == 'mafias') ...<Widget>[
                    const Divider(),
                    Text(copy.mafiaSecretChannel),
                    PubgetTextField(
                      controller: _mafiaChat,
                      label: copy.mafiaSecretMessage,
                    ),
                    PubgetSecondaryButton(
                      onPressed: state.busy || _mafiaChat.text.trim().isEmpty
                          ? null
                          : () {
                              context.read<MafiaProvider>().sendMafiaMessage(
                                _mafiaChat.text,
                              );
                              _mafiaChat.clear();
                            },
                      semanticLabel: copy.mafiaSendSecretSemantic,
                      child: Text(copy.mafiaLastWordsSend),
                    ),
                    for (final line in state.mafiaChat.take(12))
                      Text('${line['senderId']}: ${line['text']}'),
                  ],
                  if (state.failure != null) Text(state.failure!.message),
                ],
              ),
      ),
    );
  }

  Future<void> _confirmLeave(BuildContext context, String status) async {
    final copy = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(copy.mafiaLeaveTitle),
          content: Text(copy.mafiaLeaveBodyFor(status)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(copy.mafiaLeaveStay),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(copy.mafiaLeaveConfirm),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<MafiaProvider>().leave();
  }

  bool _canChat(MafiaGame game, MafiaPlayer? self) {
    return self != null &&
        self.isAlive &&
        self.canSpeak &&
        (game.currentPhase == 'DAY' ||
            game.currentPhase == 'DISCUSSION' ||
            game.currentPhase == 'VOTING');
  }
}

class _LobbyHeader extends StatelessWidget {
  const _LobbyHeader({required this.game});

  final MafiaGame game;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    return PubgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(copy.mafiaTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            copy.mafiaPhaseLabel(game.currentPhase),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            copy.mafiaRosterCount(
              game.playersCount,
              game.maxPlayers,
              game.minPlayers,
            ),
          ),
          GameDeadlineTimer(
            deadlineAt:
                game.serverEndsAt ?? game.phaseEndsAt ?? game.countdownEndsAt,
          ),
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
    final copy = AppStrings.of(context);
    final private = context.watch<MafiaProvider>().privateState;
    final finished = context.watch<MafiaProvider>().game?.isFinished ?? false;
    return PubgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (userId != null && private.assigned)
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: ListTile(
                title: Text(
                  copy.mafiaYourRole(copy.mafiaRoleLabel(private.role)),
                ),
                subtitle: Text(
                  copy.mafiaYourTeam(
                    private.team == 'mafias'
                        ? copy.mafiaTeamMafia
                        : copy.mafiaTeamTown,
                  ),
                ),
                leading: const Icon(Icons.shield_outlined),
              ),
            ),
          if (private.mafiaTeammateIds.isNotEmpty)
            Text(copy.mafiaTeammates(private.mafiaTeammateIds.join(', '))),
          if (private.lastInvestigationResult != null)
            Text(
              copy.mafiaInvestigationResult(
                private.lastInvestigationResult!['result'] as String? ?? '',
              ),
            ),
          if (private.lastDonInvestigationResult != null)
            Text(
              copy.mafiaDonResult(
                private.lastDonInvestigationResult!['result'] as String? ?? '',
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          for (final player in players)
            ListTile(
              dense: true,
              leading: Icon(
                player.isAlive
                    ? Icons.person_outline
                    : Icons.person_off_outlined,
              ),
              title: Text(player.username),
              subtitle: Text(
                <String>[
                  if (!player.isAlive) copy.mafiaEliminated,
                  if (player.isDisconnected) copy.mafiaDisconnected,
                  if (player.userId == userId) copy.mafiaYou,
                  // Master Spec 13.10: the board is public once the game ends.
                  if (finished && player.role != null)
                    copy.mafiaRoleLabel(player.role!),
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
    final copy = AppStrings.of(context);
    final provider = context.watch<MafiaProvider>();
    final joined = provider.players.any((item) => item.userId == userId);
    final canStart =
        userId == game.createdBy && game.playersCount >= game.minPlayers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (!joined)
          PubgetPrimaryButton(
            onPressed: provider.busy ? null : () => provider.join(),
            semanticLabel: copy.mafiaJoin,
            child: Text(copy.mafiaJoin),
          ),
        if (userId == game.createdBy)
          PubgetPrimaryButton(
            onPressed: provider.busy || !canStart
                ? null
                : () => provider.start(),
            semanticLabel: copy.mafiaStartSemantic,
            child: Text(copy.mafiaStart),
          ),
        if (userId == game.createdBy && !canStart)
          Text(copy.mafiaNeedMorePlayers(game.minPlayers, game.playersCount)),
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
    final copy = AppStrings.of(context);
    final provider = context.watch<MafiaProvider>();
    final self = provider.self;
    final alive = provider.players
        .where((item) => item.isAlive && !item.hasLeft)
        .toList(growable: false);
    if (self == null || !self.isAlive) {
      if (self != null && !self.isAlive && !self.hasLeft) {
        return _LastWordsPanel(player: self);
      }
      return Text(copy.mafiaYouAreSpectator);
    }
    if (game.currentPhase == 'DISCUSSION') {
      final isTurn = game.currentSpeakerId == userId;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(isTurn ? copy.mafiaYourTurn : copy.mafiaWaitingForSpeaker),
          if (isTurn)
            PubgetPrimaryButton(
              onPressed: provider.busy ? null : () => provider.endTurn(),
              semanticLabel: copy.mafiaEndTurnSemantic,
              child: Text(copy.mafiaEndTurn),
            ),
        ],
      );
    }
    if (game.currentPhase == 'NIGHT' &&
        self.canUseAbility &&
        _abilityRoles.contains(provider.privateState.role)) {
      final role = provider.privateState.role;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(copy.mafiaNightAbility(copy.mafiaRoleLabel(role))),
          for (final player in alive)
            if (player.userId != userId || role == 'doctor')
              Builder(
                builder: (context) {
                  // Master Spec 13.3: the Doctor may protect anyone, including
                  // themselves, but never the same player two nights running.
                  final blocked =
                      role == 'doctor' &&
                      provider.privateState.lastDoctorTargetId == player.userId;
                  return ListTile(
                    title: Text(player.username),
                    subtitle: blocked ? Text(copy.mafiaDoctorSameTarget) : null,
                    enabled: !provider.busy && !blocked,
                    onTap: provider.busy || blocked
                        ? null
                        : () => provider.nightAction(player.userId),
                  );
                },
              ),
        ],
      );
    }
    if (game.currentPhase == 'VOTING' && self.canVote) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            game.revoteCandidates.isNotEmpty
                ? copy.mafiaSecretVoteRevote
                : copy.mafiaSecretVote,
          ),
          for (final player in alive)
            if (player.userId != userId &&
                (game.revoteCandidates.isEmpty ||
                    game.revoteCandidates.contains(player.userId)))
              ListTile(
                title: Text(player.username),
                onTap: provider.busy
                    ? null
                    : () => provider.vote(player.userId),
              ),
        ],
      );
    }
    return Text(copy.mafiaPhaseLabel(game.currentPhase));
  }
}

class _LastWordsPanel extends StatefulWidget {
  const _LastWordsPanel({required this.player});

  final MafiaPlayer player;

  @override
  State<_LastWordsPanel> createState() => _LastWordsPanelState();
}

class _LastWordsPanelState extends State<_LastWordsPanel> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final provider = context.watch<MafiaProvider>();
    final player = provider.self ?? widget.player;
    final spoken = player.lastWords;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(copy.mafiaLastWordsIntro),
        // The server closes last words after one submission, so the input is
        // replaced by the text rather than left there to fail a second time.
        if (spoken != null && spoken.isNotEmpty)
          Text('${copy.mafiaLastWordsSpoken}$spoken')
        else if (player.canSayLastWords) ...<Widget>[
          PubgetTextField(
            controller: _controller,
            label: copy.mafiaLastWordsLabel,
          ),
          PubgetSecondaryButton(
            onPressed: provider.busy || _controller.text.trim().isEmpty
                ? null
                : () => provider.submitLastWords(_controller.text.trim()),
            semanticLabel: copy.mafiaLastWordsSendSemantic,
            child: Text(copy.mafiaLastWordsSend),
          ),
        ],
      ],
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.game, required this.players});

  final MafiaGame game;
  final List<MafiaPlayer> players;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final label = switch (game.winner) {
      'mafias' => copy.mafiaMafiaWon,
      'citizens' => copy.mafiaTownWon,
      _ => copy.mafiaGameEnded,
    };
    return PubgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          // Master Spec 13.10: the final reveal. Every role is public now, so
          // the board is spelled out instead of only announced in the log.
          for (final player in players)
            if (player.role != null)
              ListTile(
                dense: true,
                title: Text(player.username),
                trailing: Text(copy.mafiaRoleLabel(player.role!)),
              ),
          const SizedBox(height: AppSpacing.sm),
          PubgetSecondaryButton(
            onPressed: game.groupId.isEmpty
                ? null
                : () => GameLinks.openCreate(context, groupId: game.groupId),
            semanticLabel: GameStrings.playAgain,
            child: Text(copy.mafiaPlayAgain),
          ),
        ],
      ),
    );
  }
}
