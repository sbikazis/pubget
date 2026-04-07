// lib/features/private_chat/private_chats_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/private_chat_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart'; // ✅ مضاف للتحقق الاحتياطي من حالة المستخدم
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
    // ✅ استخدام Future.microtask لضمان استقرار سياق الـ Provider عند بدء التحميل
    Future.microtask(() => _loadChats());
  }

  Future<void> _loadChats() async {
    if (!mounted) return;

    final userProvider =
        Provider.of<UserProvider>(context, listen: false);
    final authProvider = 
        Provider.of<AuthProvider>(context, listen: false);
    final chatProvider =
        Provider.of<PrivateChatProvider>(context, listen: false);

    // ✅ منطق مرن: جلب المستخدم الحالي من UserProvider أو AuthProvider كخيار ثانٍ
    final currentUser = userProvider.currentUser ?? authProvider.user;

    if (currentUser == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final chats = await chatProvider.getUserChats(
        userId: currentUser.id,
      );

      if (mounted) {
        setState(() {
          _chats = chats;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading private chats: $e");
      // ✅ ضمان تحويل حالة التحميل إلى false حتى في حال وقوع خطأ لمنع الدائرة اللانهائية
      if (mounted) {
        setState(() => _loading = false);
      }
    }
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
    // ✅ مراقبة AuthProvider لضمان تحديث الواجهة عند تغير حالة المستخدم
    final authProvider = Provider.of<AuthProvider>(context);
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
      body: _loading
          ? const LoadingWidget(
              message: "جاري تحميل الدردشات...",
            )
          : _chats.isEmpty
              ? const EmptyStateWidget(
                  title: "لا توجد دردشات بعد",
                  subtitle: "ابدأ محادثة مع معجبيك الآن",
                  icon: Icons.chat_bubble_outline,
                )
              : RefreshIndicator(
                  onRefresh: _loadChats,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
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
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const ListTile(
                              title: Text("جاري التحميل..."),
                            );
                          }

                          final otherUser = snapshot.data;
                          
                          // في حال تعذر تحميل بيانات الطرف الآخر
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
                            subtitle: const Text(
                              "اضغط لفتح المحادثة",
                              style: TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
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
                ),
    );
  }

  Future<UserModel?> _loadOtherUser(String userId) async {
    final provider =
        Provider.of<PrivateChatProvider>(context, listen: false);
    return await provider.getUserById(userId);
  }
}