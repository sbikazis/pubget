// lib/features/private_chat/private_chats_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../providers/private_chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state_widget.dart';
import 'private_chat_screen.dart';

class PrivateChatsListScreen extends StatefulWidget {
  const PrivateChatsListScreen({super.key});

  @override
  State<PrivateChatsListScreen> createState() => _PrivateChatsListScreenState();
}

class _PrivateChatsListScreenState extends State<PrivateChatsListScreen> {
  // cache لتجنب إعادة جلب بيانات المستخدم في كل rebuild
  final Map<String, Future<UserModel?>> _userCache = {};

  Future<UserModel?> _loadOtherUser(String userId) {
    return _userCache.putIfAbsent(
      userId,
      () => Provider.of<PrivateChatProvider>(context, listen: false)
          .getUserById(userId),
    );
  }

  void _openChat({required String chatId, required UserModel otherUser}) {
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
    final currentUser = Provider.of<AuthProvider>(context).user;
    final chatProvider = Provider.of<PrivateChatProvider>(context, listen: false);

    if (currentUser == null) {
      return const Scaffold(
        body: EmptyStateWidget(
          title: "يجب تسجيل الدخول",
          subtitle: "يرجى تسجيل الدخول لعرض دردشاتك الخاصة",
          icon: Icons.lock_outline,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("الدردشات الخاصة"),
        centerTitle: true,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: chatProvider.streamUserChats(userId: currentUser.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingWidget(message: "جاري تحميل الدردشات...");
          }

          final chats = snapshot.data ?? [];

          if (chats.isEmpty) {
            return const EmptyStateWidget(
              title: "لا توجد دردشات بعد",
              subtitle: "ابدأ محادثة مع معجبيك الآن",
              icon: Icons.chat_bubble_outline,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final chatId = chat["chatId"] as String;
              final lastMessage =
                  chat["lastMessageText"] as String? ?? "اضغط لفتح المحادثة";
              final otherUserId = chat["userA"] == currentUser.id
                  ? chat["userB"] as String
                  : chat["userA"] as String;

              return FutureBuilder<UserModel?>(
                future: _loadOtherUser(otherUserId),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const ListTile(title: Text("جاري التحميل..."));
                  }

                  final otherUser = userSnapshot.data;
                  if (otherUser == null) return const SizedBox.shrink();

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey[200],
                      backgroundImage: otherUser.avatarUrl.isNotEmpty
                          ? NetworkImage(otherUser.avatarUrl)
                          : null,
                      child: otherUser.avatarUrl.isEmpty
                          ? const Icon(Icons.person, color: Colors.grey)
                          : null,
                    ),
                    title: Text(
                      otherUser.username,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StreamBuilder<int>(
                          stream: chatProvider.streamPrivateUnreadCount(
                            chatId: chatId,
                            userId: currentUser.id,
                          ),
                          initialData: 0,
                          builder: (context, countSnap) {
                            final count = countSnap.data ?? 0;
                            if (count == 0) return const SizedBox.shrink();
                            return Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                borderRadius:
                                    BorderRadius.all(Radius.circular(10)),
                              ),
                              child: Text(
                                count > 9 ? '+9' : '$count',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios, size: 14),
                      ],
                    ),
                    onTap: () => _openChat(chatId: chatId, otherUser: otherUser),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
