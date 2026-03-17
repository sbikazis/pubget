
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/chat_provider.dart';
import '../../../providers/game_provider.dart';
import '../../../providers/user_provider.dart';

import '../../../models/message_model.dart';
import '../../../models/member_model.dart';

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

  @override
  void initState() {
    super.initState();
    // بعد بناء الإطار الأول، نحصل على المستخدم الحالي
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
      print('Failed to load current member: $e');
    }
  }

  void _scrollToBottom({bool animate = true}) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position.maxScrollExtent;
    if (animate) {
      _scrollController.animateTo(
        position,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(position);
    }
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

  void _openMedia() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Media picker not implemented yet")),
    );
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
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return const Center(
                    child: EmptyStateWidget(
                      title: 'لا توجد رسائل بعد',
                      subtitle: 'ابدأ المحادثة الآن',
                      icon: Icons.chat_bubble_outline,
                    ),
                  );
                }

                // Scroll to bottom بعد بناء الإطار
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(top: 12, bottom: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];

                    // تحقق إذا الرسالة من العضو الحالي
                    final isMe = _currentMember != null &&
                        message.senderId == _currentMember!.userId;

                    // إذا لم يكن العضو الحالي مرسل الرسالة، أنشئ MemberModel مؤقت
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
                    );
                  },
                );
              },
            ),
          ),

          // MessageInputBar يظهر فقط إذا تم تحميل العضو الحالي
          if (_currentMember != null)
            MessageInputBar(
              groupId: widget.groupId,
              sender: _currentMember!,
              onGamePressed: _openGame,
              onMediaPressed: _openMedia,
              onSendMessage: (String text) {
                // Scroll تلقائي عند إرسال رسالة جديدة
                _scrollToBottom();
              },
            ),
        ],
      ),
    );
  }
}