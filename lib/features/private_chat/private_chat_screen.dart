import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/message_model.dart';
import '../../models/user_model.dart';

import '../../providers/private_chat_provider.dart';
import '../../providers/user_provider.dart';

import 'package:pubget/features/groups/chat/massage_bubble.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state_widget.dart';

import '../../core/theme/app_colors.dart';

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
  final TextEditingController _controller = TextEditingController();
  final Uuid _uuid = const Uuid();

  bool _sending = false;

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();

    if (text.isEmpty) return;

    final userProvider =
        Provider.of<UserProvider>(context, listen: false);

    final privateChatProvider =
        Provider.of<PrivateChatProvider>(context, listen: false);

    final currentUser = userProvider.currentUser;

    if (currentUser == null) return;

    setState(() {
      _sending = true;
    });

    try {
      await privateChatProvider.sendTextMessage(
        chatId: widget.chatId,
        messageId: _uuid.v4(),
        sender: currentUser,
        text: text,
      );

      _controller.clear();

      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to send message"),
        ),
      );
    }

    setState(() {
      _sending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    final currentUser = userProvider.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: LoadingWidget(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage:
                  NetworkImage(widget.otherUser.avatarUrl),
            ),
            const SizedBox(width: 10),
            Text(widget.otherUser.username),
          ],
        ),
      ),
      body: Column(
        children: [
          /// ===============================
          /// MESSAGES
          /// ===============================
          Expanded(
            child: Consumer<PrivateChatProvider>(
              builder: (context, provider, _) {
                return StreamBuilder<List<MessageModel>>(
                  stream: provider.streamMessages(
                    chatId: widget.chatId,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const LoadingWidget();
                    }

                    if (!snapshot.hasData ||
                        snapshot.data!.isEmpty) {
                      return const EmptyStateWidget(
                        title: "No messages yet",
                        subtitle:
                            "Start the conversation now",
                        icon: Icons.chat_bubble_outline,
                      );
                    }

                    final messages = snapshot.data!;

                    WidgetsBinding.instance
                        .addPostFrameCallback(
                            (_) => _scrollToBottom());

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          vertical: 10),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];

                        final isMe =
                            message.senderId ==
                                currentUser.id;

                        return MessageBubble(
                          message: message,
                          sender: null as dynamic,
                          isMe: isMe,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),

          /// ===============================
          /// INPUT BAR
          /// ===============================
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness ==
                      Brightness.dark
                  ? AppColors.darkSurface
                  : AppColors.lightSurface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).brightness ==
                          Brightness.dark
                      ? AppColors.darkBorder
                      : AppColors.lightBorder,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Write a message...",
                      filled: true,
                      fillColor: Theme.of(context)
                                  .brightness ==
                              Brightness.dark
                          ? AppColors.darkCard
                          : AppColors.lightCard,
                      contentPadding:
                          const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send,
                            color: Colors.white),
                    onPressed:
                        _sending ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}