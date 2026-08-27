// lib/widgets/mafia/mafia_chat_bubble.dart
//
// نسخة مبسّطة بنفس روح MessageBubble البصرية (ألوان، ظلال، شكل
// الفقاعة، الأفاتار) لكن بدون رد/تفاعلات/تعديل — هذي الميزات غير
// موجودة في MafiaChatMessageModel حالياً (قرار نطاق مقصود لتفادي
// تضخيم موديل المافيا الآن؛ يمكن توسعتها لاحقاً كمرحلة منفصلة).

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/time_utils.dart';
import '../../models/mafia/mafia_chat_message_model.dart';

class MafiaChatBubble extends StatelessWidget {
  final MafiaChatMessageModel message;
  final bool isMe;

  const MafiaChatBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (message.type == 'system') {
      return _buildSystemBubble(isDark);
    }

    final bubbleColor = isMe
        ? AppColors.myMessageBubble
        : (isDark ? AppColors.otherMessageBubbleDark : AppColors.otherMessageBubbleLight);
    final textColor = isMe ? Colors.white : (isDark ? Colors.white : const Color(0xFF1A1A1A));
    final timeColor = isMe ? Colors.white.withOpacity(0.8) : (isDark ? Colors.white70 : Colors.black54);

    final borderRadius = isMe
        ? const BorderRadius.only(
            topLeft: Radius.circular(16), topRight: Radius.circular(4),
            bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16))
        : const BorderRadius.only(
            topLeft: Radius.circular(4), topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) _buildAvatar(),
          if (!isMe) const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: borderRadius,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isMe) ...[
                    Text(message.sender,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    const SizedBox(height: 3),
                  ],
                  Text(message.text,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(fontSize: 15, color: textColor, height: 1.3)),
                  const SizedBox(height: 4),
                  Text(TimeUtils.formatChatTime(message.time),
                      style: TextStyle(fontSize: 10.5, color: timeColor)),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
          if (isMe) _buildAvatar(),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 16,
      backgroundColor: AppColors.primary.withOpacity(0.12),
      backgroundImage: message.senderAvatar.isNotEmpty ? NetworkImage(message.senderAvatar) : null,
      child: message.senderAvatar.isEmpty ? const Icon(Icons.person, size: 16, color: AppColors.primary) : null,
    );
  }

  Widget _buildSystemBubble(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      child: Row(
        children: [
          Expanded(child: Divider(color: isDark ? Colors.white12 : Colors.black12)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.goldAccent.withOpacity(isDark ? 0.15 : 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.goldAccent.withOpacity(0.3)),
            ),
            child: Text(message.text,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black54)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: isDark ? Colors.white12 : Colors.black12)),
        ],
      ),
    );
  }
}