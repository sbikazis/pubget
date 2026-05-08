import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../providers/chat_provider.dart';
import '../models/member_model.dart';

class GameInfoDialog extends StatefulWidget {
  final String groupId;
  final MemberModel currentMember;
  final String? gameId;

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
          onPressed: _isLoading ? null : () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Text("إلغاء", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
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

  void _handleConfirm(BuildContext context) async {
    setState(() => _isLoading = true);
    
    final gameProv = context.read<GameProvider>();
    final chatProv = context.read<ChatProvider>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (widget.gameId == null) {
        // إنشاء
        final result = await gameProv.createGame(
          groupId: widget.groupId,
          creatorUserId: widget.currentMember.userId,
          creatorName: widget.currentMember.displayName,
        );
        if (result != null) {
          await chatProv.sendGameMessage(
            groupId: widget.groupId,
            messageId: DateTime.now().millisecondsSinceEpoch.toString(),
            sender: widget.currentMember,
            gameId: result['gameId']!,
            gameAction: 'challenge',
            gameSlot: result['gameSlot'],
          );
        }
      } else {
        // انضمام
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
      }

      // ✅ الحل: سكّر بالـ rootNavigator فقط، لا تدفع شاشة
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        messenger.showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}