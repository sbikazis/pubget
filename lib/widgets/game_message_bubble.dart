import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/message_model.dart';
import '../models/member_model.dart';
import '../providers/game_provider.dart';
import '../core/constants/game_status.dart';
import '../core/utils/time_utils.dart';
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

  Color _getStatusColor() {
    if (message.isRead) {
      return Colors.green;
    } else if (message.isDelivered) {
      return Colors.yellow;
    } else {
      return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMe = message.senderId == currentMember.userId;
    final bool isSlotOne = message.gameSlot == 'game_1';
    final Color gameColor = isSlotOne ? const Color(0xFFFFD700) : const Color(0xFFC0C0C0);
    final Color textColor = Colors.black87;

    return StreamBuilder(
      stream: context.read<GameProvider>().streamCurrentGame(groupId, message.gameId ?? ''),
      builder: (context, snapshot) {
        final game = snapshot.data;
        
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: gameColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: gameColor, width: 2),
            boxShadow: [
              BoxShadow(color: gameColor.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: gameColor.withValues(alpha: 0.8)),
                  ),
                ],
              ),
              const Divider(height: 20),

              _buildMessageContent(message, gameColor),

              // ✅ التعديل الجديد - الزر يختفي إلا كانت الغرفة خاوية
              if (message.gameAction == 'challenge' && 
                  game != null && 
                  game.status.canAcceptOpponent && 
                  game.playerTwoId == null)
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

              const SizedBox(height: 8),

              Align(
                alignment: Alignment.bottomLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      TimeUtils.formatChatTime(message.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.done,
                        size: 15,
                        color: _getStatusColor(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageContent(MessageModel msg, Color accentColor) {
    String text = "";
    IconData icon = Icons.info;

    switch (msg.gameAction) {
      case 'challenge':
        text = "أرسل طلب تحدي جديد! من يجرؤ على المواجهة؟";
        icon = Icons.bolt;
        break;
      case 'join':
        text = "دخل الحلبة الآن! بدأت مرحلة التجهيز...";
        icon = Icons.handshake;
        break;
      case 'guess':
        text = msg.text ?? "${msg.senderName} حاول التخمين...";
        icon = Icons.search;
        break;
      case 'win':
        text = msg.text ?? "فوز مستحق!";
        icon = Icons.emoji_events;
        break;
      case 'quit':
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
            style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.black87),
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
        gameId: message.gameId,
      ),
    );
  }
}