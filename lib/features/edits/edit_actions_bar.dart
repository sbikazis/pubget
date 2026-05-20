import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pubget/models/edits_model.dart';
import '../../providers/edits_provider.dart';
import 'edits_comments_sheet.dart';

class EditActionsBar extends StatefulWidget {
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
  State<EditActionsBar> createState() => _EditActionsBarState();
}

class _EditActionsBarState extends State<EditActionsBar> {
  void _openComments(BuildContext context, String editId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditCommentsSheet(
        editId: editId,
        currentUserId: widget.currentUserId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EditsProvider>();
    final liveEdit = provider.getEditById(widget.edit.id) ?? widget.edit;
    final isLiked = liveEdit.isLikedBy(widget.currentUserId);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── زر اللايك مع AnimatedSwitcher
        GestureDetector(
          onTap: widget.onLike,
          child: Column(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.elasticOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: child,
                ),
                child: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  key: ValueKey(isLiked),
                  color: isLiked ? Colors.red : Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${liveEdit.likes.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _ActionButton(
          icon: Icons.chat_bubble_outline,
          color: Colors.white,
          label: '${liveEdit.commentsCount}',
          onTap: () => _openComments(context, liveEdit.id),
        ),
        const SizedBox(height: 20),
        _ActionButton(
          icon: Icons.share,
          color: Colors.white,
          label: 'شارك',
          onTap: widget.onShare,
        ),
        const SizedBox(height: 20),
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