// lib/features/edits/edit_comments_sheet.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/edits_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../models/edits_model.dart';
import '../profile/profile_sceen.dart';

class EditCommentsSheet extends StatefulWidget {
  final String editId;
  final String currentUserId;
  final String? scrollToCommentId; // ← جديد

  const EditCommentsSheet({
    super.key,
    required this.editId,
    required this.currentUserId,
    this.scrollToCommentId,
  });

  @override
  State<EditCommentsSheet> createState() => _EditCommentsSheetState();
}

class _EditCommentsSheetState extends State<EditCommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, GlobalKey> _commentKeys = {};
  bool _isSending = false;
  String? _replyToId;
  String? _replyToName;

  @override
  void initState() {
    super.initState();
    // سكرول للتعليق بعد التحميل
    if (widget.scrollToCommentId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToComment());
    }
  }

  void _scrollToComment() {
    final key = _commentKeys[widget.scrollToCommentId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    final user = context.read<UserProvider>().currentUser;
    if (user == null) return;

    final editsProvider = context.read<EditsProvider>();
    final notificationsProvider = context.read<NotificationsProvider>();
    final edit = editsProvider.getEditById(widget.editId);

    setState(() => _isSending = true);

    try {
      // 1. حفظ التعليق وجيب الـ ID
      final commentId = await editsProvider.addComment(
        editId: widget.editId,
        userId: user.id,
        username: user.username,
        userAvatar: user.avatarUrl,
        text: text,
      );

      // 2. إرسال إشعار مع الـ commentId
      if (edit != null && edit.uploaderId != user.id && commentId != null) {
        await notificationsProvider.createCommentNotification(
          toUserId: edit.uploaderId,
          fromUserId: user.id,
          fromUsername: user.username,
          editId: widget.editId,
          commentText: text,
          commentId: commentId,
        );
      }

      _controller.clear();
      setState(() {
        _replyToId = null;
        _replyToName = null;
        _isSending = false;
      });

      _scrollToBottom();
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الإرسال: $e')),
        );
      }
    }
  }

  Future<void> _toggleCommentLike(String commentId, List likes) async {
    final userId = widget.currentUserId;
    final ref = _firestore
        .collection('edits')
        .doc(widget.editId)
        .collection('comments')
        .doc(commentId);

    if (likes.contains(userId)) {
      await ref.update({'likes': FieldValue.arrayRemove([userId])});
    } else {
      await ref.update({'likes': FieldValue.arrayUnion([userId])});
    }
  }

  void _setReply(String commentId, String username) {
    setState(() {
      _replyToId = commentId;
      _replyToName = username;
    });
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyToId = null;
      _replyToName = null;
    });
  }

  void _openProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editsProvider = context.watch<EditsProvider>();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ── الهيدر
          Container(
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
                  'التعليقات',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),

          // ── قائمة التعليقات (تستخدم streamComments)
          Expanded(
            child: StreamBuilder<List<CommentModel>>(
              stream: editsProvider.streamComments(widget.editId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final comments = snapshot.data ?? [];

                if (comments.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            color: Colors.white24, size: 48),
                        SizedBox(height: 12),
                        Text(
                          'لا يوجد تعليقات بعد\nكن أول من يعلق!',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: Colors.white38, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                // أنشئ keys للسكرول
                for (final c in comments) {
                  _commentKeys.putIfAbsent(c.id, () => GlobalKey());
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    final isLiked = comment.likes.contains(widget.currentUserId);

                    return Container(
                      key: _commentKeys[comment.id],
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // الصورة مع ضغط للبروفايل
                          GestureDetector(
                            onTap: () => _openProfile(comment.userId),
                            child: CircleAvatar(
                              radius: 18,
                              backgroundImage: comment.userAvatar.isNotEmpty
                                  ? NetworkImage(comment.userAvatar)
                                  : null,
                              backgroundColor: Colors.white24,
                              child: comment.userAvatar.isEmpty
                                  ? const Icon(Icons.person,
                                      size: 18, color: Colors.white)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 10),

                          // المحتوى
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () => _openProfile(comment.userId),
                                  child: Text(
                                    comment.userName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  comment.text,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: () =>
                                      _setReply(comment.id, comment.userName),
                                  child: const Text(
                                    'رد',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // لايك التعليق
                          GestureDetector(
                            onTap: () => _toggleCommentLike(
                                comment.id, comment.likes),
                            child: Column(
                              children: [
                                Icon(
                                  isLiked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color:
                                      isLiked ? Colors.red : Colors.white38,
                                  size: 18,
                                ),
                                if (comment.likes.isNotEmpty)
                                  Text(
                                    '${comment.likes.length}',
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ── رد على
          if (_replyToName != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: Colors.white10,
              child: Row(
                children: [
                  Text(
                    'رداً على @$_replyToName',
                    style: const TextStyle(
                        color: Colors.blueAccent, fontSize: 13),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _cancelReply,
                    child: const Icon(Icons.close,
                        color: Colors.white38, size: 18),
                  ),
                ],
              ),
            ),

          // ── حقل الكتابة
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    style: const TextStyle(color: Colors.white),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendComment(),
                    decoration: InputDecoration(
                      hintText: 'اكتب تعليقاً...',
                      hintStyle:
                          const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white10,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _isSending ? null : _sendComment,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Colors.deepPurple,
                      shape: BoxShape.circle,
                    ),
                    child: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send,
                            color: Colors.white, size: 18),
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
