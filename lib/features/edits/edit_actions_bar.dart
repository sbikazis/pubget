import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pubget/models/edits_model.dart';
import '../../providers/edits_provider.dart';
import 'edits_comments_sheet.dart';

class EditActionsBar extends StatelessWidget {
  final EditModel edit;
  final String currentUserId;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;

  const EditActionsBar({
    super.key,
    required this.edit,
    required this.currentUserId,
    required this.onLike,
    required this.onComment,
    required this.onShare,
  });

  void _openComments(BuildContext context, String editId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditCommentsSheet(
        editId: editId,
        currentUserId: currentUserId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ← التعديل: نقرأ من _editsMap مباشرة بدل _sessionFeed
    final provider = context.watch<EditsProvider>();
    final liveEdit = provider.getEditById(edit.id) ?? edit;

    final isLiked = liveEdit.isLikedBy(currentUserId);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── اللايك
        _ActionButton(
          icon: isLiked ? Icons.favorite : Icons.favorite_border,
          color: isLiked ? Colors.red : Colors.white,
          label: '${liveEdit.likes.length}',
          onTap: onLike,
        ),
        const SizedBox(height: 20),

        // ── الكومنت
        _ActionButton(
          icon: Icons.chat_bubble_outline,
          color: Colors.white,
          label: '${liveEdit.commentsCount}',
          onTap: () => _openComments(context, liveEdit.id),
        ),
        const SizedBox(height: 20),

        // ── الشير
        _ActionButton(
          icon: Icons.share,
          color: Colors.white,
          label: 'شارك',
          onTap: onShare,
        ),
        const SizedBox(height: 20),

        // ── المشاهدات
        _ActionButton(
          icon: Icons.remove_red_eye_outlined,
          color: Colors.white,
          label: '${liveEdit.views}',
          onTap: () {},
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}