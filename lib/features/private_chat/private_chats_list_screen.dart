import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/private_chat_provider.dart';
import '../../providers/user_provider.dart';

import '../../models/user_model.dart';

import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state_widget.dart';



import 'private_chat_screen.dart';


class PrivateChatsListScreen extends StatefulWidget {
  const PrivateChatsListScreen({super.key});

  @override
  State<PrivateChatsListScreen> createState() =>
      _PrivateChatsListScreenState();
}

class _PrivateChatsListScreenState
    extends State<PrivateChatsListScreen> {
  bool _loading = true;

  List<Map<String, dynamic>> _chats = [];

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    final userProvider =
        Provider.of<UserProvider>(context, listen: false);

    final chatProvider =
        Provider.of<PrivateChatProvider>(context, listen: false);

    final currentUser = userProvider.currentUser;

    if (currentUser == null) return;

    final chats = await chatProvider.getUserChats(
      userId: currentUser.id,
    );

    setState(() {
      _chats = chats;
      _loading = false;
    });
  }

  void _openChat({
    required String chatId,
    required UserModel otherUser,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrivateChatScreen(
          chatId: chatId,
          otherUser: otherUser,
        ),
      ),
    );
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
        title: const Text("Private Chats"),
      ),
      body: _loading
          ? const LoadingWidget(
              message: "Loading chats...",
            )
          : _chats.isEmpty
              ? const EmptyStateWidget(
                  title: "No chats yet",
                  subtitle:
                      "Start a conversation with someone",
                  icon: Icons.chat_outlined,
                )
              : ListView.builder(
                  itemCount: _chats.length,
                  itemBuilder: (context, index) {
                    final chat = _chats[index];

                    final chatId = chat["chatId"];

                    final userA = chat["userA"];
                    final userB = chat["userB"];

                    final otherUserId =
                        userA == currentUser.id
                            ? userB
                            : userA;

                    return FutureBuilder<UserModel?>(
                      future: _loadOtherUser(otherUserId),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const ListTile(
                            title: Text("Loading..."),
                          );
                        }

                        final otherUser = snapshot.data!;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: NetworkImage(
                              otherUser.avatarUrl,
                            ),
                          ),
                          title: Text(
                            otherUser.username,
                          ),
                          subtitle: const Text(
                            "Open conversation",
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () {
                            _openChat(
                              chatId: chatId,
                              otherUser: otherUser,
                            );
                          },
                        );
                      },
                    );
                  },
                ),
    );
  }

  Future<UserModel?> _loadOtherUser(String userId) async {
  final provider =
      Provider.of<PrivateChatProvider>(context, listen: false);

  return await provider.getUserById(userId);
}
}