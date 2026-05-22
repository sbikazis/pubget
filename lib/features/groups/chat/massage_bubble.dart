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
import 'package:pubget/models/user_model.dart';
import 'package:pubget/models/edits_model.dart';
import 'package:pubget/providers/user_provider.dart';
import 'package:pubget/providers/chat_provider.dart';
import 'package:pubget/providers/private_chat_provider.dart';
import 'package:pubget/providers/edits_provider.dart';
import 'package:pubget/features/profile/profile_sceen.dart';
import 'package:pubget/features/profile/respect_modal.dart';
import 'package:pubget/features/edits/edits_screen.dart';
import '../../../services/local/local_storage_service.dart'; // ✅ مضاف

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roleColor = RoleColors.getColor(sender.role, isDark: isDark);

    final bool isGameMessage = message.gameId!= null;
    Color? gameAccentColor;
    if (isGameMessage) {
      gameAccentColor = message.gameSlot == 'game_1'
         ? const Color(0xFFFFD700)
          : const Color(0xFFC0C0C0);
    }

    final Color bubbleColor;
    if (isGameMessage) {
      bubbleColor = gameAccentColor!.withOpacity(0.15);
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
    if (isMe &&!isGameMessage) {
      textColor = Colors.white;
    } else if (hasBackground) {
      textColor = isDark? Colors.white : AppColors.lightTextPrimary;
    } else {
      textColor = isDark? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    }

    final Color timeColor;
    if (hasBackground) {
      timeColor = isDark
         ? Colors.white.withOpacity(0.75)
          : Colors.black.withOpacity(0.60);
    } else {
      timeColor = isDark? AppColors.darkTextHint : AppColors.lightTextHint;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: GestureDetector(
        onLongPress: () => _showOptionsSheet(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment:
              isMe? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isMe) _buildAvatar(context, isGameMessage, gameAccentColor),
            if (!isMe) const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isMe? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  _buildNameRow(roleColor),
                  if (message.reactions!= null &&
                      message.reactions!.isNotEmpty)
                    _buildReactionsRow(),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.circular(16),
                      border: isGameMessage
                         ? Border.all(color: gameAccentColor!, width: 1)
                          : null,
                      boxShadow: hasBackground
                         ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.20),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.replyText!= null)
                          _buildReplyPreview(isDark),
                        _buildMessageContent(context, textColor),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    TimeUtils.formatChatTime(message.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: timeColor,
                      shadows: hasBackground
                         ? [
                              Shadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 3,
                              ),
                            ]
                          : null,
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
                      final userId = Provider.of<UserProvider>(
                        context,
                        listen: false,
                      ).currentUser!.id;
                      if (isPrivate) {
                        Provider.of<PrivateChatProvider>(
                          context,
                          listen: false,
                        ).toggleReaction(
                          chatId: groupId,
                          messageId: message.id,
                          userId: userId,
                          emoji: emoji,
                        );
                      } else {
                        Provider.of<ChatProvider>(
                          context,
                          listen: false,
                        ).toggleReaction(
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
              title: const Text('رد'),
              onTap: () {
                Navigator.pop(context);
                if (onReply!= null) onReply!(message);
              },
            ),
            if (message.text!= null && message.text!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy, color: AppColors.primary),
                title: const Text('نسخ'),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: message.text!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم نسخ الرسالة'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            if (isMe)
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'حذف الرسالة',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  if (isPrivate) {
                    Provider.of<PrivateChatProvider>(
                      context,
                      listen: false,
                    ).deleteMessage(
                        chatId: groupId, messageId: message.id);
                  } else {
                    Provider.of<ChatProvider>(
                      context,
                      listen: false,
                    ).deleteMessage(
                        groupId: groupId, messageId: message.id);
                  }
                  Navigator.pop(context);
                },
              )
            else
              ListTile(
                leading: const Icon(
                  Icons.person_outline,
                  color: Color(0xFFFFD700),
                ),
                title: const Text('الملف الشخصي'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ProfileScreen(userId: message.senderId),
                    ),
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
        if (onTapReply!= null && message.replyToId!= null) {
          onTapReply!(message.replyToId!);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isDark
             ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05),
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
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (onTapReply!= null && message.replyToId!= null) {
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
                    fontStyle: FontStyle.italic,
                    color: isDark? Colors.white70 : Colors.black54,
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
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 12)),
        );
      }).toList(),
    );
  }

  Widget _buildAvatar(
    BuildContext context, [
    bool isGame = false,
    Color? gameColor,
  ]) {
    final String? avatarUrl = sender.displayImageUrl??
        (message.senderAvatar.isNotEmpty? message.senderAvatar : null);

    return GestureDetector(
      onTap: () async {
        if (isMe) return;
        final userProvider =
            Provider.of<UserProvider>(context, listen: false);
        final myId = userProvider.currentUser?.id;
        final targetUser =
            await userProvider.getUserById(message.senderId);
        if (targetUser!= null && myId!= null) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) =>
                RespectModal(targetUser: targetUser, currentUserId: myId),
          );
        }
      },
      child: CircleAvatar(
        radius: 18,
        backgroundColor: isGame
           ? gameColor!.withOpacity(0.2)
            : AppColors.primary.withOpacity(0.1),
        child: ClipOval(
          child: isGame
             ? Icon(Icons.videogame_asset, size: 20, color: gameColor)
              : (avatarUrl!= null && avatarUrl.isNotEmpty
                 ? Image.network(
                      avatarUrl,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(
                        Icons.person,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              value: loadingProgress.expectedTotalBytes!= null
                                 ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                    )
                  : const Icon(
                      Icons.person,
                      size: 20,
                      color: AppColors.primary,
                    )),
        ),
      ),
    );
  }

  Widget _buildNameRow(Color roleColor) {
    final bool isPremiumUser = message.senderIsPremium || sender.isPremium;

    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: isMe? TextDirection.rtl : TextDirection.ltr,
      children: [
        Flexible(
          child: Text(
            sender.effectiveName,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: roleColor,
              shadows: hasBackground
                 ? [
                      Shadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
        if (isPremiumUser)...[
          const SizedBox(width: 4),
          const PremiumBadge(size: 14),
        ],
        const SizedBox(width: 6),
        RoleBadge(role: sender.role),
      ],
    );
  }

  Widget _buildMessageContent(BuildContext context, Color textColor) {
    // ── إيديت مشارك
    if (message.mediaType == 'edit_share' && message.mediaUrl!= null) {
      return _EditShareBubble(message: message);
    }

    // ── GIF مع حفظ بالضغط المطول ✅
    if (message.mediaType == 'gif' && message.mediaUrl!= null) {
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
                duration: Duration(seconds: 1),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('GIF محفوظ مسبقاً'),
                duration: Duration(seconds: 1),
              ),
            );
          }
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            message.mediaUrl!,
            width: 200,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: 200,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => Container(
              width: 200,
              height: 100,
              color: Colors.grey[300],
              child: const Center(
                child: Icon(Icons.gif, size: 40, color: Colors.grey),
              ),
            ),
          ),
        ),
      );
    }

    // ── نص
    if (message.text!= null) {
      return Text(
        message.text!,
        style: TextStyle(fontSize: 15, color: textColor),
      );
    }

    // ── صورة
    if (message.mediaUrl!= null && message.mediaType == 'image') {
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
          errorBuilder: (context, error, stackTrace) => Container(
            width: 220,
            height: 150,
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image, color: Colors.grey),
          ),
        ),
      );
    }

    // ── صوت
    if (message.mediaType == 'audio' && message.mediaUrl!= null) {
      return AudioBubble(url: message.mediaUrl!, isMe: isMe);
    }

    return const SizedBox();
  }
}

// ══════════════════════════════════════════════
// ── Widget مستقل لتشغيل الإيديت في الدردشة
// ══════════════════════════════════════════════
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
      Uri.parse(widget.message.mediaUrl!),
    );
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
                    if (_initialized && _controller!= null)
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
                    else if (widget.message.editThumbnail!= null &&
                        widget.message.editThumbnail!.isNotEmpty)
                      Image.network(
                        widget.message.editThumbnail!,
                        width: 220,
                        height: 140,
                        fit: BoxFit.cover,
                      )
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
                                      color: Colors.white, fontSize: 11)),
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
                    widget.message.editAnimeTitle?? 'إيديت',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
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