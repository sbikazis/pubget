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
      // ✅ تحميل الخلفية المحفوظة محلياً لهذه المحادثة
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
    if (show != _showScrollDown) {
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

      if (currentUserId != null) {
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
    if (index != -1) {
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

  // ✅ فتح شيت اختيار الخلفية الشخصية
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
        replyText: replyTo?.text ??
            (replyTo?.mediaType == 'image'
                ? "صورة 🖼️"
                : replyTo?.mediaType == 'gif'
                    ? "GIF 🎞️"
                    : replyTo?.mediaType == 'audio'
                        ? "🎙️ تسجيل صوتي"
                        : null),
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
        replyText: replyTo?.text ??
            (replyTo?.mediaType == 'image' ? "صورة 🖼️" : null),
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
        replyText: replyTo?.mediaType == 'gif' ? "GIF 🎞️" : null,
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
        replyText: replyTo?.text ??
            (replyTo?.mediaType == 'audio' ? "🎙️ تسجيل صوتي" : null),
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

  void _onCancelReply() {
    if (mounted) setState(() => _replyingMessage = null);
  }

  // ✅ بناء طبقة الخلفية مع Overlay
  Widget _buildBackground(String? backgroundPath) {
    if (backgroundPath == null || backgroundPath.isEmpty) {
      return const SizedBox.shrink();
    }

    final bool isNetwork = backgroundPath.startsWith('http');

    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // صورة الخلفية (محلية أو من الشبكة)
          isNetwork
              ? Image.network(backgroundPath, fit: BoxFit.cover)
              : Image.file(File(backgroundPath), fit: BoxFit.cover),
          // ✅ Overlay شفاف لضمان وضوح عناصر الدردشة
          Container(
            color: Colors.black.withOpacity(0.38),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<UserProvider>().currentUser;

    if (currentUser == null) {
      return const Scaffold(body: LoadingWidget());
    }

    // ✅ الاستماع للخلفية من ChatBackgroundProvider
    final backgroundPath =
        context.watch<ChatBackgroundProvider>().privateBackgroundPath;
    final bool hasBackground =
        backgroundPath != null && backgroundPath.isNotEmpty;

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
        // ✅ زر اختيار الخلفية في الـ AppBar
        actions: [
          IconButton(
            onPressed: _openBackgroundPicker,
            icon: const Icon(Icons.wallpaper_outlined),
            tooltip: 'خلفية الدردشة',
          ),
        ],
      ),
      body: Stack(
        children: [
          // ✅ الطبقة السفلى: صورة الخلفية + Overlay
          _buildBackground(backgroundPath),

          // الطبقة العليا: محتوى الدردشة
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
                          role: message.senderRole ?? Roles.member,
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
                          // ✅ تمرير حالة الخلفية لـ MessageBubble
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
                replyingMessage: _replyingMessage,
                onCancelReply: _onCancelReply,
                isPrivate: true,
              ),
            ],
          ),

          // زر التمرير للأسفل
          Positioned(
            bottom: 80,
            right: 16,
            child: AnimatedOpacity(
              opacity: _showScrollDown ? 1.0 : 0.0,
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