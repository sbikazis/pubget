import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pubget/models/edits_model.dart';
import '../../providers/edits_provider.dart';
import '../../providers/user_provider.dart';
import '../profile/profile_sceen.dart';
import 'edit_player_widget.dart';
import 'edit_actions_bar.dart';
import 'upload_edit_screen.dart';
import 'edits_share_sheet.dart';

class EditsScreen extends StatefulWidget {
  final List<EditModel>? initialEdits; // ← مضاف
  final int startIndex; // ← مضاف

  const EditsScreen({
    super.key,
    this.initialEdits, // ← مضاف
    this.startIndex = 0, // ← مضاف
  });

  @override
  State<EditsScreen> createState() => _EditsScreenState();
}

class _EditsScreenState extends State<EditsScreen>
    with AutomaticKeepAliveClientMixin {
  late final PageController _pageController;
  int _currentIndex = 0;
  bool _initialized = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.startIndex; // ← مضاف
    _pageController = PageController(initialPage: widget.startIndex); // ← مضاف
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      // ← فقط إذا مفيش initialEdits نجيب من Firebase
      if (widget.initialEdits == null) {
        context.read<EditsProvider>().listenToEdits();
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final editsProvider = context.watch<EditsProvider>();
    final userProvider = context.watch<UserProvider>();
    final currentUserId = userProvider.currentUser?.id ?? '';

    // ← المصدر: إما من البروفايل أو من Firebase
    final edits = widget.initialEdits ?? editsProvider.edits;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── حالة التحميل (فقط عند جلب من Firebase)
          if (widget.initialEdits == null && editsProvider.isLoading)
            const Center(child: CircularProgressIndicator()),

          // ── حالة الخطأ
          if (widget.initialEdits == null &&
              !editsProvider.isLoading &&
              editsProvider.error != null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 50),
                  const SizedBox(height: 12),
                  Text(
                    'حدث خطأ:\n${editsProvider.error}',
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      editsProvider.resetError();
                      editsProvider.listenToEdits();
                    },
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),

          // ── لا يوجد فيديوهات
          if (edits.isEmpty &&
              (widget.initialEdits != null || !editsProvider.isLoading))
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
          if (edits.isNotEmpty)
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: edits.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
                editsProvider.incrementViews(edits[index].id);
              },
              itemBuilder: (context, index) {
                final edit = edits[index];
                return Stack(
                  children: [
                    EditPlayerWidget(
                      edit: edit,
                      isActive: index == _currentIndex,
                    ),
                    Positioned(
                      bottom: 80,
                      left: 16,
                      right: 80,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => _openProfile(edit.uploaderId),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundImage:
                                      edit.uploaderAvatar.isNotEmpty
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
                          ),
                          const SizedBox(height: 8),
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
                    Positioned(
                      bottom: 100,
                      right: 12,
                      child: EditActionsBar(
                        edit: edit,
                        currentUserId: currentUserId,
                        onLike: () =>
                            editsProvider.toggleLike(edit.id, currentUserId),
                        onComment: () {},
                        onShare: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => EditShareSheet(edit: edit),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),

          // ── زر الرفع (يظهر فقط في الوضع العادي مش البروفايل)
          if (widget.initialEdits == null)
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

          // ── زر رجوع (يظهر فقط عند الفتح من البروفايل)
          if (widget.initialEdits != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
