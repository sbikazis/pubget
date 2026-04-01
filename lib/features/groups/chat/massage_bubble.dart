import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/message_model.dart';
import '../../../models/member_model.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/role_colors.dart';
import '../../../core/utils/time_utils.dart';
import 'package:pubget/models/user_model.dart';
import 'package:pubget/providers/user_provider.dart';

import 'role_badge.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final MemberModel sender;

  final bool isMe;

  const MessageBubble({
    super.key,
    required this.message,
    required this.sender,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final roleColor = RoleColors.getColor(sender.role, isDark: isDark);

    final bubbleColor = isMe
        ? AppColors.myMessageBubble
        : (isDark
              ? AppColors.otherMessageBubbleDark
              : AppColors.otherMessageBubbleLight);

    final textColor = isMe
        ? Colors.white
        : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMe) _buildAvatar(context),

          if (!isMe) const SizedBox(width: 8),

          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isMe) _buildNameRow(roleColor),

                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _buildMessageContent(textColor),
                ),

                const SizedBox(height: 4),

                Text(
                  TimeUtils.formatChatTime(message.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextHint
                        : AppColors.lightTextHint,
                  ),
                ),
              ],
            ),
          ),

          if (isMe) const SizedBox(width: 8),

          if (isMe) _buildAvatar(context),
        ],
      ),
    );
  }

  // ==============================
  // AVATAR
  // ==============================

  Widget _buildAvatar(BuildContext context) {
    // 1. إذا كانت الصورة موجودة في الـ message model (مثل تقمص الأدوار)
    if (message.senderAvatar.isNotEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundImage: NetworkImage(message.senderAvatar),
      );
    }

    // 2. إذا كانت فارغة، نبحث عن صورة المستخدم الحقيقية من الـ UserProvider
    return FutureBuilder<UserModel?>(
      future: Provider.of<UserProvider>(
        context,
        listen: false,
      ).getUserById(message.senderId),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data?.avatarUrl.isNotEmpty == true) {
          return CircleAvatar(
            radius: 18,
            backgroundImage: NetworkImage(snapshot.data!.avatarUrl),
          );
        }

        // 3. شكل افتراضي في حال عدم وجود صورة نهائياً
        return CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: const Icon(Icons.person, size: 20, color: AppColors.primary),
        );
      },
    );
  }

  // ==============================
  // NAME + ROLE BADGE
  // ==============================

  Widget _buildNameRow(Color roleColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message.senderName,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: roleColor,
          ),
        ),

        const SizedBox(width: 6),

        RoleBadge(role: sender.role),
      ],
    );
  }

  // ==============================
  // MESSAGE CONTENT
  // ==============================

  Widget _buildMessageContent(Color textColor) {
    if (message.text != null) {
      return Text(
        message.text!,
        style: TextStyle(fontSize: 15, color: textColor),
      );
    }

    if (message.mediaUrl != null) {
      if (message.mediaType == 'image') {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            message.mediaUrl!,
            width: 220,
            fit: BoxFit.cover,
          ),
        );
      }

      if (message.mediaType == 'video') {
        return const Text("🎬 Video message");
      }

      if (message.mediaType == 'audio') {
        return const Text("🎧 Audio message");
      }
    }

    if (message.gameId != null) {
      return const Text(
        "🎮 Game started",
        style: TextStyle(fontWeight: FontWeight.w600),
      );
    }

    return const SizedBox();
  }
}
