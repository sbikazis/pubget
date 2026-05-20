// lib/features/edits/edit_comments_sheet.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';

class EditCommentsSheet extends StatefulWidget {
  final String editId;
  final String currentUserId;

  const EditCommentsSheet({
    super.key,
    required this.editId,
    required this.currentUserId,
  });

  @override
  State<EditCommentsSheet> createState() => _EditCommentsSheetState();
}

class _EditCommentsSheetState extends State<EditCommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isSending = false;
  String? _replyToId;
  String? _replyToName;

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

    setState(() => _isSending = true);

    try {
      final commentRef = _firestore
          .collection('edits')
          .doc(widget.editId)
          .collection('comments')
          .doc();

      await commentRef.set({
        'id': commentRef.id,
        'userId': user.id,
        'username': user.username,
        'avatarUrl': user.avatarUrl,
        'text': text,
        'likes': [],
        'replyToId': _replyToId,
        'replyToName': _replyToName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // تحديث عداد التعليقات
      await _firestore.collection('edits').doc(widget.editId).update({
        'commentsCount': FieldValue.increment(1),
      });

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

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

          // ── قائمة التعليقات
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('edits')
                  .doc(widget.editId)
                  .collection('comments')
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
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

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final commentId = docs[index].id;
                    final likes = List.from(data['likes'] ?? []);
                    final isLiked = likes.contains(widget.currentUserId);
                    final replyToName = data['replyToName'];

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // الصورة
                          CircleAvatar(
                            radius: 18,
                            backgroundImage:
                                (data['avatarUrl'] ?? '').isNotEmpty
                                    ? NetworkImage(data['avatarUrl'])
                                    : null,
                            backgroundColor: Colors.white24,
                            child: (data['avatarUrl'] ?? '').isEmpty
                                ? const Icon(Icons.person,
                                    size: 18, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 10),

                          // المحتوى
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // الاسم
                                Text(
                                  data['username'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),

                                // رد على
                                if (replyToName != null)
                                  Text(
                                    'رداً على @$replyToName',
                                    style: const TextStyle(
                                      color: Colors.blueAccent,
                                      fontSize: 11,
                                    ),
                                  ),

                                const SizedBox(height: 2),

                                // النص
                                Text(
                                  data['text'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 6),

                                // رد + لايك
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => _setReply(
                                          commentId, data['username'] ?? ''),
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
                              ],
                            ),
                          ),

                          // لايك التعليق
                          GestureDetector(
                            onTap: () =>
                                _toggleCommentLike(commentId, likes),
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
                                if (likes.isNotEmpty)
                                  Text(
                                    '${likes.length}',
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