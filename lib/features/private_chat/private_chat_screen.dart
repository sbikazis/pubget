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

import '../groups/chat/massage_bubble.dart'; // تصحيح بسيط في اسم الملف (Message بدل Massage)
import '../groups/chat/massage_input_bar.dart'; // تصحيح بسيط في اسم الملف


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
  
  // ✅ تخزين الـ Stream لمنع الرعشة وإعادة البناء
  late Stream<List<MessageModel>> _messageStream;
  List<MessageModel> _currentMessages = [];

  @override
  void initState() {
    super.initState();
    // ✅ تثبيت الـ Stream هنا لضمان استقرار الاتصال
    _messageStream = Provider.of<PrivateChatProvider>(context, listen: false)
        .streamMessages(chatId: widget.chatId);

    // ✅ التعديل الأول: تصفير العداد فور دخول المحادثة الخاصة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePrivateReadStatus();
    });
  }

  @override
  void dispose() {
    // ✅ التعديل الثالث: تصفير العداد عند مغادرة المحادثة لضمان دقة آخر ظهور
    _updatePrivateReadStatus();
    _scrollController.dispose();
    super.dispose();
  }

  // ✅ دالة مساعدة لتحديث حالة القراءة في الدردشة الخاصة
  void _updatePrivateReadStatus() {
    // نستخدم try-catch للتأكد من عدم تعطل التطبيق إذا أغلق المستخدم الشاشة بسرعة
    try {
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

  // ✅ دالة التمرير للأسفل (تحسين السلاسة)
  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  // ✅ دالة الانتقال لرسالة محددة (عند الضغط على الرد)
  void _scrollToMessage(String messageId) {
    final index = _currentMessages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      // حساب تقريبي للموقع
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
      
      // تحديث حالة القراءة فور الإرسال لضمان تصفير العداد محلياً أيضاً
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

      // تحديث حالة القراءة فور إرسال الصورة
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
                  
                  // ✅ تحديث حالة القراءة عند استقبال رسائل جديدة
                  if (_currentMessages.length < newMessages.length) {
                    Future.microtask(() => _updatePrivateReadStatus());
                    
                    // ✅ التعديل الجوهري: التمرير للأسفل فقط في حال وجود رسائل جديدة
                    // لمنع الاهتزاز عند مجرد إضافة إيموجي (تفاعل)
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

          MessageInputBar(
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
