import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../providers/chat_provider.dart';
import '../models/game_model.dart';
import '../models/member_model.dart';
import '../core/constants/game_status.dart';
import '../core/constants/game_constants.dart'; // ✅ إضافة استيراد الثوابت
import '../core/logic/game_logic_validator.dart'; // ✅ إضافة استيراد الفحص
import '../core/utils/game_timer_manager.dart'; // ✅ إضافة استيراد العداد
import 'guess_character_dialog.dart';

class GameBottomBar extends StatefulWidget {
  final String groupId;
  final GameModel game;
  final MemberModel currentMember;

  const GameBottomBar({
    super.key,
    required this.groupId,
    required this.game,
    required this.currentMember,
  });

  @override
  State<GameBottomBar> createState() => _GameBottomBarState();
}

class _GameBottomBarState extends State<GameBottomBar> {
  final TextEditingController _controller = TextEditingController();

  // تحديد دور اللاعب الحالي
  bool get isMyTurn => widget.game.currentTurnUserId == widget.currentMember.userId;

  // ✅ تحديد نوع الدور (هل هو دور سؤال أم جواب؟)
  bool get isAnswerPhase => widget.game.lastActionType == 'question' && isMyTurn;
  bool get isQuestionPhase => widget.game.lastActionType!= 'question' && isMyTurn;

  @override
  Widget build(BuildContext context) {
    // 1. حالة الانتظار (ليس دورك)
    if (!isMyTurn) {
      return _buildWaitingBar();
    }

    // 2. حالة دور الأكشن (أنت السائل/المجيب)
    return _buildActionBar();
  }

  // ==========================================
  // 🟢 شريط الأكشن (دورك سواء سؤال أو جواب)
  // ==========================================
  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: const Border(top: BorderSide(color: Colors.black12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ✅ إضافة العداد التنازلي المرئي
          _buildTimerProgress(),

          Row(
            children: [
              // زر الانسحاب (موجود دائماً)
              IconButton(
                icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
                onPressed: () => _handleQuit(),
              ),

              // زر التخمين (مفعل فقط في دور السؤال)
              if (isQuestionPhase)
                IconButton(
                  icon: const Icon(Icons.ads_click, color: Colors.amber),
                  onPressed: () => _showGuessDialog(),
                ),

              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: isQuestionPhase
                       ? "اسأل سؤالاً (إجابته نعم/لا)..."
                        : "أجب بـ (نعم) أو (لا) فقط...",
                    hintStyle: const TextStyle(fontSize: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    fillColor: Colors.grey[200],
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                  ),
                ),
              ),

              // زر الإرسال
              IconButton(
                icon: const Icon(Icons.send, color: Colors.blue),
                onPressed: () => _handleSend(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ✅ ودجت العداد المرئي (جديد)
  Widget _buildTimerProgress() {
    return StreamBuilder<int>(
      stream: GameTimerManager.startSyncedCountdown(
        widget.game.lastActionAt?? widget.game.createdAt,
        GameConstants.turnDuration
      ),
      builder: (context, snapshot) {
        final seconds = snapshot.data?? GameConstants.turnDuration;
        final percent = seconds / GameConstants.turnDuration;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0, left: 10, right: 10),
          child: LinearProgressIndicator(
            value: percent,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              seconds < 10? Colors.red : Colors.green,
            ),
            minHeight: 2,
          ),
        );
      },
    );
  }

  // ==========================================
  // 🟡 شريط الانتظار (مجمد)
  // ==========================================
  Widget _buildWaitingBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey[100],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTimerProgress(), // حتى في الانتظار نرى عداد الخصم
          Row(
            children: [
              const Expanded(
                child: Text(
                  "بانتظار حركة الخصم... ⏳",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
                onPressed: () => _handleQuit(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ⚙️ العمليات (Logic)
  // ==========================================

  void _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // ✅ التعديل الذهبي: إذا كان دور الجواب، نتحقق عبر الـ Validator
    if (isAnswerPhase) {
      if (!GameLogicValidator.isValidGameAnswer(text)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("عذراً، يجب أن تكون الإجابة نعم أو لا فقط!"),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    // إرسال الرسالة
    await context.read<ChatProvider>().sendTextMessage(
      groupId: widget.groupId,
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
      sender: widget.currentMember,
      text: text,
      gameId: widget.game.id,
      gameSlot: widget.game.gameSlot,
    );

    // بعد الإرسال، حدث نوع الحركة
    await context.read<GameProvider>().updateLastAction(
      widget.groupId,
      widget.game.id,
      isQuestionPhase? 'question' : 'answer'
    );

    // تبديل الدور تلقائياً بعد الإرسال
    await context.read<GameProvider>().switchTurn(widget.groupId, widget.game.id);

    _controller.clear();
  }

  void _showGuessDialog() {
    showDialog(
      context: context,
      builder: (_) => GuessCharacterDialog(
        groupId: widget.groupId,
        game: widget.game,
        currentMember: widget.currentMember,
      ),
    );
  }

  void _handleQuit() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("انسحاب"),
        content: const Text("هل أنت متأكد من الانسحاب؟ ستعتبر خاسراً في هذه اللعبة."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
          TextButton(
            onPressed: () {
              context.read<GameProvider>().finishGame(
                widget.groupId,
                widget.game.id,
                winnerId: widget.game.playerOneId == widget.currentMember.userId
                   ? widget.game.playerTwoId
                    : widget.game.playerOneId,
                isCancelled: true,
                reason: "انسحاب اللاعب ${widget.currentMember.displayName}"
              );
              Navigator.pop(ctx);
            },
            child: const Text("انسحاب", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}