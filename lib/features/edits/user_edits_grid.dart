import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pubget/models/edits_model.dart';
import '../../providers/edits_provider.dart';
import '../../providers/auth_provider.dart';
import 'edits_screen.dart';

class UserEditsGrid extends StatelessWidget {
  final String userId;
  final String username;

  const UserEditsGrid({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    final editsProvider = context.read<EditsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final myId = context.read<AuthProvider>().user?.id;
    final isMe = myId == userId;

    return StreamBuilder<List<EditModel>>(
      stream: editsProvider.getUserEdits(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final edits = snapshot.data?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  const Icon(Icons.play_circle_outline, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'إبداعات $username',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${edits.length}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (edits.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Icon(Icons.movie_creation_outlined,
                          size: 48,
                          color: isDark? Colors.white30 : Colors.black26),
                      const SizedBox(height: 8),
                      Text(
                        isMe
                           ? 'لم تنشر أي إيديت بعد'
                            : 'لا توجد إيديتات بعد',
                        style: TextStyle(
                          color: isDark? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (edits.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 3,
                  mainAxisSpacing: 3,
                  childAspectRatio: 9 / 16,
                ),
                itemCount: edits.length,
                itemBuilder: (context, index) {
                  final edit = edits[index];
                  return GestureDetector(
                    onTap: () => _openEdit(context, edit),
                    onLongPress: isMe
                       ? () => _confirmDelete(context, edit)
                        : null,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        edit.thumbnailUrl.isNotEmpty
                           ? Image.network(
                                edit.thumbnailUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _buildPlaceholder(isDark),
                              )
                            : _buildPlaceholder(isDark),
                        const Positioned(
                          bottom: 6,
                          left: 6,
                          child: Icon(
                            Icons.play_circle_fill,
                            color: Colors.white70,
                            size: 20,
                          ),
                        ),
                        Positioned(
                          bottom: 6,
                          right: 6,
                          child: Row(
                            children: [
                              const Icon(Icons.favorite,
                                  color: Colors.white70, size: 12),
                              const SizedBox(width: 2),
                              Text(
                                '${edit.likes.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  shadows: [
                                    Shadow(
                                        color: Colors.black,
                                        blurRadius: 4)
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  // ← التعديل هنا: ما عادش كنديرو prepend، كنمررو Provider و ID
  void _openEdit(BuildContext context, EditModel edit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<EditsProvider>(),
          child: EditsScreen(initialEditId: edit.id),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, EditModel edit) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الإيديت'),
        content: const Text('هل أنت متأكد؟ لا يمكن التراجع عن هذا.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<EditsProvider>().deleteEdit(edit);
            },
            child: const Text(
              'حذف',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Container(
      color: isDark? Colors.grey[850] : Colors.grey[300],
      child: const Center(
        child: Icon(Icons.movie_outlined, color: Colors.grey),
      ),
    );
  }
}