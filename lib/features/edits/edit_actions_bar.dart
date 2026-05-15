import 'package:flutter/material.dart';
import 'package:pubget/models/edits_model.dart';

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

  @override
  Widget build(BuildContext context) {
    final isLiked = edit.isLikedBy(currentUserId);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── اللايك
        _ActionButton(
          icon: isLiked ? Icons.favorite : Icons.favorite_border,
          color: isLiked ? Colors.red : Colors.white,
          label: '${edit.likes.length}',
          onTap: onLike,
        ),
        const SizedBox(height: 20),

        // ── الكومنت
        _ActionButton(
          icon: Icons.chat_bubble_outline,
          color: Colors.white,
          label: '${edit.commentsCount}',
          onTap: onComment,
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
          label: '${edit.views}',
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