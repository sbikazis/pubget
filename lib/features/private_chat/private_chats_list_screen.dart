// lib/features/private_chat/private_chats_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';


import '../../providers/private_chat_provider.dart';

import '../../providers/auth_provider.dart'; 
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
  
  // ✅ دالة جلب بيانات المستخدم الآخر (تم الحفاظ عليها كما هي)
  Future<UserModel?> _loadOtherUser(String userId) async {
    final provider =
        Provider.of<PrivateChatProvider>(context, listen: false);
    return await provider.getUserById(userId);
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
    final authProvider = Provider.of<AuthProvider>(context);
    final chatProvider = Provider.of<PrivateChatProvider>(context);
    final currentUser = authProvider.user;

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
      // ✅ التعديل الجوهري: استخدام FutureBuilder أو Stream لجلب القائمة
      // لضمان تحديث "آخر رسالة" والترتيب تلقائياً
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: chatProvider.getUserChats(userId: currentUser.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingWidget(
              message: "جاري تحميل الدردشات...",
            );
          }

          final chats = snapshot.data ?? [];

          if (chats.isEmpty) {
            return const EmptyStateWidget(
              title: "لا توجد دردشات بعد",
              subtitle: "ابدأ محادثة مع معجبيك الآن",
              icon: Icons.chat_bubble_outline,
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {}); // إعادة بناء الواجهة لجلب البيانات مجدداً
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];
                final chatId = chat["chatId"];
                
                // ✅ عرض آخر رسالة بدلاً من النص الثابت
                final lastMessage = chat["lastMessageText"] ?? "اضغط لفتح المحادثة";

                final otherUserId =
                    chat["userA"] == currentUser.id
                        ? chat["userB"]
                        : chat["userA"];

                return FutureBuilder<UserModel?>(
                  future: _loadOtherUser(otherUserId),
                  builder: (context, userSnapshot) {
                    if (userSnapshot.connectionState == ConnectionState.waiting) {
                      return const ListTile(
                        title: Text("جاري التحميل..."),
                      );
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
                          // ✅ عداد الرسائل غير المقروءة (مراقب حي)
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
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.all(Radius.circular(10)),
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
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                          ),
                        ],
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
        },
      ),
    );
  }
}