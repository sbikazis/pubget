import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../providers/chat_provider.dart';
import '../services/api/anime_api_service.dart';
import '../models/game_model.dart';
import '../models/member_model.dart';

class GuessCharacterDialog extends StatefulWidget {
  final String groupId;
  final GameModel game;
  final MemberModel currentMember;

  const GuessCharacterDialog({
    super.key,
    required this.groupId,
    required this.game,
    required this.currentMember,
  });

  @override
  State<GuessCharacterDialog> createState() => _GuessCharacterDialogState();
}

class _GuessCharacterDialogState extends State<GuessCharacterDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _isChecking = false;
  String? _foundCharacterName;
  String? _foundImageUrl;
  String? _errorMessage;

  // ==========================================
  // 🔍 التحقق من الشخصية عبر الـ API
  // ==========================================
  Future<void> _verifyCharacter() async {
    if (_controller.text.trim().isEmpty) return;

    setState(() {
      _isChecking = true;
      _errorMessage = null;
      _foundCharacterName = null;
      _foundImageUrl = null;
    });

    try {
      // نستخدم دالة getCharacterDetails التي أضفناها لـ AnimeApiService
      final details = await AnimeApiService.getCharacterDetails(
        animeIds: [], // بحث عالمي
        characterName: _controller.text.trim(),
      );

      if (details != null) {
        setState(() {
          _foundCharacterName = details['name'];
          _foundImageUrl = details['imageUrl'];
        });
      } else {
        setState(() => _errorMessage = "لم يتم العثور على الشخصية في MAL.");
      }
    } catch (e) {
      setState(() => _errorMessage = "حدث خطأ أثناء الاتصال بالسيرفر.");
    } finally {
      setState(() => _isChecking = false);
    }
  }

  // ==========================================
  // 🏆 تنفيذ التخمين النهائي
  // ==========================================
  void _submitGuess() async {
    if (_foundCharacterName == null) return;

    final gameProv = context.read<GameProvider>();
    
    // إرسال التخمين للمرشد (Provider) للمقارنة مع شخصية الخصم
    await gameProv.guessCharacter(
      groupId: widget.groupId,
      gameId: widget.game.id,
      userId: widget.currentMember.userId,
      guessedName: _foundCharacterName!,
      userName: widget.currentMember.effectiveName,
    );

    // إرسال رسالة التخمين للدردشة
    await context.read<ChatProvider>().sendGameMessage(
      groupId: widget.groupId,
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
      sender: widget.currentMember,
      gameId: widget.game.id,
      gameSlot: widget.game.gameSlot,
      gameAction: 'guess',
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text("تخمين الشخصية", style: TextStyle(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "اكتب اسم الشخصية بالإنجليزية للتأكد من صورتها قبل إرسال التخمين النهائي.",
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: "مثلاً: Roronoa Zoro",
              suffixIcon: IconButton(
                icon: _isChecking 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.search, color: Colors.indigo),
                onPressed: _verifyCharacter,
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 11)),
            ),
          
          // عرض نتيجة البحث للتأكيد البصري
          if (_foundImageUrl != null) ...[
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(_foundImageUrl!, height: 150, fit: BoxFit.cover),
            ),
            const SizedBox(height: 8),
            Text(_foundCharacterName!, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("إلغاء"),
        ),
        ElevatedButton(
          onPressed: _foundCharacterName == null ? null : _submitGuess,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: const Text("تأكيد التخمين النهائي", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
