// lib/features/groups/events/mafia_game_screen.dart
//
// ✅ إعادة هيكلة كاملة: الدردشة تملأ الشاشة تقريباً (MafiaChatBubble)،
// شريط مرحلة مضغوط أعلى الشاشة، لاعبون/أحداث في DraggableScrollableSheet
// طافٍ فوق الدردشة (Stack) بدل Row مقسوم بمساحات ثابتة ضيقة. اللوبي
// (waiting/starting) لم يعد جزءاً من هذه الشاشة إطلاقاً.
//
// ⚠️ إضافة خارج نطاق الملفات المخطط لها صراحة: أضفت شريط إدخال
// دردشة بسيط هنا (نص فقط) لأنه لم يكن موجوداً أصلاً لدردشة المافيا —
// كان يوجد فقط عرض بلا إرسال فعلي بواجهة مخصصة.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../widgets/mafia/mafia_phase_banner.dart';
import '../../../widgets/mafia/mafia_chat_bubble.dart';
import '../../../widgets/mafia/mafia_players_events_sheet.dart';
import '../../../widgets/mafia/night_action_sheet.dart';
import '../../../widgets/mafia/voting_sheet.dart';
import '../../../widgets/mafia/mafia_game_finished_sheet.dart';
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

  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

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
    _chatController.dispose();
    _chatScrollController.dispose();
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

  Future<void> _sendChatMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    final user = context.read<UserProvider>().currentUser;
    if (user == null) return;

    _chatController.clear();
    setState(() {});

    await context.read<MafiaGameProvider>().sendGameChatMessage(
          gameId: widget.gameId,
          senderId: user.id,
          senderName: user.username,
          text: text,
          senderAvatar: user.avatarUrl,
        );

    if (_chatScrollController.hasClients) {
      _chatScrollController.animateTo(0,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
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

        final canSendChat = currentPlayer != null &&
            !currentPlayer.hasLeft &&
            currentPlayer.canSpeak;

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
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: MafiaPhaseBanner(game: game),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _buildChatList(chatMessages, currentUserId, isDark),
                      ),
                      MafiaPlayersEventsSheet(
                        players: players,
                        events: events,
                        currentUserId: currentUserId,
                      ),
                    ],
                  ),
                ),
                _buildChatInput(isDark, canSendChat),
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

  Widget _buildChatList(
    List<MafiaChatMessageModel> messages,
    String currentUserId,
    bool isDark,
  ) {
    if (messages.isEmpty) {
      return Center(
        child: Text('لا توجد رسائل بعد — ابدأ النقاش!',
            style: TextStyle(color: isDark ? Colors.white38 : Colors.black38)),
      );
    }
    return ListView.builder(
      controller: _chatScrollController,
      reverse: true,
      padding: const EdgeInsets.only(top: 8, bottom: 90),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[messages.length - 1 - index];
        return MafiaChatBubble(
          message: message,
          isMe: message.senderId == currentUserId,
        );
      },
    );
  }

  Widget _buildChatInput(bool isDark, bool canSend) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: TextField(
                  controller: _chatController,
                  enabled: canSend,
                  minLines: 1,
                  maxLines: 4,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: canSend ? 'اكتب رسالتك...' : 'لا يمكنك الكتابة الآن',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white),
                onPressed: (canSend && _chatController.text.trim().isNotEmpty)
                    ? _sendChatMessage
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}