import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../providers/chat_provider.dart'; // ✅ رجعه
import '../models/member_model.dart';

class GameInfoDialog extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final bool isJoining = gameId != null;

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
          onPressed: () => Navigator.pop(context),
          child: const Text("إلغاء", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => _handleConfirm(context),
          child: Text(isJoining ? "تأكيد الانضمام" : "إنشاء الآن"),
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
    final gameProv = context.read<GameProvider>();
    final chatProv = context.read<ChatProvider>(); // ✅ رجعه

    try {
      if (gameId == null) {
        // 1. إنشاء لعبة جديدة
        final newGameId = await gameProv.createGame(
          groupId: groupId,
          creatorUserId: currentMember.userId,
          creatorName: currentMember.displayName,
        );

        if (newGameId != null) {
          // ✅ رجع الإرسال عبر ChatProvider (يضيف كل الحقول المطلوبة)
          await chatProv.sendGameMessage(
            groupId: groupId,
            messageId: DateTime.now().millisecondsSinceEpoch.toString(),
            sender: currentMember,
            gameId: newGameId,
            gameAction: 'challenge',
          );
        }
      } else {
        // 2. انضمام للعبة موجودة (حماية الترانزكشن مفعلة داخل Provider)
        final slot = await gameProv.joinGame(
          groupId: groupId,
          gameId: gameId!,
          userId: currentMember.userId,
          userName: currentMember.displayName,
        );

        await chatProv.sendGameMessage(
          groupId: groupId,
          messageId: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: currentMember,
          gameId: gameId!,
          gameAction: 'join',
          gameSlot: slot,
        );
      }

      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }
}