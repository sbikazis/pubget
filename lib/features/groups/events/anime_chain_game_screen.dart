import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../providers/game_provider.dart';
import '../../../models/game_model.dart';
import '../../../models/member_model.dart';
import '../../../models/message_model.dart';
import '../../../core/constants/game_status.dart';
import '../../../core/constants/firestore_paths.dart';
import 'package:pubget/widgets/game_bottom_bar.dart';

class AnimeChainGameScreen extends StatefulWidget {
  final String groupId;
  final MemberModel currentMember;
  final String? existingGameId;

  const AnimeChainGameScreen({
    super.key,
    required this.groupId,
    required this.currentMember,
    this.existingGameId,
  });

  @override
  State<AnimeChainGameScreen> createState() => _AnimeChainGameScreenState();
}

class _AnimeChainGameScreenState extends State<AnimeChainGameScreen> {
  final TextEditingController _startWordController = TextEditingController();
  String? _activeGameId;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _activeGameId = widget.existingGameId;
    if (_activeGameId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<GameProvider>().joinGame(
          groupId: widget.groupId,
          gameId: _activeGameId!,
          userId: widget.currentMember.userId,
          userName: widget.currentMember.displayName,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_activeGameId != null) {
      return StreamBuilder<GameModel?>(
        stream: context.read<GameProvider>().streamCurrentGame(widget.groupId, _activeGameId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final game = snapshot.data;
          if (game == null || game.status.isOver) {
            return _buildSetupScaffold(context);
          }
          return _buildActiveGameScaffold(context, game);
        },
      );
    }
    return _buildSetupScaffold(context);
  }

  Widget _buildSetupScaffold(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء سلسلة أنمي جديدة'), centerTitle: true),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🔗\nسلسلة كلمات الأنمي', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.5)),
                  const SizedBox(height: 12),
                  const Text('تحدى أصدقائك في المجموعة! ستقوم بكتابة اسم شخصية أو أنمي، ويجب على الخصم الإتيان باسم يبدأ بآخر حرف للكلمة السابقة قبل انتهاء الوقت!', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.4)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _startWordController,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color, // ✅ يتبدل مع الدارك
                    ),
                    decoration: InputDecoration(
                      labelText: 'كلمة البداية (مثال: Luffy)',
                      hintText: 'اكتب الإسم الأول لانطلاق السلسلة',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true, // ✅
                      fillColor: theme.cardColor, // ✅ يتبدل مع الدارك
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: _isCreating ? null : () => _handleCreateGame(),
                      child: _isCreating ? const CircularProgressIndicator(color: Colors.white) : const Text('أنشئ الغرفة وانتظر خصماً ⚔️', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveGameScaffold(BuildContext context, GameModel game) {
    final bool isMyTurn = game.currentTurnUserId == widget.currentMember.userId;
    final String opponentName = (widget.currentMember.userId == game.playerOneId)
        ? (game.playerTwoName ?? 'بانتظار انضمام خصم...')
        : (game.playerOneName ?? 'المستضيف');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ✅ التعديل - ما نخدموش التايمر إلا إلا دخل الخصم
      if (mounted && game.status == GameStatus.guessing && game.playerTwoId != null) {
        context.read<GameProvider>().processAutoJudge(widget.groupId, game);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة السلسلة الحية'),
        centerTitle: true,
        actions: [Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: Chip(avatar: const Icon(Icons.layers, size: 16, color: Colors.blue), label: Text('الكلمات: ${game.usedWords.length}')))],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            color: isMyTurn ? Colors.green.withOpacity(0.08) : Colors.amber.withOpacity(0.05),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPlayerStatusNode(widget.currentMember.displayName ?? 'لاعب مجهول', 'أنت', isMyTurn),
                const Text('VS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 16)),
                _buildPlayerStatusNode(opponentName, 'الخصم', !isMyTurn && game.status != GameStatus.waitingForOpponent),
              ],
            ),
          ),
          Expanded(
            child: game.status == GameStatus.waitingForOpponent
                ? _buildWaitingForOpponentState(game)
                : _buildGameplayCoreState(game, isMyTurn),
          ),
          GameBottomBar(groupId: widget.groupId, game: game, currentMember: widget.currentMember),
        ],
      ),
    );
  }

  Widget _buildPlayerStatusNode(String name, String role, bool isActive) {
    return Column(children: [
      Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isActive ? Colors.green : Colors.transparent, width: 3)), child: CircleAvatar(radius: 24, backgroundColor: isActive ? Colors.green[100] : Colors.grey[200], child: Icon(Icons.person, color: isActive ? Colors.green : Colors.grey))),
      const SizedBox(height: 6),
      Text(name, style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
      Text(role, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
    ]);
  }

  Widget _buildWaitingForOpponentState(GameModel game) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 24),
        const Text('تم نشر الدعوة في الشات... 📣', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('الإسم الأول: ${game.pendingStartWord ?? ''}', style: const TextStyle(color: Colors.blueAccent, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('كود الغرفة: ${game.id.substring(0, 8).toUpperCase()}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ]),
    );
  }

  Widget _buildGameplayCoreState(GameModel game, bool isMyTurn) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('آخِر إسم تَمَّ قبوله', style: TextStyle(fontSize: 13, color: Colors.grey, letterSpacing: 1.1)),
        const SizedBox(height: 8),
        Text(game.currentWord ?? '—', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.blueAccent)),
        const SizedBox(height: 32),
        const Text('الحرف المطلوب للإسم القادم هو:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 16),
        Container(width: 90, height: 90, decoration: BoxDecoration(color: isMyTurn ? Colors.green : Colors.grey[300], shape: BoxShape.circle, boxShadow: [BoxShadow(color: (isMyTurn ? Colors.green : Colors.grey).withOpacity(0.3), blurRadius: 12, spreadRadius: 4)]), child: Center(child: Text(game.lastLetter?.toUpperCase() ?? '?', style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: isMyTurn ? Colors.white : Colors.black87)))),
        const SizedBox(height: 24),
        Text(isMyTurn ? 'أسرع! دورك الآن لرمي الإسم التالي ⚔️' : 'الخصم يفكر الآن في الإسم المناسب... ⏳', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: isMyTurn ? FontWeight.bold : FontWeight.normal, color: isMyTurn ? Colors.green[700] : Colors.grey[700])),
      ]),
    );
  }

  void _handleCreateGame() async {
    final startWord = _startWordController.text.trim();
    if (startWord.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اكتب إسم البداية!'), backgroundColor: Colors.orange));
      return;
    }
    setState(() => _isCreating = true);
    try {
      final provider = context.read<GameProvider>();

      final id = await provider.createAnimeChain(
        groupId: widget.groupId,
        creatorUserId: widget.currentMember.userId,
        creatorName: widget.currentMember.displayName ?? 'مجهول',
        firstWord: startWord,
      );

      final inviteId = DateTime.now().millisecondsSinceEpoch.toString();
      final invite = MessageModel(
        id: inviteId,
        senderId: widget.currentMember.userId,
        senderName: widget.currentMember.displayName ?? '',
        senderAvatar: '',
        type: MessageType.gameInvite,
        text: 'تحداك في سلسلة الأنمي! الكلمة: $startWord',
        gameId: id,
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection(FirestorePaths.groupMessages(widget.groupId))
          .doc(inviteId)
          .set(invite.toMap());

      await FirebaseFirestore.instance
          .collection(FirestorePaths.groups)
          .doc(widget.groupId)
          .update({
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageText': '🎮 دعوة سلسلة أنمي',
      });

      setState(() => _activeGameId = id);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isCreating = false);
    }
  }

  @override
  void dispose() {
    _startWordController.dispose();
    super.dispose();
  }
}