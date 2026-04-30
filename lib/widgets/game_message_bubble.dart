import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/message_model.dart';
import '../models/member_model.dart';
import '../providers/game_provider.dart';
import '../core/constants/game_status.dart';
import 'game_info_dialog.dart';

class GameMessageBubble extends StatelessWidget {
  final MessageModel message;
  final MemberModel currentMember;
  final String groupId;

  const GameMessageBubble({
    super.key,
    required this.message,
    required this.currentMember,
    required this.groupId,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ التعديل (1): تحديد اللون بناءً على نوع الحدث (Action) بدلاً من الـ Slot فقط
    final bool isSlotOne = message.gameSlot == 'game_1';
    final Color gameColor;
    
    switch (message.gameAction) {
      case 'challenge':
        gameColor = Colors.redAccent; // أحمر للإعلان كما طلبت
        break;
      case 'win':
        gameColor = const Color(0xFFFFD700); // ذهبي للفوز
        break;
      case 'join':
        gameColor = Colors.blueAccent; // أزرق للانضمام
        break;
      case 'guess':
        gameColor = Colors.orangeAccent; // برتقالي للتخمين
        break;
      case 'quit':
        gameColor = Colors.blueGrey; // رمادي غامق للانسحاب
        break;
      default:
        gameColor = isSlotOne ? const Color(0xFFFFD700) : const Color(0xFFC0C0C0);
    }

    final Color textColor = Colors.black87;

    return StreamBuilder(
      // مراقبة حالة هذه اللعبة تحديداً لتحديث الأزرار برمجياً
      stream: context.read<GameProvider>().streamCurrentGame(groupId, message.gameId ?? ''),
      builder: (context, snapshot) {
        final game = snapshot.data;
       
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: gameColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: gameColor, width: 2),
            boxShadow: [
              BoxShadow(color: gameColor.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الرأس: أيقونة اللعبة + اسم المرسل
              Row(
                children: [
                  Icon(Icons.stars, color: gameColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    message.senderName ?? "لاعب",
                    style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                  ),
                  const Spacer(),
                  Text(
                    isSlotOne ? "التحدي الأول" : "التحدي الثاني",
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: gameColor.withOpacity(0.8)),
                  ),
                ],
              ),
              const Divider(height: 20),

              // المحتوى: نص الحدث (إعلان، فوز، انضمام)
              _buildMessageContent(message, gameColor),

              // الأزرار التفاعلية (تظهر فقط إذا كانت اللعبة تنتظر خصماً)
              if (message.gameAction == 'challenge' && game != null && game.status == GameStatus.waitingForOpponent)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gameColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _showJoinDialog(context),
                      child: const Text("قبول التحدي وانضمام", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // 💬 بناء نص الرسالة بناءً على نوع الحدث
  // ==========================================
  Widget _buildMessageContent(MessageModel msg, Color accentColor) {
    String text = "";
    IconData icon = Icons.info;

    // ✅ التعديل (4): إعطاء الأولوية للنص القادم من السيرفر (msg.text) لعرض التفاصيل
    switch (msg.gameAction) {
      case 'challenge':
        text = msg.text ?? "أرسل طلب تحدي جديد! من يجرؤ على المواجهة؟";
        icon = Icons.bolt;
        break;
      case 'join':
        text = msg.text ?? "دخل الحلبة الآن! بدأت مرحلة التجهيز...";
        icon = Icons.handshake;
        break;
      case 'guess':
        // هنا سيعرض: "فلان خمن 'شخصية' وهي خاطئة" كما تم برمجتها في الـ Provider
        text = msg.text ?? "${msg.senderName} حاول التخمين...";
        icon = Icons.search;
        break;
      case 'win':
        // هنا سيعرض التفاصيل الكاملة: الفائز، الخاسر، والسبب
        text = msg.text ?? "فوز مستحق!";
        icon = Icons.emoji_events;
        break;
      case 'quit':
        // هنا سيعرض تفاصيل الانسحاب ومن الفائز بالتبعية
        text = msg.text ?? "انسحاب";
        icon = Icons.directions_run;
        break;
      default:
        text = msg.text ?? "";
    }

    return Row(
      children: [
        Icon(icon, size: 30, color: accentColor),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
        ),
      ],
    );
  }

  void _showJoinDialog(BuildContext context) {
    if (message.senderId == currentMember.userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("لا يمكنك تحدي نفسك! انتظر خصماً.")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => GameInfoDialog(
        groupId: groupId,
        currentMember: currentMember,
        gameId: message.gameId, // تمرير الـ ID يحول الديالوج لوضع الانضمام
      ),
    );
  }
}
