// lib/features/groups/chat/massage_bubble.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../../models/message_model.dart';
import '../../../models/member_model.dart';
import '../../../models/sticker_model.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/role_colors.dart';
import '../../../core/utils/time_utils.dart';
import '../../../core/constants/roles.dart';
import '../../../core/constants/limits.dart';
import 'package:pubget/models/user_model.dart';
import 'package:pubget/models/edits_model.dart';
import 'package:pubget/providers/user_provider.dart';
import 'package:pubget/providers/chat_provider.dart';
import 'package:pubget/providers/private_chat_provider.dart';
import 'package:pubget/providers/sticker_provider.dart';
import 'package:pubget/providers/edits_provider.dart';
import 'package:pubget/providers/profile_provider.dart'; // ✅ جديد
import 'package:pubget/features/profile/profile_sceen.dart';
import 'package:pubget/features/profile/respect_modal.dart';
import 'package:pubget/features/edits/edits_screen.dart';
import '../../../features/groups/events/anime_chain_game_screen.dart';
import '../../../services/local/local_storage_service.dart';

import 'role_badge.dart';
import '../../../widgets/premium_badge.dart';
import '../../../widgets/audio_bubble.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final MemberModel sender;
  final bool isMe;
  final String groupId;
  final Function(MessageModel)? onReply;
  final Function(String)? onTapReply;
  final Function(MessageModel)? onEdit;
  final bool hasBackground;

  const MessageBubble({
    super.key,
    required this.message,
    required this.sender,
    required this.isMe,
    required this.groupId,
    this.onReply,
    this.onTapReply,
    this.onEdit,
    this.hasBackground = false,
  });

  // ✅ اللون حسب حالة التسليم
  Color _getStatusColor() {
    if (message.isRead) return Colors.green;
    if (message.isDelivered) return Colors.amber;
    return Colors.red;
  }

  // ✅ الأيقونة حسب حالة التسليم
  IconData _getStatusIcon() {
    if (message.isRead) return Icons.done_all;
    return Icons.done;
  }

  // ✅✅✅ تعديل جوهري: createdAt أصبح DateTime؟ الآن.
  // إذا لم يصل وقت السيرفر بعد (الرسالة أُرسلت منذ لحظات فقط ولم يُحدّث
  // الـ snapshot برقم Timestamp حقيقي)، نعتبرها "حديثة جداً جداً" بالتعريف،
  // فتبقى قابلة للتعديل دون الحاجة لحساب أي فرق وقت.
  bool get _canEdit =>
      isMe &&
      message.type == MessageType.text &&
      (message.createdAt == null ||
          !TimeUtils.hasMinutesPassed(
              message.createdAt!, Limits.editMessageWindowMinutes));

  Map<String, List<String>> _groupReactions() {
    final map = <String, List<String>>{};
    if (message.reactions == null) return map;
    message.reactions!.forEach((userId, emoji) {
      map.putIfAbsent(emoji, () => []).add(userId);
    });
    return map;
  }

  void _showReactionDetails(BuildContext context) {
    final grouped = _groupReactions();
    if (grouped.isEmpty) return;

    final totalCount = message.reactions!.length;
    final currentUserId =
        Provider.of<UserProvider>(context, listen: false).currentUser?.id;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bgColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
        final dividerColor = isDark ? Colors.white12 : Colors.black12;

        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.only(top: 12, bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      '$totalCount ${totalCount == 1 ? 'تفاعل' : 'تفاعلان'}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _ReactionTabChip(
                      label: 'الكل',
                      count: totalCount,
                      isSelected: true,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    ...grouped.entries.map((e) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _ReactionTabChip(
                            label: e.key,
                            count: e.value.length,
                            isSelected: false,
                            isDark: isDark,
                          ),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Divider(color: dividerColor, height: 1),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.4,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: grouped.entries.expand((entry) {
                    final emoji = entry.key;
                    final userIds = entry.value;
                    return userIds.map((uid) => _ReactionUserTile(
                          userId: uid,
                          emoji: emoji,
                          isMe: uid == currentUserId,
                          isDark: isDark,
                        ));
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSystemEventBubble(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String eventType = message.systemEventType ?? 'join';

    IconData icon;
    Color iconColor;
    Color bgColor;

    switch (eventType) {
      case 'join':
        icon = Icons.waving_hand_rounded;
        iconColor = const Color(0xFF00C853);
        bgColor = const Color(0xFF00C853).withOpacity(0.12);
        break;
      case 'leave':
        icon = Icons.directions_walk_rounded;
        iconColor = Colors.orange;
        bgColor = Colors.orange.withOpacity(0.10);
        break;
      case 'kick':
        icon = Icons.gavel_rounded;
        iconColor = Colors.red;
        bgColor = Colors.red.withOpacity(0.10);
        break;
      case 'roleAssign':
        icon = Icons.military_tech_rounded;
        iconColor = const Color(0xFFFFD700);
        bgColor = const Color(0xFFFFD700).withOpacity(0.12);
        break;
      default:
        icon = Icons.info_outline_rounded;
        iconColor = AppColors.primary;
        bgColor = AppColors.primary.withOpacity(0.10);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: isDark ? Colors.white12 : Colors.black12,
              thickness: 1,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            constraints: const BoxConstraints(maxWidth: 260),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? bgColor.withOpacity(0.18) : bgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: iconColor.withOpacity(0.25),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    message.text ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Divider(
              color: isDark ? Colors.white12 : Colors.black12,
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (message.type == MessageType.systemEvent) {
      return _buildSystemEventBubble(context);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roleColor = RoleColors.getColor(sender.role, isDark: isDark);
    final bool isPremiumUser = message.senderIsPremium || sender.isPremium;

    final bool isGameMessage =
        message.gameId != null && message.type != MessageType.gameInvite;
    Color? gameAccentColor;
    if (isGameMessage) {
      gameAccentColor = message.gameSlot == 'game_1'
          ? const Color(0xFFFFD700)
          : const Color(0xFFC0C0C0);
    }

    final bool isSticker =
        message.mediaType == 'sticker' && message.mediaUrl != null;
    if (isSticker) {
      return _buildStickerRow(context, isDark);
    }

    final Color bubbleColor;
    if (isGameMessage) {
      bubbleColor = gameAccentColor!.withOpacity(0.08);
    } else if (isMe) {
      bubbleColor = hasBackground
          ? AppColors.myMessageBubble.withOpacity(0.92)
          : AppColors.myMessageBubble;
    } else {
      if (hasBackground) {
        bubbleColor = isDark
            ? const Color(0xFF2A2A35).withOpacity(0.90)
            : Colors.white.withOpacity(0.88);
      } else {
        bubbleColor = isDark
            ? AppColors.otherMessageBubbleDark
            : AppColors.otherMessageBubbleLight;
      }
    }

    final Color textColor;
    if (isMe && !isGameMessage) {
      textColor = Colors.white;
    } else if (isGameMessage) {
      textColor = isDark ? Colors.white : Colors.black87;
    } else if (hasBackground) {
      textColor = isDark ? Colors.white : const Color(0xFF111111);
    } else {
      textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    }

    final Color timeColor;
    if (isMe && !isGameMessage) {
      timeColor = Colors.white.withOpacity(0.85);
    } else if (hasBackground) {
      timeColor = isDark
          ? Colors.white.withOpacity(0.80)
          : Colors.black.withOpacity(0.70);
    } else {
      timeColor = isDark ? Colors.white70 : Colors.black54;
    }

    final borderRadius = isMe
        ? const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          );

    final hasReactions =
        message.reactions != null && message.reactions!.isNotEmpty;
    final bool hasReply = message.replyToId != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: _SwipeToReplyWrapper(
        isMe: isMe,
        onReplyTriggered: () {
          if (onReply != null) onReply!(message);
        },
        child: GestureDetector(
          onLongPress: () => _showOptionsSheet(context),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMe) _buildAvatar(context, isGameMessage, gameAccentColor),
              if (!isMe) const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: borderRadius,
                        border: isGameMessage
                            ? Border.all(color: gameAccentColor!, width: 1.2)
                            : (isPremiumUser
                                ? Border.all(
                                    color: const Color(0xFFFFD700), width: 1.0)
                                : null),
                        boxShadow: hasBackground
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isMe) ...[
                            _buildNameRow(roleColor, isPremiumUser),
                            const SizedBox(height: 4),
                          ],
                          if (hasReply) _buildReplyPreview(isDark),
                          _buildMessageContent(context, textColor),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (message.isEdited) ...[
                                Text(
                                  'تم التعديل',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontStyle: FontStyle.italic,
                                    color: timeColor.withOpacity(0.75),
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                // ✅✅✅ تعديل جوهري: التعامل مع createdAt == null
                                // (الرسالة أُرسلت توّاً ولم يصل وقت السيرفر بعد).
                                // نعرض "الآن" مؤقتاً؛ بعد جزء من الثانية يصل
                                // التحديث الحقيقي من Firestore ويعاد البناء فوراً.
                                message.createdAt != null
                                    ? TimeUtils.formatChatTime(
                                        message.createdAt!)
                                    : 'الآن',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: timeColor,
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 4),
                                // ✅ أيقونة + لون ديناميكي حسب حالة التسليم
                                Icon(
                                  _getStatusIcon(),
                                  size: 15,
                                  color: _getStatusColor(),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (hasReactions) ...[
                      const SizedBox(height: 4),
                      _buildReactionsRow(context),
                    ],
                  ],
                ),
              ),
              if (isMe) const SizedBox(width: 8),
              if (isMe) _buildAvatar(context, isGameMessage, gameAccentColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReactionsRow(BuildContext context) {
    final grouped = _groupReactions();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _showReactionDetails(context),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: grouped.entries.map((entry) {
          final emoji = entry.key;
          final count = entry.value.length;
          return Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF2A2A3E)
                  : const Color(0xFFF0F0F5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.12)
                    : Colors.black.withOpacity(0.08),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (count > 1) ...[
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Text(emoji, style: const TextStyle(fontSize: 16)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStickerRow(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) _buildAvatar(context),
          if (!isMe) const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _showStickerSaveSheet(context),
            onLongPress: () => _showOptionsSheet(context),
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.goldAccent.withOpacity(0.35),
                      width: 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.network(
                      message.mediaUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: isDark
                              ? const Color(0xFF2A2A3E)
                              : Colors.grey.shade100,
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.grey,
                        size: 40,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      // ✅✅✅ تعديل جوهري: نفس معاملة null هنا أيضاً
                      message.createdAt != null
                          ? TimeUtils.formatChatTime(message.createdAt!)
                          : 'الآن',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      // ✅ نفس المنطق في الـ sticker
                      Icon(
                        _getStatusIcon(),
                        size: 13,
                        color: _getStatusColor(),
                      ),
                    ],
                  ],
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

  void _showStickerSaveSheet(BuildContext context) {
    if (isMe) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).scaffoldBackgroundColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.bookmark_add_outlined,
                  color: AppColors.goldAccent),
              title: const Text('حفظ الملصق',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () async {
                Navigator.pop(ctx);
                final userId =
                    Provider.of<UserProvider>(context, listen: false)
                        .currentUser
                        ?.id;
                if (userId == null) return;
                // ✅✅✅ تعديل جوهري: هذا توقيت محلي فقط لأرشفة ملصق محفوظ
                // (لا تأثير له على ترتيب الرسائل أو حالة القراءة)، فاستخدام
                // DateTime.now() هنا كـ fallback آمن ومقبول تماماً.
                final sticker = StickerModel(
                  id: message.id,
                  creatorId: message.senderId,
                  imageUrl: message.mediaUrl!,
                  createdAt: message.createdAt ?? DateTime.now(),
                );
                await Provider.of<StickerProvider>(context, listen: false)
                    .saveReceivedSticker(userId: userId, sticker: sticker);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم حفظ الملصق ✅'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ✅✅✅ تعديل جوهري: استبدال "الملف الشخصي" بـ "منح نقاط الاحترام 🌟"
  // للطرف الآخر فقط. تنتقل عبر هذه الدالة كل عمليات الجلب اللازمة
  // (previousValue من ProfileProvider + targetUser من UserProvider) قبل
  // فتح RespectModal، بحيث تفتح الـ Modal دائماً بحالتها الصحيحة (مقفولة
  // ومحددة على القيمة السابقة، أو مفتوحة من الصفر لو أول مرة).
  Future<void> _openRespectModal(BuildContext context) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final myId = userProvider.currentUser?.id;
    if (myId == null) return;

    final targetUser = await userProvider.getUserById(message.senderId);
    if (targetUser == null) return;

    final previousValue = await profileProvider.getPreviousRespectValue(
      fromUserId: myId,
      toUserId: targetUser.id,
    );

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RespectModal(
        targetUser: targetUser,
        currentUserId: myId,
        previousValue: previousValue,
      ),
    );
  }

  void _showOptionsSheet(BuildContext context) {
    if (message.type == MessageType.systemEvent) return;

    final bool isPrivate = sender.groupId == 'private';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children:
                    ['❤️', '😂', '🔥', '😮', '😢', '👍'].map((emoji) {
                  return TextButton(
                    onPressed: () {
                      final userId =
                          Provider.of<UserProvider>(context, listen: false)
                              .currentUser!
                              .id;
                      if (isPrivate) {
                        Provider.of<PrivateChatProvider>(context,
                                listen: false)
                            .toggleReaction(
                          chatId: groupId,
                          messageId: message.id,
                          userId: userId,
                          emoji: emoji,
                        );
                      } else {
                        Provider.of<ChatProvider>(context, listen: false)
                            .toggleReaction(
                          groupId: groupId,
                          messageId: message.id,
                          userId: userId,
                          emoji: emoji,
                        );
                      }
                      Navigator.pop(context);
                    },
                    child:
                        Text(emoji, style: const TextStyle(fontSize: 28)),
                  );
                }).toList(),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.reply, color: AppColors.primary),
              title: const Text('رد',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                if (onReply != null) onReply!(message);
              },
            ),
            if (message.text != null && message.text!.isNotEmpty)
              ListTile(
                leading:
                    const Icon(Icons.copy, color: AppColors.primary),
                title: const Text('نسخ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: message.text!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('تم نسخ الرسالة'),
                        duration: Duration(seconds: 1)),
                  );
                },
              ),
            if (_canEdit)
              ListTile(
                leading: const Icon(Icons.edit_outlined,
                    color: AppColors.primary),
                title: const Text('تعديل',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  if (onEdit != null) onEdit!(message);
                },
              ),
            if (isMe)
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('حذف الرسالة',
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold)),
                onTap: () {
                  if (isPrivate) {
                    Provider.of<PrivateChatProvider>(context, listen: false)
                        .deleteMessage(
                      chatId: groupId,
                      messageId: message.id,
                    );
                  } else {
                    Provider.of<ChatProvider>(context, listen: false)
                        .deleteMessage(
                      groupId: groupId,
                      messageId: message.id,
                    );
                  }
                  Navigator.pop(context);
                },
              )
            else
              // ✅✅✅ تعديل جوهري: "الملف الشخصي" → "منح نقاط الاحترام 🌟"
              // الانتقال للملف الشخصي أصبح من خلال الضغط على الصورة (_buildAvatar)
              ListTile(
                leading: const Icon(Icons.star_outline,
                    color: Color(0xFFFFD700)),
                title: const Text('منح نقاط الاحترام 🌟',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  _openRespectModal(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyPreview(bool isDark) {
    final String? mediaType = message.replyText == null
        ? null
        : (message.replyText == '🎙️ تسجيل صوتي'
            ? 'audio'
            : message.replyText == 'ملصق 🏷️'
                ? 'sticker'
                : message.replyText == 'GIF 🎞️'
                    ? 'gif'
                    : message.replyText == 'صورة 🖼️'
                        ? 'image'
                        : null);

    final bool hasMedia = message.replyToMediaUrl != null &&
        message.replyToMediaUrl!.isNotEmpty;

    return GestureDetector(
      onTap: () {
        if (onTapReply != null && message.replyToId != null) {
          onTapReply!(message.replyToId!);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: isMe
                ? BorderSide.none
                : const BorderSide(color: AppColors.primary, width: 4),
            right: isMe
                ? const BorderSide(color: AppColors.primary, width: 4)
                : BorderSide.none,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          message.replyToSenderName ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        _buildReplyContent(isDark, mediaType),
                      ],
                    ),
                  ),
                ),
                if (hasMedia &&
                    (mediaType == 'image' ||
                        mediaType == 'gif' ||
                        mediaType == null))
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                    child: Image.network(
                      message.replyToMediaUrl!,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 52,
                        height: 52,
                        color: isDark ? Colors.white10 : Colors.black12,
                        child: const Icon(Icons.broken_image_outlined,
                            size: 20, color: Colors.grey),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReplyContent(bool isDark, String? mediaType) {
    final textStyle = TextStyle(
      fontSize: 12,
      color: isDark ? Colors.white60 : Colors.black54,
    );

    if (mediaType == 'audio') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mic,
              size: 14, color: isDark ? Colors.white60 : Colors.black54),
          const SizedBox(width: 4),
          Text('تسجيل صوتي', style: textStyle),
        ],
      );
    }
    if (mediaType == 'sticker') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sticky_note_2_outlined,
              size: 14, color: isDark ? Colors.white60 : Colors.black54),
          const SizedBox(width: 4),
          Text('ملصق', style: textStyle),
        ],
      );
    }
    if (mediaType == 'gif') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.gif_box_outlined,
              size: 16, color: isDark ? Colors.white60 : Colors.black54),
          const SizedBox(width: 4),
          Text('GIF', style: textStyle),
        ],
      );
    }
    if (mediaType == 'image') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_outlined,
              size: 14, color: isDark ? Colors.white60 : Colors.black54),
          const SizedBox(width: 4),
          Text('صورة', style: textStyle),
        ],
      );
    }
    return Text(
      message.replyText ?? '',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: textStyle,
    );
  }

  // ✅✅✅ تعديل جوهري: onTap على الصورة أصبح يفتح ProfileScreen مباشرة
  // بدل RespectModal (عكس الأدوار المطلوب). منح نقاط الاحترام انتقل إلى
  // _showOptionsSheet (عبر onLongPress على الرسالة بالكامل).
  Widget _buildAvatar(BuildContext context,
      [bool isGame = false, Color? gameColor]) {
    final String? avatarUrl = sender.displayImageUrl ??
        (message.senderAvatar.isNotEmpty ? message.senderAvatar : null);
    return GestureDetector(
      onTap: () {
        if (isMe) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileScreen(userId: message.senderId),
          ),
        );
      },
      child: CircleAvatar(
        radius: 18,
        backgroundColor: isGame
            ? gameColor!.withOpacity(0.2)
            : AppColors.primary.withOpacity(0.1),
        child: ClipOval(
          child: isGame
              ? Icon(Icons.videogame_asset, size: 20, color: gameColor)
              : (avatarUrl != null && avatarUrl.isNotEmpty
                  ? Image.network(
                      avatarUrl,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.person,
                              size: 20, color: AppColors.primary),
                    )
                  : const Icon(Icons.person,
                      size: 20, color: AppColors.primary)),
        ),
      ),
    );
  }

  Widget _buildNameRow(Color roleColor, bool isPremiumUser) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: isMe ? TextDirection.rtl : TextDirection.ltr,
      children: [
        Flexible(
          child: Text(
            sender.effectiveName,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: roleColor),
          ),
        ),
        if (isPremiumUser) ...[
          const SizedBox(width: 4),
          const PremiumBadge(size: 12),
        ],
        const SizedBox(width: 4),
        RoleBadge(role: sender.role),
      ],
    );
  }

  Widget _buildMessageContent(BuildContext context, Color textColor) {
    if (message.type == MessageType.gameInvite && message.gameId != null) {
      return _buildGameInvite(context, textColor);
    }
    if (message.mediaType == 'edit_share' && message.mediaUrl != null) {
      return _EditShareBubble(message: message);
    }
    if (message.mediaType == 'gif' && message.mediaUrl != null) {
      return GestureDetector(
        onLongPress: () async {
          final url = message.mediaUrl!;
          final saved = LocalStorageService.instance.getSavedGifs();
          if (!saved.contains(url)) {
            saved.insert(0, url);
            await LocalStorageService.instance.saveGifs(saved);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('تم حفظ GIF في المحفوظات ⭐'),
                  duration: Duration(seconds: 1)),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('GIF محفوظ مسبقاً'),
                  duration: Duration(seconds: 1)),
            );
          }
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(message.mediaUrl!,
              width: 200, fit: BoxFit.cover),
        ),
      );
    }
    if (message.text != null) {
      return Text(
        message.text!,
        style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w500,
            color: textColor,
            height: 1.3),
      );
    }
    if (message.mediaUrl != null && message.mediaType == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(message.mediaUrl!,
            width: 220, fit: BoxFit.cover),
      );
    }
    if (message.mediaType == 'audio' && message.mediaUrl != null) {
      return AudioBubble(message: message, isMe: isMe);
    }
    return const SizedBox();
  }

  Widget _buildGameInvite(BuildContext context, Color textColor) {
    final user =
        Provider.of<UserProvider>(context, listen: false).currentUser;
    return Container(
      width: 240,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sports_esports,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'سلسلة أنمي',
                  style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(message.text ?? 'دعوة للعبة',
              style: TextStyle(
                  color: textColor.withOpacity(0.9), fontSize: 13.5)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white),
              onPressed: () {
                if (user == null) return;
                final tempMember = MemberModel(
                  userId: user.id,
                  displayName: user.nickname ?? user.username,
                  groupId: groupId,
                  role: Roles.member,
                  joinedAt: DateTime.now(),
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AnimeChainGameScreen(
                      groupId: groupId,
                      currentMember: tempMember,
                      existingGameId: message.gameId,
                    ),
                  ),
                );
              },
              child: const Text('انضم الآن ⚔️',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// _SwipeToReplyWrapper
// ══════════════════════════════════════════════════════════════
class _SwipeToReplyWrapper extends StatefulWidget {
  final Widget child;
  final bool isMe;
  final VoidCallback onReplyTriggered;

  const _SwipeToReplyWrapper({
    required this.child,
    required this.isMe,
    required this.onReplyTriggered,
  });

  @override
  State<_SwipeToReplyWrapper> createState() => _SwipeToReplyWrapperState();
}

class _SwipeToReplyWrapperState extends State<_SwipeToReplyWrapper> {
  double _dragExtent = 0;
  static const double _maxDrag = 70;
  static const double _triggerThreshold = 55;
  bool _triggered = false;

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragExtent += details.delta.dx;
      if (_dragExtent < 0) _dragExtent = 0;
      if (_dragExtent > _maxDrag) _dragExtent = _maxDrag;
    });

    if (!_triggered && _dragExtent >= _triggerThreshold) {
      _triggered = true;
      HapticFeedback.mediumImpact();
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_dragExtent >= _triggerThreshold) {
      widget.onReplyTriggered();
    }
    setState(() {
      _dragExtent = 0;
      _triggered = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double opacity = (_dragExtent / _triggerThreshold).clamp(0.0, 1.0);

    return GestureDetector(
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [
          if (_dragExtent > 0)
            Positioned(
              left: 4,
              child: Opacity(
                opacity: opacity,
                child: Icon(
                  Icons.reply,
                  color: AppColors.primary,
                  size: 22 + (opacity * 4),
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(_dragExtent, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// _ReactionTabChip
// ══════════════════════════════════════════════════════════════
class _ReactionTabChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final bool isDark;

  const _ReactionTabChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary
            : (isDark
                ? const Color(0xFF2A2A3E)
                : const Color(0xFFF0F0F5)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? AppColors.primary
              : (isDark ? Colors.white12 : Colors.black12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.black87),
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// _ReactionUserTile
// ══════════════════════════════════════════════════════════════
class _ReactionUserTile extends StatelessWidget {
  final String userId;
  final String emoji;
  final bool isMe;
  final bool isDark;

  const _ReactionUserTile({
    required this.userId,
    required this.emoji,
    required this.isMe,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel?>(
      future: Provider.of<UserProvider>(context, listen: false)
          .getUserById(userId),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final name =
            isMe ? 'أنت' : (user?.nickname ?? user?.username ?? '...');
        final avatarUrl = user?.avatarUrl;

        return ListTile(
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withOpacity(0.15),
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? const Icon(Icons.person,
                        size: 22, color: AppColors.primary)
                    : null,
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color:
                        isDark ? const Color(0xFF1E1E2E) : Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child:
                      Text(emoji, style: const TextStyle(fontSize: 14)),
                ),
              ),
            ],
          ),
          title: Text(
            name,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          subtitle: isMe
              ? Text(
                  'اضغط للإزالة',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                )
              : null,
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
// _EditShareBubble
// ══════════════════════════════════════════════════════════════
class _EditShareBubble extends StatefulWidget {
  final MessageModel message;
  const _EditShareBubble({required this.message});

  @override
  State<_EditShareBubble> createState() => _EditShareBubbleState();
}

class _EditShareBubbleState extends State<_EditShareBubble> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    if (widget.message.mediaUrl == null) return;
    final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.message.mediaUrl!));
    await controller.initialize();
    controller.setLooping(true);
    if (mounted) {
      setState(() {
        _controller = controller;
        _initialized = true;
      });
    }
  }

  void _togglePlay() {
    if (!_initialized || _controller == null) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _isPlaying = false;
      } else {
        _controller!.play();
        _isPlaying = true;
      }
    });
  }

  void _openInEditsScreen(BuildContext context) {
    final editId = widget.message.editId;
    if (editId == null || editId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<EditsProvider>(),
          child: EditsScreen(initialEditId: editId),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: SizedBox(
                width: 220,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_initialized && _controller != null)
                      SizedBox.expand(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _controller!.value.size.width,
                            height: _controller!.value.size.height,
                            child: VideoPlayer(_controller!),
                          ),
                        ),
                      )
                    else if (widget.message.editThumbnail != null &&
                        widget.message.editThumbnail!.isNotEmpty)
                      Image.network(widget.message.editThumbnail!,
                          width: 220, height: 140, fit: BoxFit.cover)
                    else
                      Container(color: Colors.grey[900]),
                    Icon(
                      _isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_fill,
                      color: Colors.white70,
                      size: 44,
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => _openInEditsScreen(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.open_in_full,
                                  color: Colors.white, size: 12),
                              SizedBox(width: 4),
                              Text('عرض',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                const Text('🎌 ', style: TextStyle(fontSize: 13)),
                Expanded(
                  child: Text(
                    widget.message.editAnimeTitle ?? 'إيديت',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () => _openInEditsScreen(context),
                  child: const Icon(Icons.arrow_forward_ios,
                      color: Colors.white54, size: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}