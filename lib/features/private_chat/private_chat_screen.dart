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

import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state_widget.dart';

import '../groups/chat/massage_bubble.dart'; 
import '../groups/chat/massage_input_bar.dart'; 

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

  @override
  void initState() {
    super.initState();
    _messageStream = Provider.of<PrivateChatProvider>(context, listen: false)
        .streamMessages(chatId: widget.chatId);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePrivateReadStatus();
    });
  }

  @override
  void dispose() {
    _updatePrivateReadStatus();
    _scrollController.dispose();
    super.dispose();
  }

  void _updatePrivateReadStatus() {
    try {
      if (!mounted) return;
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final privateChatProvider = Provider.of<PrivateChatProvider>(context, listen: false);
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

  Future<void> _handleSendText(String text, MessageModel? replyTo) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final privateChatProvider = Provider.of<PrivateChatProvider>(context, listen: false);
    final currentUser = userProvider.currentUser;
    if (currentUser == null) return;

    try {
      await privateChatProvider.sendTextMessage(
        chatId: widget.chatId,
        messageId: _uuid.v4(),
        sender: currentUser,
        text: text,
        replyToId: replyTo?.id,
        replyText: replyTo?.text ?? (replyTo?.mediaType == 'image' ? "صورة 🖼️" : null),
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
    final privateChatProvider = Provider.of<PrivateChatProvider>(context, listen: false);
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
        replyText: replyTo?.text ?? (replyTo?.mediaType == 'image' ? "صورة 🖼️" : null),
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

  void _onCancelReply() {
    if (mounted) setState(() => _replyingMessage = null);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<UserProvider>().currentUser;

    if (currentUser == null) {
      return const Scaffold(body: LoadingWidget());
    }

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
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _messageStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && _currentMessages.isEmpty) {
                  return const LoadingWidget();
                }

                if (snapshot.hasData) {
                  final newMessages = snapshot.data!;
                  if (newMessages.length > _currentMessages.length) {
                    Future.microtask(() => _updatePrivateReadStatus());
                    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
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
                      onReply: (msg) => setState(() => _replyingMessage = msg),
                      onTapReply: (replyId) => _scrollToMessage(replyId),
                    );
                  },
                );
              },
            ),
          ),

          // ✅ التعديل هنا: تمرير المعطيات المطلوبة للدردشة الخاصة
          MessageInputBar(
            groupId: widget.chatId, // نمرر الـ chatId كبديل للـ groupId
            currentMember: MemberModel(
              userId: currentUser.id,
              groupId: 'private',
              role: Roles.member,
              joinedAt: DateTime.now(),
              displayName: currentUser.username,
            ),
            onSendText: _handleSendText,
            onSendImage: _handleSendImage,
            replyingMessage: _replyingMessage,
            onCancelReply: _onCancelReply,
            isPrivate: true, 
          ),
        ],
      ),
    );
  }
}