// lib/features/groups/chat/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../../providers/chat_provider.dart';
import '../../../providers/game_provider.dart';
import '../../../providers/user_provider.dart';

import '../../../models/message_model.dart';
import '../../../models/member_model.dart';

// ✅ تم تصحيح الأخطاء الإملائية في المسارات أدناه
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
  MemberModel? _currentMember;
  
  // ✅ إضافة حالة الرسالة التي يتم الرد عليها
  MessageModel? _replyingMessage;

  // ✅ متغيرات جديدة للتحكم في سلاسة القائمة
  List<MessageModel> _cachedMessages = [];
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUserId = userProvider.currentUser?.id;
      if (currentUserId != null) {
        _loadCurrentMember(currentUserId);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

  // ✅ تحسين دالة التمرير لتكون ذكية (لا تقفز إذا كان المستخدم في الأعلى)
  void _scrollToBottom({bool animate = true, bool force = false}) {
    if (!_scrollController.hasClients) return;
    
    // إذا كان المستخدم يقرأ رسائل قديمة (ليس عند النهاية)، لا تجبره على النزول إلا إذا أرسل هو رسالة (force)
    if (!force && _scrollController.offset < _scrollController.position.maxScrollExtent - 200) {
      return; 
    }

    final position = _scrollController.position.maxScrollExtent;
    if (animate) {
      _scrollController.animateTo(
        position,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(position);
    }
  }

  // ✅ دالة جديدة: الانتقال إلى رسالة معينة (عند الضغط على الرد)
  void _scrollToMessage(String messageId) {
    final index = _cachedMessages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      // حساب الموقع التقريبي (هذا يعتمد على متوسط طول الفقاعة، لعدم وجود ScrollToIndex في Flutter افتراضياً)
      // سنستخدم JumpTo مبدئياً أو تحريك بسيط
      // ملاحظة: لضمان دقة 100% يفضل استخدام مكتبة scrollable_positioned_list مستقبلاً
      double targetOffset = index * 100.0; // قيمة تقديرية
      if (targetOffset > _scrollController.position.maxScrollExtent) {
        targetOffset = _scrollController.position.maxScrollExtent;
      }
      
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('جاري الانتقال للرسالة الأصلية...'), duration: Duration(milliseconds: 500)),
      );
    }
  }

  void _onCancelReply() {
    setState(() => _replyingMessage = null);
  }

  Future<void> _openGame() async {
    if (_currentMember == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن بدء اللعبة الآن')),
      );
      return;
    }

    final gameProvider = Provider.of<GameProvider>(context, listen: false);

    try {
      final gameId = await gameProvider.createGame(
        groupId: widget.groupId,
        creatorUserId: _currentMember!.userId,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GuessCharacterGameScreen(
            groupId: widget.groupId,
            gameId: gameId,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل إنشاء اللعبة: ${e.toString()}')),
      );
    }
  }

  Future<void> _openMedia() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null && _currentMember != null) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      try {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('جاري رفع الصورة...')),
        );

        await chatProvider.sendMediaMessage(
          groupId: widget.groupId,
          messageId: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: _currentMember!,
          file: File(image.path),
          mediaType: 'image',
          userAvatar: userProvider.currentUser?.avatarUrl,
          replyToId: _replyingMessage?.id,
          replyText: _replyingMessage?.text ?? _replyingMessage?.mediaType,
        );

        _onCancelReply();
        _scrollToBottom(force: true); // إجبار التمرير لأن المستخدم هو من أرسل
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل رفع الصورة: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Group Chat"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: chatProvider.streamMessages(groupId: widget.groupId),
              builder: (context, snapshot) {
                // ✅ تحسين: لا تظهر مؤشر التحميل إذا كان لدينا بيانات كاش مسبقة
                if (snapshot.connectionState == ConnectionState.waiting && _isInitialLoad) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasData) {
                  _cachedMessages = snapshot.data!;
                  _isInitialLoad = false;
                }

                if (_cachedMessages.isEmpty) {
                  return const Center(
                    child: EmptyStateWidget(
                      title: 'لا توجد رسائل بعد',
                      subtitle: 'ابدأ المحادثة الآن',
                      icon: Icons.chat_bubble_outline,
                    ),
                  );
                }

                // التمرير التلقائي عند وصول رسائل جديدة بذكاء
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(top: 12, bottom: 12),
                  itemCount: _cachedMessages.length,
                  itemBuilder: (context, index) {
                    final message = _cachedMessages[index];
                    final isMe = _currentMember != null && message.senderId == _currentMember!.userId;

                    final sender = isMe
                        ? _currentMember!
                        : MemberModel(
                            userId: message.senderId,
                            groupId: widget.groupId,
                            role: message.senderRole,
                            joinedAt: DateTime.now(),
                            displayName: message.senderName,
                            characterImageUrl: message.senderAvatar,
                          );

                    return MessageBubble(
                      key: ValueKey(message.id),
                      message: message,
                      sender: sender,
                      isMe: isMe,
                      groupId: widget.groupId,
                      onReply: (msg) => setState(() => _replyingMessage = msg),
                      // ✅ تفعيل وظيفة الضغط على الرد للذهاب للرسالة الأصلية
                      onTapReply: (replyId) => _scrollToMessage(replyId), 
                    );
                  },
                );
              },
            ),
          ),

          if (_currentMember != null)
            MessageInputBar(
              groupId: widget.groupId,
              sender: _currentMember!,
              replyingMessage: _replyingMessage,
              onCancelReply: _onCancelReply,
              onGamePressed: _openGame,
              onMediaPressed: _openMedia,
              onSendMessage: (String text) {
                _onCancelReply();
                _scrollToBottom(force: true); // إجبار التمرير للأسفل عند الإرسال
              },
            ),
        ],
      ),
    );
  }
}