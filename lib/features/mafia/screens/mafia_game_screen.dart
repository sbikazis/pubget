import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../games/models/game_type_registry.dart';
import '../../games/widgets/game_play_panels.dart';
import '../../games/widgets/game_widgets.dart';
import '../models/mafia_leave_copy.dart';
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
    final state = context.watch<MafiaProvider>();
    final game = state.game;
    final uid = context.watch<AuthProvider>().currentUser?.id;
    final canLeave = game != null &&
        !game.isFinished &&
        MafiaLeaveCopy.canLeave(game.status) &&
        state.self != null &&
        !state.self!.hasLeft;
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: const Text('مافيا'),
        actions: <Widget>[
          if (canLeave)
            TextButton(
              onPressed: state.busy
                  ? null
                  : () => _confirmLeave(context, game.status),
              child: const Text(MafiaLeaveCopy.leave),
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
        empty: const PubgetEmptyState(
          title: GameStrings.missing,
          message: GameStrings.missing,
        ),
        error: PubgetErrorState(
          title: 'تعذر تحميل المافيا',
          message: state.failure?.message ?? 'تحقق من الاتصال وحاول مجددًا.',
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
                  Text('سجل اللعبة', style: Theme.of(context).textTheme.titleMedium),
                  for (final event in state.events.take(8))
                    ListTile(
                      dense: true,
                      title: Text(event['message'] as String? ?? event['type'] as String? ?? ''),
                    ),
                  if (_canChat(game, state.self)) ...[
                    PubgetTextField(controller: _chat, label: 'النقاش'),
                    PubgetSecondaryButton(
                      onPressed: state.busy
                          ? null
                          : () {
                              context.read<MafiaProvider>().sendChat(_chat.text);
                              _chat.clear();
                            },
                      semanticLabel: 'إرسال',
                      child: const Text('إرسال'),
                    ),
                    for (final line in state.chat.take(12))
                      Text('${line['sender']}: ${line['text']}'),
                  ],
                  if (state.privateState.assigned &&
                      state.privateState.team == 'mafias') ...[
                    const Divider(),
                    const Text('القناة السرية للمافيا'),
                    PubgetTextField(controller: _mafiaChat, label: 'رسالة سرية'),
                    PubgetSecondaryButton(
                      onPressed: state.busy || _mafiaChat.text.trim().isEmpty
                          ? null
                          : () {
                              context.read<MafiaProvider>()
                                  .sendMafiaMessage(_mafiaChat.text);
                              _mafiaChat.clear();
                            },
                      semanticLabel: 'إرسال رسالة سرية',
                      child: const Text('إرسال'),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(MafiaLeaveCopy.title),
          content: Text(MafiaLeaveCopy.bodyFor(status)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(MafiaLeaveCopy.stay),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(MafiaLeaveCopy.confirm),
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
        (game.currentPhase == 'day' ||
            game.currentPhase == 'discussion' ||
            game.currentPhase == 'voting' ||
            game.currentPhase == 'revote');
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
          Text('مافيا', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(_phaseLabel(game.currentPhase),
              style: Theme.of(context).textTheme.titleMedium),
          Text('${game.playersCount}/${game.maxPlayers} لاعبين · الحد الأدنى ${game.minPlayers}'),
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
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: ListTile(
                title: Text('دورك: ${_roleLabel(private.role)}'),
                subtitle: Text(
                  'الفريق: ${private.team == 'mafias' ? 'المافيا' : 'المدينة'}',
                ),
                leading: const Icon(Icons.shield_outlined),
              ),
            ),
          if (private.mafiaTeammateIds.isNotEmpty)
            Text('زملاؤك في المافيا: ${private.mafiaTeammateIds.join('، ')}'),
          if (private.lastInvestigationResult != null)
            Text('نتيجة التحقيق: ${private.lastInvestigationResult!['result']}'),
          if (private.lastDonInvestigationResult != null)
            Text('نتيجة تحقق الدون: ${private.lastDonInvestigationResult!['result']}'),
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
                  if (!player.isAlive) 'مقصى',
                  if (player.isDisconnected) 'غير متصل',
                  if (player.userId == userId) 'أنت',
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
            semanticLabel: 'انضمام',
            child: const Text('انضمام'),
          ),
        if (userId == game.createdBy)
          PubgetPrimaryButton(
            onPressed: provider.busy || !canStart ? null : () => provider.start(),
            semanticLabel: 'بدء',
            child: const Text('بدء اللعبة'),
          ),
        if (userId == game.createdBy && !canStart)
          Text(
            'تحتاج اللعبة إلى ${game.minPlayers} لاعبين. المنضم الآن: ${game.playersCount}.',
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
      if (self != null && !self.isAlive && self.hasLeft == false) {
        return const _LastWordsPanel();
      }
      return const Text('أنت تشاهد اللعبة كمشاهد.');
    }
    if (game.currentPhase == 'discussion') {
      final isTurn = game.currentSpeakerId == userId;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(isTurn ? 'حان دورك للكلام.' : 'بانتظار دور اللاعب الحالي.'),
          if (isTurn)
            PubgetPrimaryButton(
              onPressed: provider.busy ? null : () => provider.endTurn(),
              semanticLabel: 'إنهاء الدور',
              child: const Text('إنهاء دوري'),
            ),
        ],
      );
    }
    if (game.currentPhase == 'night' && self.canUseAbility) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('قدرة ${_roleLabel(provider.privateState.role)} الليلية'),
          for (final player in alive)
            if (player.userId != userId ||
                provider.privateState.role == 'doctor')
              ListTile(
                title: Text(player.username),
                onTap: provider.busy
                    ? null
                    : () => provider.nightAction(player.userId),
              ),
        ],
      );
    }
    if ((game.currentPhase == 'voting' || game.currentPhase == 'revote') &&
        self.canVote) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            game.currentPhase == 'revote'
                ? 'إعادة تصويت سرية بين المتعادلين فقط.'
                : 'تصويت سري. لا يمكنك التصويت لنفسك.',
          ),
          for (final player in alive)
            if (player.userId != userId &&
                (game.currentPhase != 'revote' ||
                    game.revoteCandidates.contains(player.userId)))
              ListTile(
                title: Text(player.username),
                onTap: provider.busy ? null : () => provider.vote(player.userId),
              ),
        ],
      );
    }
    return Text(_phaseLabel(game.currentPhase));
  }
}

class _LastWordsPanel extends StatefulWidget {
  const _LastWordsPanel();

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
    final provider = context.watch<MafiaProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('أنت الآن مشاهد. يمكنك كتابة كلماتك الأخيرة مرة واحدة.'),
        PubgetTextField(controller: _controller, label: 'كلمات أخيرة'),
        PubgetSecondaryButton(
          onPressed: provider.busy || _controller.text.trim().isEmpty
              ? null
              : () => provider.submitLastWords(_controller.text.trim()),
          semanticLabel: 'إرسال الكلمات الأخيرة',
          child: const Text('إرسال'),
        ),
      ],
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.game});

  final MafiaGame game;

  @override
  Widget build(BuildContext context) {
    final label = switch (game.winner) {
      'mafias' => 'فازت المافيا',
      'citizens' => 'فازت المدينة',
      _ => 'انتهت اللعبة',
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
            child: const Text('العب مجددًا'),
          ),
        ],
      ),
    );
  }
}

String _phaseLabel(String phase) => switch (phase) {
      'waiting' => 'غرفة الانتظار',
      'starting' => 'جاري بدء اللعبة',
      'role_reveal' => 'كشف دورك',
      'night' => 'الليل',
      'day' => 'النهار',
      'discussion' => 'النقاش',
      'voting' => 'التصويت',
      'revote' => 'إعادة التصويت',
      'vote_result' => 'نتيجة التصويت',
      'resolution' => 'معالجة النتيجة',
      'game_over' || 'finished' => 'انتهت اللعبة',
      _ => phase,
    };

String _roleLabel(String role) => switch (role) {
      'mafia' => 'مافيا',
      'don' => 'الدون',
      'detective' => 'المحقق',
      'doctor' => 'الطبيب',
      'citizen' => 'مواطن',
      _ => role.isEmpty ? 'غير معروف' : role,
    };
