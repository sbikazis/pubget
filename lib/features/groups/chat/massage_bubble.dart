// lib/features/groups/chat/message_bubble.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../../models/message_model.dart';
import '../../../models/member_model.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/role_colors.dart';
import '../../../core/utils/time_utils.dart';
import '../../../core/constants/roles.dart';
import 'package:pubget/models/user_model.dart';
import 'package:pubget/models/edits_model.dart';
import 'package:pubget/providers/user_provider.dart';
import 'package:pubget/providers/chat_provider.dart';
import 'package:pubget/providers/private_chat_provider.dart';
import 'package:pubget/providers/edits_provider.dart';
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
  final bool hasBackground;

  const MessageBubble({
    super.key,
    required this.message,
    required this.sender,
    required this.isMe,
    required this.groupId,
    this.onReply,
    this.onTapReply,
    this.hasBackground = false,
  });

  // 1. الدالة المساعدة لتحديد لون مؤشر حالة الرسالة (صح مفرد)
  Color _getStatusColor() {
    if (message.isRead) {
      return Colors.green; // قرأها 🟢
    } else if (message.isDelivered) {
      return Colors.yellow; // وصلت ولم تُقرأ 🟡
    } else {
      return Colors.red; // لم تصل للهاتف الآخر 🔴
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roleColor = RoleColors.getColor(sender.role, isDark: isDark);
    final bool isPremiumUser = message.senderIsPremium || sender.isPremium;

    final bool isGameMessage = message.gameId != null && message.type != MessageType.gameInvite;
    Color? gameAccentColor;
    
    if (isGameMessage) {
      gameAccentColor = message.gameSlot == 'game_1'
          ? const Color(0xFFFFD700)
          : const Color(0xFFC0C0C0);
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
      timeColor = isDark ? Colors.white.withOpacity(0.80) : Colors.black.withOpacity(0.70);
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: GestureDetector(
        onLongPress: () => _showOptionsSheet(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isMe) _buildAvatar(context, isGameMessage, gameAccentColor),
            if (!isMe) const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (message.reactions != null && message.reactions!.isNotEmpty)
                    _buildReactionsRow(),
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: borderRadius,
                      border: isGameMessage
                          ? Border.all(color: gameAccentColor!, width: 1.2)
                          : (isPremiumUser
                              ? Border.all(color: const Color(0xFFFFD700), width: 1.0)
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
                        if (message.replyText != null) _buildReplyPreview(isDark),
                        _buildMessageContent(context, textColor),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              TimeUtils.formatChatTime(message.createdAt),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: timeColor,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              // 2. استبدال الأيقونة لتصبح صح مفرد وتمرير اللون الديناميكي
                              Icon(
                                Icons.done,
                                size: 15,
                                color: _getStatusColor(),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (isMe) const SizedBox(width: 8),
            if (isMe) _buildAvatar(context, isGameMessage, gameAccentColor),
          ],
        ),
      ),
    );
  }

  void _showOptionsSheet(BuildContext context) {
    final bool isPrivate = sender.groupId == 'private';
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
                      final userId = Provider.of<UserProvider>(context, listen: false).currentUser!.id;
                      if (isPrivate) {
                        Provider.of<PrivateChatProvider>(context, listen: false).toggleReaction(
                          chatId: groupId,
                          messageId: message.id,
                          userId: userId,
                          emoji: emoji,
                        );
                      } else {
                        Provider.of<ChatProvider>(context, listen: false).toggleReaction(
                          groupId: groupId,
                          messageId: message.id,
                          userId: userId,
                          emoji: emoji,
                        );
                      }
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
              title: const Text('رد', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                if (onReply != null) onReply!(message);
              },
            ),
            if (message.text != null && message.text!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy, color: AppColors.primary),
                title: const Text('نسخ', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: message.text!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم نسخ الرسالة'), duration: Duration(seconds: 1)),
                  );
                },
              ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('حذف الرسالة', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                onTap: () {
                  if (isPrivate) {
                    Provider.of<PrivateChatProvider>(context, listen: false).deleteMessage(
                      chatId: groupId,
                      messageId: message.id,
                    );
                  } else {
                    Provider.of<ChatProvider>(context, listen: false).deleteMessage(
                      groupId: groupId,
                      messageId: message.id,
                    );
                  }
                  Navigator.pop(context);
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.person_outline, color: Color(0xFFFFD700)),
                title: const Text('الملف الشخصي', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProfileScreen(userId: message.senderId)),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyPreview(bool isDark) {
    return GestureDetector(
      onTap: () {
        if (onTapReply != null && message.replyToId != null) {
          onTapReply!(message.replyToId!);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: isMe ? BorderSide.none : const BorderSide(color: AppColors.primary, width: 4),
            right: isMe ? const BorderSide(color: AppColors.primary, width: 4) : BorderSide.none,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (onTapReply != null && message.replyToId != null) {
                  onTapReply!(message.replyToId!);
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  message.replyText!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ),
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
            color: AppColors.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 12)),
        );
      }).toList(),
    );
  }

  Widget _buildAvatar(BuildContext context, [bool isGame = false, Color? gameColor]) {
    final String? avatarUrl = sender.displayImageUrl ?? (message.senderAvatar.isNotEmpty ? message.senderAvatar : null);
    return GestureDetector(
      onTap: () async {
        if (isMe) return;
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final myId = userProvider.currentUser?.id;
        final targetUser = await userProvider.getUserById(message.senderId);
        if (targetUser != null && myId != null) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => RespectModal(targetUser: targetUser, currentUserId: myId),
          );
        }
      },
      child: CircleAvatar(
        radius: 18,
        backgroundColor: isGame ? gameColor!.withOpacity(0.2) : AppColors.primary.withOpacity(0.1),
        child: ClipOval(
          child: isGame
              ? Icon(Icons.videogame_asset, size: 20, color: gameColor)
              : (avatarUrl != null && avatarUrl.isNotEmpty
                  ? Image.network(
                      avatarUrl,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 20, color: AppColors.primary),
                    )
                  : const Icon(Icons.person, size: 20, color: AppColors.primary)),
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
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: roleColor),
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
              const SnackBar(content: Text('تم حفظ GIF في المحفوظات ⭐'), duration: Duration(seconds: 1)),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('GIF محفوظ مسبقاً'), duration: Duration(seconds: 1)),
            );
          }
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(message.mediaUrl!, width: 200, fit: BoxFit.cover),
        ),
      );
    }
    if (message.text != null) {
      return Text(
        message.text!,
        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500, color: textColor, height: 1.3),
      );
    }
    if (message.mediaUrl != null && message.mediaType == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(message.mediaUrl!, width: 220, fit: BoxFit.cover),
      );
    }
    if (message.mediaType == 'audio' && message.mediaUrl != null) {
      return AudioBubble(message: message, isMe: isMe,);
    }
    return const SizedBox();
  }

  Widget _buildGameInvite(BuildContext context, Color textColor) {
    final user = Provider.of<UserProvider>(context, listen: false).currentUser;
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
              const Icon(Icons.sports_esports, color: AppColors.primary, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'سلسلة أنمي',
                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(message.text ?? 'دعوة للعبة', style: TextStyle(color: textColor.withOpacity(0.9), fontSize: 13.5)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
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
              child: const Text('انضم الآن ⚔️', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

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
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.message.mediaUrl!));
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
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
                    else if (widget.message.editThumbnail != null && widget.message.editThumbnail!.isNotEmpty)
                      Image.network(widget.message.editThumbnail!, width: 220, height: 140, fit: BoxFit.cover)
                    else
                      Container(color: Colors.grey[900]),
                    Icon(
                      _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                      color: Colors.white70,
                      size: 44,
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => _openInEditsScreen(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.open_in_full, color: Colors.white, size: 12),
                              SizedBox(width: 4),
                              Text('عرض', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                const Text('🎌 ', style: TextStyle(fontSize: 13)),
                Expanded(
                  child: Text(
                    widget.message.editAnimeTitle ?? 'إيديت',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () => _openInEditsScreen(context),
                  child: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
