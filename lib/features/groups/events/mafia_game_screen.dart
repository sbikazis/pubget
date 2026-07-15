// lib/features/groups/events/mafia_game_screen.dart
//
// ✅ تلميع شامل: خلفية متدرجة، بطاقات أحداث بأيقونات حسب النوع،
// فقاعات دردشة أنيقة، فتح تلقائي لشاشة النهاية عند status==finished.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../widgets/mafia/mafia_phase_banner.dart';
import '../../../widgets/mafia/mafia_waiting_room.dart';
import '../../../widgets/mafia/night_action_sheet.dart';
import '../../../widgets/mafia/voting_sheet.dart';
import '../../../widgets/mafia/mafia_game_finished_sheet.dart';
import '../../../models/mafia/mafia_event_model.dart';
import '../../../models/mafia/mafia_chat_message_model.dart';
import '../../../models/mafia/mafia_player_model.dart';
import '../../../models/mafia/mafia_player_private_model.dart';
import '../../../models/mafia/mafia_game_model.dart';
import '../../../core/constants/mafia_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/mafia_game_provider.dart';
import '../../../providers/user_provider.dart';

class MafiaGameScreen extends StatefulWidget {
  final String gameId;

  const MafiaGameScreen({super.key, required this.gameId});

  @override
  State<MafiaGameScreen> createState() => _MafiaGameScreenState();
}

class _MafiaGameScreenState extends State<MafiaGameScreen> {
  MafiaGameProvider? _provider;
  int? _lastNightSheetShownFor;
  int? _lastVotingSheetShownFor;
  bool _finishedSheetShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<MafiaGameProvider>();
    if (_provider != provider) {
      _provider = provider;
      provider.subscribeToGame(gameId: widget.gameId);
    }
  }

  @override
  void dispose() {
    _provider?.unsubscribe();
    super.dispose();
  }

  MafiaPlayerModel? _findCurrentPlayer(List<MafiaPlayerModel> players, String currentUserId) {
    for (final p in players) {
      if (p.id == currentUserId) return p;
    }
    return null;
  }

  void _maybeShowNightSheet({
    required MafiaGameModel game,
    required MafiaPlayerModel? currentPlayer,
    required MafiaPlayerPrivateModel? currentPlayerPrivate,
    required List<MafiaPlayerModel> players,
  }) {
    if (game.status != MafiaGameStatus.night) return;
    if (currentPlayer == null || currentPlayer.hasLeft) return;
    if (currentPlayerPrivate == null) return;
    if (_lastNightSheetShownFor == game.currentNight) return;

    _lastNightSheetShownFor = game.currentNight;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      NightActionSheet.show(
        context,
        gameId: widget.gameId,
        currentPlayer: currentPlayer,
        currentPlayerPrivate: currentPlayerPrivate,
        allPlayers: players,
      );
    });
  }

  void _maybeShowVotingSheet({
    required MafiaGameModel game,
    required MafiaPlayerModel? currentPlayer,
    required List<MafiaPlayerModel> players,
  }) {
    if (game.status != MafiaGameStatus.voting) return;
    if (currentPlayer == null || currentPlayer.hasLeft) return;
    if (_lastVotingSheetShownFor == game.currentDay) return;

    _lastVotingSheetShownFor = game.currentDay;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      VotingSheet.show(
        context,
        gameId: widget.gameId,
        currentPlayer: currentPlayer,
        allPlayers: players,
        dayNumber: game.currentDay,
      );
    });
  }

  void _maybeShowFinishedSheet(MafiaGameModel game) {
    if (game.status != MafiaGameStatus.finished) return;
    if (_finishedSheetShown) return;
    _finishedSheetShown = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      MafiaGameFinishedSheet.show(context, gameId: widget.gameId);
    });
  }

  Future<bool> _handleWillPop(MafiaPlayerModel? currentPlayer) async {
    final stillActivePlayer =
        currentPlayer != null && currentPlayer.isAlive && !currentPlayer.hasLeft;

    if (!stillActivePlayer) return true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('هل تريد الخروج؟'),
        content: const Text(
          'لا تزال على قيد الحياة في هذه المباراة. الخروج الآن سيُعتبر '
          'انسحاباً، وسيُعامَل جسدك كأنك قُتلت — ولن تتمكن من العودة كلاعب.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('البقاء في المباراة'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('الانسحاب والخروج'),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    try {
      await context.read<MafiaGameProvider>().leaveCurrentUser(gameId: widget.gameId);
    } catch (_) {}
    return true;
  }

  IconData _eventIcon(String type) {
    switch (type) {
      case 'PlayerKilled':
        return Icons.dangerous_rounded;
      case 'PlayerSaved':
        return Icons.shield_rounded;
      case 'PlayerExecuted':
        return Icons.gavel_rounded;
      case 'RolesAssigned':
        return Icons.style_rounded;
      case 'PhaseChanged':
        return Icons.autorenew_rounded;
      case 'GameFinished':
        return Icons.emoji_events_rounded;
      case 'ExecutionSkipped':
        return Icons.remove_circle_outline_rounded;
      case 'SniperMissed':
        return Icons.gps_off_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Color _eventColor(String type) {
    switch (type) {
      case 'PlayerKilled':
      case 'PlayerExecuted':
        return AppColors.error;
      case 'PlayerSaved':
        return const Color(0xFF10B981);
      case 'GameFinished':
        return AppColors.goldAccent;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.watch<UserProvider>().currentUser?.id ?? '';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<MafiaGameProvider>(
      builder: (context, provider, child) {
        final game = provider.currentGame;
        final players = provider.players;
        final myPrivateData = provider.myPrivateData;
        final events = provider.events;
        final chatMessages = provider.chatMessages;

        if (game == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final currentPlayer = _findCurrentPlayer(players, currentUserId);

        _maybeShowNightSheet(
          game: game, currentPlayer: currentPlayer,
          currentPlayerPrivate: myPrivateData, players: players,
        );
        _maybeShowVotingSheet(game: game, currentPlayer: currentPlayer, players: players);
        _maybeShowFinishedSheet(game);

        return WillPopScope(
          onWillPop: () => _handleWillPop(currentPlayer),
          child: Scaffold(
            backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
            appBar: AppBar(
              title: const Text('لعبة المافيا'),
              centerTitle: true,
              elevation: 0,
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: MafiaPhaseBanner(game: game),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12, right: 4, bottom: 12),
                          child: Column(
                            children: [
                              Expanded(
                                child: MafiaWaitingRoom(
                                  game: game, players: players, currentUserId: currentUserId,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Expanded(child: _buildEventTimeline(events, isDark)),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12, left: 4, bottom: 12),
                          child: _buildChatList(chatMessages, isDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            floatingActionButton: _buildFab(game, currentPlayer, players, myPrivateData),
          ),
        );
      },
    );
  }

  Widget? _buildFab(
    MafiaGameModel game,
    MafiaPlayerModel? currentPlayer,
    List<MafiaPlayerModel> players,
    MafiaPlayerPrivateModel? myPrivateData,
  ) {
    if (currentPlayer == null || !currentPlayer.isAlive) return null;

    if (game.status == MafiaGameStatus.night && myPrivateData != null) {
      return FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => NightActionSheet.show(
          context, gameId: widget.gameId, currentPlayer: currentPlayer,
          currentPlayerPrivate: myPrivateData, allPlayers: players,
        ),
        icon: const Icon(Icons.nightlight_round),
        label: const Text('قراري الليلي'),
      );
    }

    if (game.status == MafiaGameStatus.voting) {
      return FloatingActionButton.extended(
        backgroundColor: Colors.deepOrange,
        onPressed: () => VotingSheet.show(
          context, gameId: widget.gameId, currentPlayer: currentPlayer,
          allPlayers: players, dayNumber: game.currentDay,
        ),
        icon: const Icon(Icons.how_to_vote),
        label: const Text('صوّتي'),
      );
    }
    return null;
  }

  Widget _buildEventTimeline(List<MafiaEventModel> events, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.timeline_rounded, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            const Text('أحداث المباراة', style: TextStyle(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[events.length - 1 - index];
                final color = _eventColor(event.type);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                        child: Icon(_eventIcon(event.type), size: 14, color: color),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(event.message, style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList(List<MafiaChatMessageModel> messages, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            const Text('دردشة المافيا', style: TextStyle(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[messages.length - 1 - index];
                final isSystem = message.type == 'system';
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSystem
                        ? AppColors.goldAccent.withOpacity(0.12)
                        : AppColors.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(message.sender,
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold,
                              color: isSystem ? AppColors.goldAccent : AppColors.primary)),
                      Text(message.text, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}