// lib/features/edits/edit_share_sheet.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/home_provider.dart';
import '../../providers/private_chat_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/edits_model.dart';

class EditShareSheet extends StatefulWidget {
  final EditModel edit;

  const EditShareSheet({super.key, required this.edit});

  @override
  State<EditShareSheet> createState() => _EditShareSheetState();
}

class _EditShareSheetState extends State<EditShareSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSending = false;
  String? _sentTo;

  // ── بيانات الدردشات الخاصة مع المستخدمين (جلب مرة واحدة)
  List<Map<String, dynamic>> _privateChats = [];
  Map<String, dynamic> _usersCache = {};
  bool _chatsLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPrivateChatsWithUsers();
  }

  Future<void> _loadPrivateChatsWithUsers() async {
    final user = context.read<UserProvider>().currentUser;
    if (user == null) {
      if (mounted) setState(() => _chatsLoading = false);
      return;
    }

    final privateChatProvider = context.read<PrivateChatProvider>();

    try {
      // 1. جلب قائمة الدردشات
      final chats = await privateChatProvider.getUserChats(userId: user.id);

      // 2. استخراج IDs المستخدمين الآخرين (بدون تكرار)
      final otherIds = chats
          .map((c) => c['userA'] == user.id ? c['userB'] : c['userA'])
          .toSet()
          .toList();

      // 3. جلب بيانات جميع المستخدمين دفعة واحدة
      final usersData = <String, dynamic>{};
      await Future.wait(
        otherIds.map((id) async {
          final otherUser = await privateChatProvider.getUserById(id);
          if (otherUser != null) usersData[id] = otherUser;
        }),
      );

      if (mounted) {
        setState(() {
          _privateChats = chats;
          _usersCache = usersData;
          _chatsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _chatsLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _sendToGroup(String groupId, String groupName) async {
    if (_isSending) return;
    setState(() {
      _isSending = true;
      _sentTo = groupId;
    });

    final user = context.read<UserProvider>().currentUser;
    if (user == null) return;

    try {
      final messageId = DateTime.now().millisecondsSinceEpoch.toString();
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('messages')
          .doc(messageId)
          .set({
        'id': messageId,
        'senderId': user.id,
        'senderName': user.username,
        'senderAvatar': user.avatarUrl,
        'senderIsPremium': user.isPremium,
        'text': '',
        'mediaUrl': widget.edit.videoUrl,
        'mediaType': 'edit_share',
        'editThumbnail': widget.edit.thumbnailUrl,
        'editAnimeTitle': widget.edit.animeTitle,
        'editId': widget.edit.id,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _isSending = false;
          _sentTo = null;
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم الإرسال إلى $groupName ✅')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
          _sentTo = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الإرسال: $e')),
        );
      }
    }
  }

  Future<void> _sendToPrivateChat(
      String chatId, String otherUserId, String otherName) async {
    if (_isSending) return;
    setState(() {
      _isSending = true;
      _sentTo = chatId;
    });

    final user = context.read<UserProvider>().currentUser;
    if (user == null) return;

    try {
      final messageId = DateTime.now().millisecondsSinceEpoch.toString();
      await FirebaseFirestore.instance
          .collection('privateChats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .set({
        'id': messageId,
        'senderId': user.id,
        'senderName': user.username,
        'senderAvatar': user.avatarUrl,
        'senderIsPremium': user.isPremium,
        'text': '',
        'mediaUrl': widget.edit.videoUrl,
        'mediaType': 'edit_share',
        'editThumbnail': widget.edit.thumbnailUrl,
        'editAnimeTitle': widget.edit.animeTitle,
        'editId': widget.edit.id,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('privateChats')
          .doc(chatId)
          .update({
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageText': '🎬 إيديت',
      });

      if (mounted) {
        setState(() {
          _isSending = false;
          _sentTo = null;
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم الإرسال إلى $otherName ✅')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
          _sentTo = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الإرسال: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeProvider = context.read<HomeProvider>();
    final user = context.read<UserProvider>().currentUser;

    final allGroups = [
      ...homeProvider.myGroups,
      ...homeProvider.joinedGroups,
    ];

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ── الهيدر
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'مشاركة الإيديت',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // ── معاينة الإيديت
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: widget.edit.thumbnailUrl.isNotEmpty
                      ? Image.network(
                          widget.edit.thumbnailUrl,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 60,
                          height: 60,
                          color: Colors.white12,
                          child: const Icon(Icons.play_circle,
                              color: Colors.white54),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🎌 ${widget.edit.animeTitle}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (widget.edit.caption.isNotEmpty)
                        Text(
                          widget.edit.caption,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white12),

          // ── تابس
          TabBar(
            controller: _tabController,
            indicatorColor: Colors.deepPurple,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            tabs: const [
              Tab(text: 'المجموعات'),
              Tab(text: 'الدردشات الخاصة'),
            ],
          ),

          // ── المحتوى
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ── المجموعات
                allGroups.isEmpty
                    ? const Center(
                        child: Text(
                          'لا توجد مجموعات',
                          style: TextStyle(color: Colors.white38),
                        ),
                      )
                    : ListView.builder(
                        itemCount: allGroups.length,
                        itemBuilder: (context, index) {
                          final group = allGroups[index];
                          final isSending =
                              _isSending && _sentTo == group.id;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: group.imageUrl.isNotEmpty
                                  ? NetworkImage(group.imageUrl)
                                  : null,
                              backgroundColor: Colors.white12,
                              child: group.imageUrl.isEmpty
                                  ? const Icon(Icons.group,
                                      color: Colors.white54)
                                  : null,
                            ),
                            title: Text(
                              group.name,
                              style: const TextStyle(color: Colors.white),
                            ),
                            trailing: isSending
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send,
                                    color: Colors.deepPurple),
                            onTap: () =>
                                _sendToGroup(group.id, group.name),
                          );
                        },
                      ),

                // ── الدردشات الخاصة
                user == null
                    ? const Center(
                        child: Text(
                          'يجب تسجيل الدخول',
                          style: TextStyle(color: Colors.white38),
                        ),
                      )
                    : _chatsLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _privateChats.isEmpty
                            ? const Center(
                                child: Text(
                                  'لا توجد دردشات خاصة',
                                  style: TextStyle(color: Colors.white38),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _privateChats.length,
                                itemBuilder: (context, index) {
                                  final chat = _privateChats[index];
                                  final chatId = chat['chatId'];
                                  final otherId = chat['userA'] == user.id
                                      ? chat['userB']
                                      : chat['userA'];
                                  final otherUser = _usersCache[otherId];
                                  final name = otherUser?.username ?? '...';
                                  final avatar = otherUser?.avatarUrl ?? '';
                                  final isSending =
                                      _isSending && _sentTo == chatId;

                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundImage: avatar.isNotEmpty
                                          ? NetworkImage(avatar)
                                          : null,
                                      backgroundColor: Colors.white12,
                                      child: avatar.isEmpty
                                          ? const Icon(Icons.person,
                                              color: Colors.white54)
                                          : null,
                                    ),
                                    title: Text(
                                      name,
                                      style: const TextStyle(
                                          color: Colors.white),
                                    ),
                                    trailing: isSending
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.send,
                                            color: Colors.deepPurple),
                                    onTap: () => _sendToPrivateChat(
                                        chatId, otherId, name),
                                  );
                                },
                              ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}