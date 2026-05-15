import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/edits_provider.dart';
import '../../providers/user_provider.dart';
import 'edit_player_widget.dart';
import 'edit_actions_bar.dart';
import 'upload_edit_screen.dart';

class EditsScreen extends StatefulWidget {
  const EditsScreen({super.key});

  @override
  State<EditsScreen> createState() => _EditsScreenState();
}

class _EditsScreenState extends State<EditsScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    context.read<EditsProvider>().listenToEdits();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editsProvider = context.watch<EditsProvider>();
    final userProvider = context.watch<UserProvider>();
    final currentUserId = userProvider.currentUser?.id ?? '';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── حالة التحميل
          if (editsProvider.isLoading)
            const Center(child: CircularProgressIndicator()),

          // ── لا يوجد فيديوهات
          if (!editsProvider.isLoading && editsProvider.edits.isEmpty)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.movie_creation_outlined,
                      color: Colors.white54, size: 60),
                  SizedBox(height: 16),
                  Text(
                    'لا يوجد إيديتات بعد\nكن أول من ينشر!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                ],
              ),
            ),

          // ── الفيديوهات
          if (editsProvider.edits.isNotEmpty)
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: editsProvider.edits.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
                // زيادة المشاهدات
                editsProvider.incrementViews(
                    editsProvider.edits[index].id);
              },
              itemBuilder: (context, index) {
                final edit = editsProvider.edits[index];
                return Stack(
                  children: [
                    // ── مشغل الفيديو
                    EditPlayerWidget(
                      edit: edit,
                      isActive: index == _currentIndex,
                    ),

                    // ── معلومات الإيديت (يسار الأسفل)
                    Positioned(
                      bottom: 80,
                      left: 16,
                      right: 80,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // اسم المستخدم
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundImage: edit.uploaderAvatar.isNotEmpty
                                    ? NetworkImage(edit.uploaderAvatar)
                                    : null,
                                child: edit.uploaderAvatar.isEmpty
                                    ? const Icon(Icons.person, size: 18)
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                edit.uploaderName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // اسم الأنمي
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '🎌 ${edit.animeTitle}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13),
                            ),
                          ),
                          const SizedBox(height: 6),

                          // الكابشن
                          if (edit.caption.isNotEmpty)
                            Text(
                              edit.caption,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),

                    // ── أزرار التفاعل (يمين)
                    Positioned(
                      bottom: 100,
                      right: 12,
                      child: EditActionsBar(
                        edit: edit,
                        currentUserId: currentUserId,
                        onLike: () => editsProvider.toggleLike(
                            edit.id, currentUserId),
                        onComment: () {
                          // TODO: فتح كومنتات
                        },
                        onShare: () {
                          // TODO: شير
                        },
                      ),
                    ),
                  ],
                );
              },
            ),

          // ── زر الرفع
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const UploadEditScreen()),
              ),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }
}