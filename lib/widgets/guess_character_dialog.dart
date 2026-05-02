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
      // ✅ [تعديل] استخدم searchCharacterMultiple بدل getCharacterDetails
      final results = await AnimeApiService.searchCharacterMultiple(
        animeIds: [], // بحث عالمي
        characterName: _controller.text.trim(),
      );

      if (results.isEmpty) {
        setState(() => _errorMessage = "لم يتم العثور على الشخصية في MAL.");
      } else if (results.length == 1) {
        // نتيجة واحدة - اخترها مباشرة
        setState(() {
          _foundCharacterName = results[0]['name'];
          _foundImageUrl = results[0]['imageUrl'];
        });
      } else {
        // ✅ [تعديل] عدة نتائج - اعرض Bottom Sheet للاختيار
        _showCharacterSelectionSheet(results);
      }
    } catch (e) {
      setState(() => _errorMessage = "حدث خطأ أثناء الاتصال بالسيرفر.");
    } finally {
      setState(() => _isChecking = false);
    }
  }

  // ✅ [تعديل] Bottom Sheet لعرض قائمة الشخصيات
  void _showCharacterSelectionSheet(List<Map<String, String>> characters) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.person_search, color: Colors.indigo),
                    SizedBox(width: 8),
                    Text(
                      'اختر الشخصية الصحيحة',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'وجدنا عدة شخصيات بهذا الاسم، اختر الشخصية التي تريد تخمينها',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              const Divider(height: 24),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: characters.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final char = characters[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: char['imageUrl']!= null && char['imageUrl']!.isNotEmpty
                           ? Image.network(
                                char['imageUrl']!,
                                width: 50,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 50,
                                  height: 60,
                                  color: Colors.grey.shade300,
                                  child: const Icon(Icons.person),
                                ),
                              )
                            : Container(
                                width: 50,
                                height: 60,
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.person),
                              ),
                      ),
                      title: Text(
                        char['name']?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: const Icon(Icons.check_circle_outline, color: Colors.indigo),
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _foundCharacterName = char['name'];
                          _foundImageUrl = char['imageUrl'];
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
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
          if (_errorMessage!= null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 11)),
            ),

          // عرض نتيجة البحث للتأكيد البصري
          if (_foundImageUrl!= null)...[
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
          onPressed: _foundCharacterName == null? null : _submitGuess,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: const Text("تأكيد التخمين النهائي", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}