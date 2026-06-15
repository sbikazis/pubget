// lib/features/private_chat/private_chat_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../models/member_model.dart';

import '../../providers/private_chat_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/chat_background_provider.dart';

import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state_widget.dart';

import '../groups/chat/massage_bubble.dart';
import '../groups/chat/massage_input_bar.dart';
import '../groups/chat/chat_background_picker_sheet.dart';

import '../../core/constants/roles.dart';
import 'package:pubget/models/sticker_model.dart';

class PrivateChatScreen extends StatefulWidget {
  final String chatId;
  final UserModel otherUser;

  const PrivateChatScreen({
    super.key,
    required this.chatId,
    required this.otherUser,
  });

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final Uuid _uuid = const Uuid();

  MessageModel? _replyingMessage;

  late Stream<List<MessageModel>> _messageStream;
  List<MessageModel> _currentMessages = [];

  bool _showScrollDown = false;

  @override
  void initState() {
    super.initState();
    _messageStream = Provider.of<PrivateChatProvider>(context, listen: false)
      .streamMessages(chatId: widget.chatId);

    _scrollController.addListener(_scrollListener);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePrivateReadStatus();
      context.read<ChatBackgroundProvider>().loadPrivateBackground(
            chatId: widget.chatId,
          );
    });
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final show = (maxScroll - currentScroll) > 200;
    if (show!= _showScrollDown) {
      setState(() => _showScrollDown = show);
    }
  }

  @override
  void dispose() {
    _updatePrivateReadStatus();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _updatePrivateReadStatus() {
    try {
      if (!mounted) return;
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final privateChatProvider =
          Provider.of<PrivateChatProvider>(context, listen: false);
      final currentUserId = userProvider.currentUser?.id;

      if (currentUserId!= null) {
        privateChatProvider.updatePrivateLastRead(
          chatId: widget.chatId,
          userId: currentUserId,
        );
      }
    } catch (e) {
      debugPrint("Status update failed: $e");
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scrollToMessage(String messageId) {
    final index = _currentMessages.indexWhere((m) => m.id == messageId);
    if (index!= -1) {
      double targetOffset = index * 80.0;
      if (targetOffset > _scrollController.position.maxScrollExtent) {
        targetOffset = _scrollController.position.maxScrollExtent;
      }
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  void _openBackgroundPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChatBackgroundPickerSheet(
        chatId: widget.chatId,
        isGroup: false,
      ),
    );
  }

  Future<void> _handleSendText(String text, MessageModel? replyTo) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final privateChatProvider =
        Provider.of<PrivateChatProvider>(context, listen: false);
    final currentUser = userProvider.currentUser;
    if (currentUser == null) return;

    try {
      await privateChatProvider.sendTextMessage(
        chatId: widget.chatId,
        messageId: _uuid.v4(),
        sender: currentUser,
        text: text,
        replyToId: replyTo?.id,
        replyText: replyTo?.text??
            (replyTo?.mediaType == 'image'
              ? "صورة 🖼️"
                : replyTo?.mediaType == 'gif'
                  ? "GIF 🎞️"
                    : replyTo?.mediaType == 'audio'
                      ? "🎙️ تسجيل صوتي"
                        : replyTo?.mediaType == 'sticker'
                          ? "ملصق 🏷️"
                            : null),
        replyToSenderName: replyTo?.senderName,
        replyToMediaUrl: (replyTo?.mediaType == 'image' || replyTo?.mediaType == 'gif')
          ? replyTo?.mediaUrl
            : null,
      );
      _updatePrivateReadStatus();
      _onCancelReply();
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("فشل إرسال الرسالة")),
      );
    }
  }

  Future<void> _handleSendImage(File file, MessageModel? replyTo) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final privateChatProvider =
        Provider.of<PrivateChatProvider>(context, listen: false);
    final currentUser = userProvider.currentUser;
    if (currentUser == null) return;

    try {
      await privateChatProvider.sendMediaMessage(
        chatId: widget.chatId,
        messageId: _uuid.v4(),
        sender: currentUser,
        file: file,
        mediaType: 'image',
        replyToId: replyTo?.id,
        replyText: replyTo?.text??
            (replyTo?.mediaType == 'image'
              ? "صورة 🖼️"
                : replyTo?.mediaType == 'gif'
                  ? "GIF 🎞️"
                    : replyTo?.mediaType == 'audio'
                      ? "🎙️ تسجيل صوتي"
                        : replyTo?.mediaType == 'sticker'
                          ? "ملصق 🏷️"
                            : null),
        replyToSenderName: replyTo?.senderName,
        replyToMediaUrl: (replyTo?.mediaType == 'image' || replyTo?.mediaType == 'gif')
          ? replyTo?.mediaUrl
            : null,
      );
      _updatePrivateReadStatus();
      _onCancelReply();
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("فشل إرسال الصورة")),
      );
    }
  }

  Future<void> _handleSendGif(String gifUrl, MessageModel? replyTo) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final privateChatProvider =
        Provider.of<PrivateChatProvider>(context, listen: false);
    final currentUser = userProvider.currentUser;
    if (currentUser == null) return;

    try {
      await privateChatProvider.sendGifMessage(
        chatId: widget.chatId,
        messageId: _uuid.v4(),
        sender: currentUser,
        gifUrl: gifUrl,
        replyToId: replyTo?.id,
        replyText: replyTo?.text??
            (replyTo?.mediaType == 'image'
              ? "صورة 🖼️"
                : replyTo?.mediaType == 'gif'
                  ? "GIF 🎞️"
                    : replyTo?.mediaType == 'audio'
                      ? "🎙️ تسجيل صوتي"
                        : replyTo?.mediaType == 'sticker'
                          ? "ملصق 🏷️"
                            : null),
        replyToSenderName: replyTo?.senderName,
        replyToMediaUrl: (replyTo?.mediaType == 'image' || replyTo?.mediaType == 'gif')
          ? replyTo?.mediaUrl
            : null,
      );
      _updatePrivateReadStatus();
      _onCancelReply();
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("فشل إرسال GIF")),
      );
    }
  }

  Future<void> _handleSendAudio(
      File audioFile, MessageModel? replyTo, int duration) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final privateChatProvider =
        Provider.of<PrivateChatProvider>(context, listen: false);
    final currentUser = userProvider.currentUser;
    if (currentUser == null) return;

    try {
      await privateChatProvider.sendAudioMessage(
        chatId: widget.chatId,
        messageId: _uuid.v4(),
        sender: currentUser,
        audioFile: audioFile,
        durationSeconds: duration,
        replyToId: replyTo?.id,
        replyText: replyTo?.text??
            (replyTo?.mediaType == 'image'
              ? "صورة 🖼️"
                : replyTo?.mediaType == 'gif'
                  ? "GIF 🎞️"
                    : replyTo?.mediaType == 'audio'
                      ? "🎙️ تسجيل صوتي"
                        : replyTo?.mediaType == 'sticker'
                          ? "ملصق 🏷️"
                            : null),
        replyToSenderName: replyTo?.senderName,
        replyToMediaUrl: (replyTo?.mediaType == 'image' || replyTo?.mediaType == 'gif')
          ? replyTo?.mediaUrl
            : null,
      );
      _updatePrivateReadStatus();
      _onCancelReply();
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("فشل إرسال التسجيل الصوتي")),
      );
    }
  }

  Future<void> _handleSendSticker(
      StickerModel sticker, MessageModel? replyTo) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final privateChatProvider =
        Provider.of<PrivateChatProvider>(context, listen: false);
    final currentUser = userProvider.currentUser;
    if (currentUser == null) return;

    try {
      await privateChatProvider.sendStickerMessage(
        chatId: widget.chatId,
        messageId: _uuid.v4(),
        sender: currentUser,
        stickerUrl: sticker.imageUrl,
        replyToId: replyTo?.id,
        replyText: replyTo?.text??
            (replyTo?.mediaType == 'image'
              ? "صورة 🖼️"
                : replyTo?.mediaType == 'gif'
                  ? "GIF 🎞️"
                    : replyTo?.mediaType == 'audio'
                      ? "🎙️ تسجيل صوتي"
                        : replyTo?.mediaType == 'sticker'
                          ? "ملصق 🏷️"
                            : null),
        replyToSenderName: replyTo?.senderName,
        replyToMediaUrl: (replyTo?.mediaType == 'image' || replyTo?.mediaType == 'gif')
          ? replyTo?.mediaUrl
            : null,
      );
      _updatePrivateReadStatus();
      _onCancelReply();
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("فشل إرسال الملصق")),
      );
    }
  }

  void _onCancelReply() {
    if (mounted) setState(() => _replyingMessage = null);
  }

  Widget _buildBackground(String? backgroundPath) {
    if (backgroundPath == null || backgroundPath.isEmpty) {
      return const SizedBox.shrink();
    }

    final bool isNetwork = backgroundPath.startsWith('http');

    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          isNetwork
            ? Image.network(backgroundPath, fit: BoxFit.cover)
              : Image.file(File(backgroundPath), fit: BoxFit.cover),
          Container(
            color: Colors.black.withValues(alpha: 0.38),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<UserProvider>().currentUser;
    final privateChatProvider = context.read<PrivateChatProvider>();

    if (currentUser == null) {
      return const Scaffold(body: LoadingWidget());
    }

    final backgroundPath =
        context.watch<ChatBackgroundProvider>().privateBackgroundPath;
    final bool hasBackground =
        backgroundPath!= null && backgroundPath.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: NetworkImage(widget.otherUser.avatarUrl),
            ),
            const SizedBox(width: 10),
            Text(widget.otherUser.username),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'background') {
                _openBackgroundPicker();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'background',
                child: Row(
                  children: [
                    Icon(Icons.wallpaper_outlined),
                    SizedBox(width: 12),
                    Text('خلفية الدردشة'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildBackground(backgroundPath),
          Column(
            children: [
              Expanded(
                child: StreamBuilder<List<MessageModel>>(
                  stream: _messageStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        _currentMessages.isEmpty) {
                      return const LoadingWidget();
                    }

                    if (snapshot.hasData) {
                      final newMessages = snapshot.data!;

                      for (final msg in newMessages) {
                        if (msg.senderId!= currentUser.id) {
                          if (!msg.isDelivered) {
                            privateChatProvider.markAsDelivered(
                              chatId: widget.chatId,
                              messageId: msg.id,
                            );
                          }
                          if (!msg.isRead) {
                            privateChatProvider.markAsRead(
                              chatId: widget.chatId,
                              messageId: msg.id,
                            );
                          }
                        }
                      }

                      if (newMessages.length > _currentMessages.length) {
                        Future.microtask(() => _updatePrivateReadStatus());
                        WidgetsBinding.instance
                          .addPostFrameCallback((_) => _scrollToBottom());
                      }
                      _currentMessages = newMessages;
                    }

                    if (_currentMessages.isEmpty) {
                      return const EmptyStateWidget(
                        title: "لا توجد رسائل",
                        subtitle: "ابدأ المحادثة الآن",
                        icon: Icons.chat_bubble_outline,
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      itemCount: _currentMessages.length,
                      itemBuilder: (context, index) {
                        final message = _currentMessages[index];
                        final isMe = message.senderId == currentUser.id;

                        final sender = MemberModel(
                          userId: message.senderId,
                          groupId: 'private',
                          role: message.senderRole?? Roles.member,
                          joinedAt: DateTime.now(),
                          displayName: message.senderName,
                          characterImageUrl: message.senderAvatar,
                        );

                        return MessageBubble(
                          key: ValueKey(message.id),
                          message: message,
                          sender: sender,
                          isMe: isMe,
                          groupId: widget.chatId,
                          hasBackground: hasBackground,
                          onReply: (msg) =>
                              setState(() => _replyingMessage = msg),
                          onTapReply: (replyId) => _scrollToMessage(replyId),
                        );
                      },
                    );
                  },
                ),
              ),
              MessageInputBar(
                groupId: widget.chatId,
                currentMember: MemberModel(
                  userId: currentUser.id,
                  groupId: 'private',
                  role: Roles.member,
                  joinedAt: DateTime.now(),
                  displayName: currentUser.username,
                ),
                onSendText: _handleSendText,
                onSendImage: _handleSendImage,
                onSendGif: _handleSendGif,
                onSendAudio: _handleSendAudio,
                onSendSticker: _handleSendSticker,
                replyingMessage: _replyingMessage,
                onCancelReply: _onCancelReply,
                isPrivate: true,
              ),
            ],
          ),
          Positioned(
            bottom: 80,
            right: 16,
            child: AnimatedOpacity(
              opacity: _showScrollDown? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: _showScrollDown
                ? FloatingActionButton.small(
                      backgroundColor: Theme.of(context).primaryColor,
                      onPressed: _scrollToBottom,
                      child: const Icon(Icons.arrow_downward,
                          color: Colors.white),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}