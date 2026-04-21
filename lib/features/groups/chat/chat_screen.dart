// lib/features/groups/chat/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:uuid/uuid.dart'; 

import '../../../providers/chat_provider.dart';
import '../../../providers/game_provider.dart';
import '../../../providers/user_provider.dart';

import '../../../models/message_model.dart';
import '../../../models/member_model.dart';
import '../../../core/constants/roles.dart';

// ✅ استيراد خدمة الإعلانات لتفعيل منطق الأشباح عند الدخول
import '../../../services/monetization/ad_service.dart';

// ✅ تصحيح المسارات
import 'package:pubget/features/groups/chat/massage_bubble.dart';
import 'package:pubget/features/groups/chat/massage_input_bar.dart';

import '../events/guess_character_game_screen.dart';
import '../../../widgets/empty_state_widget.dart';

class ChatScreen extends StatefulWidget {
  final String groupId;

  const ChatScreen({super.key, required this.groupId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final Uuid _uuid = const Uuid(); 
  MemberModel? _currentMember;
 
  MessageModel? _replyingMessage;
  List<MessageModel> _cachedMessages = [];
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUserId = userProvider.currentUser?.id;
      final isPremium = userProvider.currentUser?.isPremium ?? false;

      if (currentUserId != null) {
        _loadCurrentMember(currentUserId);
        // ✅ التعديل الأول: تصفير العداد فور دخول الشاشة
        _updateReadStatus(currentUserId);

        // 🚀 تفعيل إعلان الدخول للمجموعة (منطق الأشباح)
        // سيتحقق الـ AdService تلقائياً من شرط الـ 5 دقائق والحد اليومي والبريميوم
        final adService = Provider.of<AdService>(context, listen: false);
        adService.tryShowGroupAd(isPremium: isPremium);
      }
    });
  }

  @override
  void dispose() {
    // ✅ التعديل الثالث: تصفير العداد عند مغادرة الشاشة لضمان تسجيل آخر تواجد
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUserId = userProvider.currentUser?.id;
    if (currentUserId != null) {
      _updateReadStatus(currentUserId);
    }
    _scrollController.dispose();
    super.dispose();
  }

  // دالة مساعدة لتحديث حالة القراءة
  void _updateReadStatus(String userId) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.updateLastRead(
      groupId: widget.groupId,
      userId: userId,
    );
  }

  Future<void> _loadCurrentMember(String userId) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    try {
      final member = await chatProvider.getMember(
        groupId: widget.groupId,
        userId: userId,
      );
      if (!mounted) return;
      setState(() => _currentMember = member);
    } catch (e) {
      debugPrint('Failed to load current member: $e');
    }
  }

  void _scrollToBottom({bool animate = true, bool force = false}) {
    if (!_scrollController.hasClients) return;
    if (!force && _scrollController.offset < _scrollController.position.maxScrollExtent - 200) {
      return;
    }
    final position = _scrollController.position.maxScrollExtent;
    if (animate) {
      _scrollController.animateTo(position, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } else {
      _scrollController.jumpTo(position);
    }
  }

  void _scrollToMessage(String messageId) {
    final index = _cachedMessages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      double targetOffset = index * 100.0;
      if (targetOffset > _scrollController.position.maxScrollExtent) {
        targetOffset = _scrollController.position.maxScrollExtent;
      }
      _scrollController.animateTo(targetOffset, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    }
  }

  void _onCancelReply() {
    setState(() => _replyingMessage = null);
  }

  // ✅ دالة إرسال النص الجديدة المتوافقة مع الـ Generic Bar
  Future<void> _handleSendText(String text, MessageModel? replyTo) async {
    if (_currentMember == null) return;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
   
    await chatProvider.sendTextMessage(
      groupId: widget.groupId,
      messageId: _uuid.v4(),
      sender: _currentMember!,
      text: text,
      replyToId: replyTo?.id,
      replyText: replyTo?.text ?? (replyTo?.mediaType == 'image' ? "صورة 🖼️" : null),
    );
   
    // بعد الإرسال، نحدث وقت القراءة مباشرة
    _updateReadStatus(_currentMember!.userId);
    _onCancelReply();
    _scrollToBottom(force: true);
  }

  // ✅ دالة إرسال الصور الجديدة المتوافقة مع الـ Generic Bar
  Future<void> _handleSendImage(File file, MessageModel? replyTo) async {
    if (_currentMember == null) return;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    await chatProvider.sendMediaMessage(
      groupId: widget.groupId,
      messageId: _uuid.v4(),
      sender: _currentMember!,
      file: file,
      mediaType: 'image',
      userAvatar: userProvider.currentUser?.avatarUrl,
      replyToId: replyTo?.id,
      replyText: replyTo?.text ?? (replyTo?.mediaType == 'image' ? "صورة 🖼️" : null),
    );

    // بعد الإرسال، نحدث وقت القراءة مباشرة
    _updateReadStatus(_currentMember!.userId);
    _onCancelReply();
    _scrollToBottom(force: true);
  }

  Future<void> _openGame() async {
    if (_currentMember == null) return;
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    try {
      final gameId = await gameProvider.createGame(
        groupId: widget.groupId,
        creatorUserId: _currentMember!.userId,
      );
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => GuessCharacterGameScreen(groupId: widget.groupId, gameId: gameId)));
    } catch (e) {
      debugPrint('Failed to create game: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Group Chat"), centerTitle: true),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: chatProvider.streamMessages(groupId: widget.groupId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && _isInitialLoad) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasData) {
                  // ✅ التعديل الثاني: عند وصول رسائل جديدة وأنت فاتح الشاشة، صفر العداد
                  if (_cachedMessages.length < snapshot.data!.length) {
                    final userProvider = Provider.of<UserProvider>(context, listen: false);
                    final currentUserId = userProvider.currentUser?.id;
                    if (currentUserId != null) {
                      _updateReadStatus(currentUserId);
                    }
                  }
                  _cachedMessages = snapshot.data!;
                  _isInitialLoad = false;
                }
                if (_cachedMessages.isEmpty) {
                  return const Center(child: EmptyStateWidget(title: 'لا توجد رسائل بعد', subtitle: 'ابدأ المحادثة الآن', icon: Icons.chat_bubble_outline));
                }
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(top: 12, bottom: 12),
                  itemCount: _cachedMessages.length,
                  itemBuilder: (context, index) {
                    final message = _cachedMessages[index];
                    final isMe = _currentMember != null && message.senderId == _currentMember!.userId;
                    
                    // ✅ التعديل المطلوب: تم تمرير message.senderIsPremium إلى MemberModel لضمان ظهور الجوهرة
                    final sender = isMe ? _currentMember! : MemberModel(
                            userId: message.senderId,
                            groupId: widget.groupId,
                            role: message.senderRole ?? Roles.member,
                            joinedAt: DateTime.now(),
                            displayName: message.senderName,
                            characterImageUrl: message.senderAvatar,
                            isPremium: message.senderIsPremium, 
                          );

                    return MessageBubble(
                      key: ValueKey(message.id),
                      message: message,
                      sender: sender,
                      isMe: isMe,
                      groupId: widget.groupId,
                      onReply: (msg) => setState(() => _replyingMessage = msg),
                      onTapReply: (replyId) => _scrollToMessage(replyId),
                    );
                  },
                );
              },
            ),
          ),

          if (_currentMember != null)
            MessageInputBar(
              onSendText: _handleSendText,
              onSendImage: _handleSendImage,
              replyingMessage: _replyingMessage,
              onCancelReply: _onCancelReply,
              onGamePressed: _openGame,
              isPrivate: false, // نحن في المجموعات، لذا الألعاب تظهر
            ),
        ],
      ),
    );
  }
}