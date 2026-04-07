import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/message_model.dart';
import '../../../models/member_model.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/role_colors.dart';
import '../../../core/utils/time_utils.dart';
import 'package:pubget/models/user_model.dart';
import 'package:pubget/providers/user_provider.dart';
import 'package:pubget/providers/chat_provider.dart';
import 'package:pubget/features/profile/profile_sceen.dart';
import 'package:pubget/features/profile/respect_modal.dart'; 

import 'role_badge.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final MemberModel sender;
  final bool isMe;
  final String groupId;
  final Function(MessageModel)? onReply;
  // ✅ إضافة دالة الـ Callback لاستقبال طلب الانتقال للرسالة الأصلية
  final Function(String)? onTapReply;

  const MessageBubble({
    super.key,
    required this.message,
    required this.sender,
    required this.isMe,
    required this.groupId,
    this.onReply,
    this.onTapReply, // ✅ إضافة البارامتر الجديد هنا
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
      child: GestureDetector(
        onLongPress: () => _showOptionsSheet(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isMe) _buildAvatar(context),
            if (!isMe) const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe) _buildNameRow(roleColor),
                  
                  if (message.reactions != null && message.reactions!.isNotEmpty)
                    _buildReactionsRow(),

                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ✅ تمرير خاصية الضغط لمعاينة الرد
                        if (message.replyText != null) _buildReplyPreview(isDark),
                        _buildMessageContent(textColor),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    TimeUtils.formatChatTime(message.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                    ),
                  ),
                ],
              ),
            ),
            if (isMe) const SizedBox(width: 8),
            if (isMe) _buildAvatar(context),
          ],
        ),
      ),
    );
  }

  // ==============================
  // OPTIONS SHEET
  // ==============================

  void _showOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['❤️', '😂', '🔥', '😮', '😢', '👍'].map((emoji) {
                  return TextButton(
                    onPressed: () {
                      final chatProv = Provider.of<ChatProvider>(context, listen: false);
                      chatProv.toggleReaction(
                        groupId: groupId,
                        messageId: message.id,
                        userId: Provider.of<UserProvider>(context, listen: false).currentUser!.id,
                        emoji: emoji,
                      );
                      Navigator.pop(context);
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 28)),
                  );
                }).toList(),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.reply, color: AppColors.primary),
              title: const Text('رد'),
              onTap: () {
                Navigator.pop(context);
                if (onReply != null) onReply!(message);
              },
            ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('حذف الرسالة', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Provider.of<ChatProvider>(context, listen: false)
                      .deleteMessage(groupId: groupId, messageId: message.id);
                  Navigator.pop(context);
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.person_outline, color: Color(0xFFFFD700)),
                title: const Text('الملف الشخصي'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(userId: message.senderId),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // ==============================
  // UI COMPONENTS
  // ==============================

  Widget _buildReplyPreview(bool isDark) {
    // ✅ جعل معاينة الرد قابلة للضغط للانتقال للرسالة الأصلية
    return GestureDetector(
      onTap: () {
        if (onTapReply != null && message.replyToId != null) {
          onTapReply!(message.replyToId!);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        width: double.infinity, // لضمان قابلية الضغط على كامل العرض
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.08), // تغميق اللون قليلاً ليعطي إيحاء التفاعل
          borderRadius: BorderRadius.circular(8),
          border: const Border(
            right: BorderSide(color: AppColors.primary, width: 4),
          ),
        ),
        child: Text(
          message.replyText!,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
      ),
    );
  }

  Widget _buildReactionsRow() {
    return Wrap(
      spacing: 4,
      children: message.reactions!.values.toSet().map((emoji) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 12)),
        );
      }).toList(),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final myId = userProvider.currentUser?.id;

    return GestureDetector(
      onTap: () async {
        if (isMe) return;

        final targetUser = await userProvider.getUserById(message.senderId);
        if (targetUser != null && myId != null) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => RespectModal(
              targetUser: targetUser,
              currentUserId: myId,
            ),
          );
        }
      },
      child: message.senderAvatar.isNotEmpty
          ? CircleAvatar(
              radius: 18,
              backgroundImage: NetworkImage(message.senderAvatar),
            )
          : FutureBuilder<UserModel?>(
              future: userProvider.getUserById(message.senderId),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data?.avatarUrl.isNotEmpty == true) {
                  return CircleAvatar(
                    radius: 18,
                    backgroundImage: NetworkImage(snapshot.data!.avatarUrl),
                  );
                }
                return CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: const Icon(Icons.person, size: 20, color: AppColors.primary),
                );
              },
            ),
    );
  }

  Widget _buildNameRow(Color roleColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message.senderName,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: roleColor),
        ),
        const SizedBox(width: 6),
        RoleBadge(role: sender.role),
      ],
    );
  }

  Widget _buildMessageContent(Color textColor) {
    if (message.text != null) {
      return Text(message.text!, style: TextStyle(fontSize: 15, color: textColor));
    }
    if (message.mediaUrl != null) {
      if (message.mediaType == 'image') {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            message.mediaUrl!,
            width: 220,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            },
          ),
        );
      }
      return Text("🎬 ${message.mediaType} message");
    }
    return const SizedBox();
  }
}