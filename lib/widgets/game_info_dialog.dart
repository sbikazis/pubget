import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../providers/chat_provider.dart'; // ✅ رجعه
import '../models/member_model.dart';
import '../features/groups/events/guess_character_game_screen.dart';

class GameInfoDialog extends StatefulWidget {
  final String groupId;
  final MemberModel currentMember;
  final String? gameId; // إذا كان null يعني إنشاء لعبة جديدة، إذا وجد يعني انضمام

  const GameInfoDialog({
    super.key,
    required this.groupId,
    required this.currentMember,
    this.gameId,
  });

  @override
  State<GameInfoDialog> createState() => _GameInfoDialogState();
}

class _GameInfoDialogState extends State<GameInfoDialog> {
  // ✅ [تعديل 3] متغير لإخفاء الزر أثناء التنفيذ
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final bool isJoining = widget.gameId != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.videogame_asset, color: Colors.indigo),
          const SizedBox(width: 10),
          Text(isJoining ? "انضمام للتحدي" : "إنشاء تحدي جديد"),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRuleItem(Icons.psychology, "اختر شخصية أنمي موجودة في MAL بدقة."),
            _buildRuleItem(Icons.timer, "لديك 60 ثانية لاختيار الشخصية و40 ثانية لكل دور."),
            _buildRuleItem(Icons.quiz, "الأسئلة يجب أن تكون إجابتها (نعم) أو (لا) فقط."),
            _buildRuleItem(Icons.warning, "الانسحاب أو انتهاء الوقت يعني الخسارة التلقائية."),
            const Divider(),
            const Text(
              "هل أنت مستعد لبدء الملحمة؟",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          // ✅ [تعديل 3] تعطيل زر الإلغاء أثناء التنفيذ أيضاً
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text("إلغاء", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          // ✅ [تعديل 3] الزر يُعطَّل ويظهر loading أثناء التنفيذ
          onPressed: _isLoading ? null : () => _handleConfirm(context),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Text(isJoining ? "تأكيد الانضمام" : "إنشاء الآن"),
        ),
      ],
    );
  }

  Widget _buildRuleItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blueGrey),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  // ==========================================
  // ⚙️ معالجة الضغط (إنشاء أو انضمام)
  // ==========================================
  void _handleConfirm(BuildContext context) async {
    // ✅ [تعديل 3] تفعيل حالة التحميل لإخفاء الزر
    setState(() => _isLoading = true);

    final gameProv = context.read<GameProvider>();
    final chatProv = context.read<ChatProvider>(); // ✅ رجعه

    String? targetGameId = widget.gameId;

    try {
      if (widget.gameId == null) {
        // 1. إنشاء لعبة جديدة
        // ✅ [تعديل 1] createGame يُرجع الآن Map يحتوي gameId و gameSlot
        final result = await gameProv.createGame(
          groupId: widget.groupId,
          creatorUserId: widget.currentMember.userId,
          creatorName: widget.currentMember.displayName,
        );

        if (result != null) {
          final newGameId = result['gameId'] as String;
          final newGameSlot = result['gameSlot'] as String; // ✅ [تعديل 1] استخرج الـ slot

          // ✅ [تعديل 1] تمرير gameSlot لرسالة challenge لإصلاح اللون
          await chatProv.sendGameMessage(
            groupId: widget.groupId,
            messageId: DateTime.now().millisecondsSinceEpoch.toString(),
            sender: widget.currentMember,
            gameId: newGameId,
            gameAction: 'challenge',
            gameSlot: newGameSlot, // ✅ [تعديل 1] هنا كان السبب الجذري للون الرمادي
          );
          targetGameId = newGameId;
        }
      } else {
        // 2. انضمام للعبة موجودة (حماية الترانزكشن مفعلة داخل Provider)
        final slot = await gameProv.joinGame(
          groupId: widget.groupId,
          gameId: widget.gameId!,
          userId: widget.currentMember.userId,
          userName: widget.currentMember.displayName,
        );

        await chatProv.sendGameMessage(
          groupId: widget.groupId,
          messageId: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: widget.currentMember,
          gameId: widget.gameId!,
          gameAction: 'join',
          gameSlot: slot,
        );
        targetGameId = widget.gameId;
      }

      if (context.mounted && targetGameId != null) {
        // ✅ [إصلاح] إغلاق الديالوج نفسه أولاً بـ pop البسيطة
        Navigator.of(context).pop();
        await Future.delayed(const Duration(milliseconds: 100));
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (_) => GuessCharacterGameScreen(
                groupId: widget.groupId,
                gameId: targetGameId!,
                animeIds: [], // سيتم جلبه داخل الشاشة
              ),
            ),
          );
        }
      } else if (context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }
}