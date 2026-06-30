// lib/features/edits/edits_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pubget/models/edits_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../providers/edits_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/notifications_provider.dart';

import '../profile/profile_sceen.dart';
import 'edit_player_widget.dart';
import 'edit_actions_bar.dart';
import 'upload_edit_screen.dart';
import 'edits_share_sheet.dart';
import 'edits_comments_sheet.dart';
import 'ad_edit_widget.dart';

class EditsScreen extends StatefulWidget {
  final int startIndex;
  final String? initialEditId;
  final String? initialCommentId;
  final bool autoOpenComments;

  const EditsScreen({
    super.key,
    this.startIndex = 0,
    this.initialEditId,
    this.initialCommentId,
    this.autoOpenComments = false,
  });

  @override
  State<EditsScreen> createState() => _EditsScreenState();
}

class _EditsScreenState extends State<EditsScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  late final PageController _pageController;
  int _currentIndex = 0;
  bool _isAdCurrentlyShowing = false;
  bool _initialized = false;
  bool _endDialogShown = false;
  static const int _adInterval = 5;
  final Set<int> _finishedAdIndexes = {};
  DateTime? _pageEntryTime;

  bool _showCaption = false;

  final Map<String, bool> _subscribedMap = {};
  final Map<String, bool> _subscribingMap = {};

  late final AnimationController _subscribeAnimCtrl;
  late final Animation<double> _subscribeScale;
  late final Animation<double> _subscribeGlow;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.startIndex;
    _pageController = PageController(initialPage: widget.startIndex);

    _subscribeAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _subscribeScale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.35)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 40),
      TweenSequenceItem(
          tween: Tween(begin: 1.35, end: 0.9)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 30),
      TweenSequenceItem(
          tween: Tween(begin: 0.9, end: 1.0)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 30),
    ]).animate(_subscribeAnimCtrl);

    _subscribeGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _subscribeAnimCtrl,
          curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );

    if (widget.initialEditId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final provider = context.read<EditsProvider>();

        EditModel? targetEdit = provider.getEditById(widget.initialEditId!);
        targetEdit ??= await provider.fetchEditById(widget.initialEditId!);

        if (targetEdit != null && mounted) {
          provider.prependEdit(targetEdit);

          await Future.delayed(const Duration(milliseconds: 100));
          if (!mounted) return;

          if (_pageController.hasClients) {
            _pageController.jumpToPage(0);
            setState(() => _currentIndex = 0);
          }

          if (widget.autoOpenComments || widget.initialCommentId != null) {
            await Future.delayed(const Duration(milliseconds: 400));
            if (mounted) {
              _openComments(targetEdit.id, commentId: widget.initialCommentId);
            }
          }
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    if (widget.initialEditId == null) {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      context.read<EditsProvider>().loadSmartFeed(userId);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _subscribeAnimCtrl.dispose();
    super.dispose();
  }

  // ✅ التحقق بـ query بدل doc ID ثابت
  Future<void> _checkSubscription(
      String uploaderId, String currentUserId) async {
    if (_subscribedMap.containsKey(uploaderId)) return;
    try {
      final query = await FirebaseFirestore.instance
          .collection('respects')
          .where('fromUserId', isEqualTo: currentUserId)
          .where('toUserId', isEqualTo: uploaderId)
          .limit(1)
          .get();
      if (mounted) {
        setState(() => _subscribedMap[uploaderId] = query.docs.isNotEmpty);
      }
    } catch (_) {}
  }

  Future<void> _onSubscribe(EditModel edit, String currentUserId) async {
    if (_subscribingMap[edit.uploaderId] == true) return;
    if (_subscribedMap[edit.uploaderId] == true) return;

    setState(() => _subscribingMap[edit.uploaderId] = true);
    _subscribeAnimCtrl.forward(from: 0.0);

    final currentUser = FirebaseAuth.instance.currentUser;
    final username = currentUser?.displayName ?? 'مستخدم';

    final success = await context.read<EditsProvider>().subscribeToUploader(
          uploaderId: edit.uploaderId,
          currentUserId: currentUserId,
          currentUsername: username,
        );

    if (mounted) {
      setState(() {
        _subscribingMap[edit.uploaderId] = false;
        if (success) _subscribedMap[edit.uploaderId] = true;
      });
    }
  }

  bool _isAdSlot(int index) {
    final cycleLength = _adInterval + 1;
    return (index % cycleLength) == _adInterval;
  }

  int _realEditIndex(int index, bool isPremium) {
    if (isPremium) return index;
    final cycleLength = _adInterval + 1;
    final completeCycles = index ~/ cycleLength;
    final positionInCycle = index % cycleLength;
    return (completeCycles * _adInterval) + positionInCycle;
  }

  int _totalVisualCount(int editsCount) {
    return editsCount + (editsCount ~/ _adInterval);
  }

  void _openProfile(String userId) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)));
  }

  void _openComments(String editId, {String? commentId}) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditCommentsSheet(
        editId: editId,
        currentUserId: currentUserId,
        scrollToCommentId: commentId,
      ),
    );
  }

  void _showEndDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎌', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              const Text(
                'هذا كل شيء حالياً!',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'شاهدت جميع الإيديتات المتاحة\nسنعرض لك المزيد عندما يُضاف محتوى جديد',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() => _endDialogShown = false);
                        context.read<EditsProvider>().resetSeen();
                        final uid =
                            FirebaseAuth.instance.currentUser?.uid ?? '';
                        context.read<EditsProvider>().loadSmartFeed(uid);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('عرض من البداية',
                          style: TextStyle(color: Colors.white70)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const UploadEditScreen()));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('أضف إيديت ✨',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _checkEndOfFeed(
      List<EditModel> edits, int visualIndex, bool isPremium) {
    if (_endDialogShown) return;
    final realIndex = _realEditIndex(visualIndex, isPremium);
    if (realIndex >= edits.length - 1) {
      _endDialogShown = true;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        _showEndDialog();
      });
    }
  }

  Widget _buildEditInfo(EditModel edit, String currentUserId) {
    final isOwner = edit.uploaderId == currentUserId;
    final isSubscribed = _subscribedMap[edit.uploaderId] ?? false;
    final isSubscribing = _subscribingMap[edit.uploaderId] ?? false;

    if (!_subscribedMap.containsKey(edit.uploaderId)) {
      _checkSubscription(edit.uploaderId, currentUserId);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _openProfile(edit.uploaderId),
          child: Row(
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
                    fontSize: 15),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                edit.animeTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (edit.caption.isNotEmpty) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => setState(() => _showCaption = !_showCaption),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: _showCaption ? Colors.white24 : Colors.white10,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                          _showCaption ? Colors.white38 : Colors.white12,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showCaption
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: Colors.white70,
                        size: 13,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        _showCaption ? 'إخفاء' : 'الوصف',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),

        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _showCaption && edit.caption.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      edit.caption,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12.5),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),

        const SizedBox(height: 10),

        if (!isOwner)
          AnimatedBuilder(
            animation: _subscribeAnimCtrl,
            builder: (_, __) {
              return Transform.scale(
                scale: _subscribeScale.value,
                child: GestureDetector(
                  onTap: isSubscribed || isSubscribing
                      ? null
                      : () => _onSubscribe(edit, currentUserId),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: isSubscribed
                          ? null
                          : const LinearGradient(
                              colors: [
                                Color(0xFF7C3AED),
                                Color(0xFF4F46E5),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      color: isSubscribed ? Colors.white12 : null,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSubscribed
                            ? Colors.white24
                            : Colors.transparent,
                        width: 1,
                      ),
                      boxShadow: isSubscribed
                          ? []
                          : [
                              BoxShadow(
                                color: Colors.deepPurple.withValues(
                                    alpha: 0.45 * _subscribeGlow.value),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                    ),
                    child: isSubscribing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSubscribed
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: isSubscribed
                                    ? Colors.pinkAccent
                                    : Colors.white,
                                size: 13,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isSubscribed ? 'مشترك ✓' : 'اشتراك',
                                style: TextStyle(
                                  color: isSubscribed
                                      ? Colors.white60
                                      : Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final editsProvider = context.watch<EditsProvider>();
    final userProvider = context.watch<UserProvider>();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isPremium = userProvider.currentUser?.isPremium ?? false;
    final edits = editsProvider.sessionFeed;
    final totalCount =
        isPremium ? edits.length : _totalVisualCount(edits.length);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (editsProvider.isLoading && edits.isEmpty)
            const Center(child: CircularProgressIndicator()),

          if (!editsProvider.isLoading && editsProvider.error != null)
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
                      final uid =
                          FirebaseAuth.instance.currentUser?.uid ?? '';
                      editsProvider.loadSmartFeed(uid);
                    },
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),

          if (edits.isEmpty && !editsProvider.isLoading)
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

          if (edits.isNotEmpty)
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: totalCount,
              physics: _isAdCurrentlyShowing
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              onPageChanged: (index) {
                if (_showCaption) setState(() => _showCaption = false);

                final entryTime = _pageEntryTime;
                if (entryTime != null) {
                  final secondsSpent =
                      DateTime.now().difference(entryTime).inSeconds;
                  if (secondsSpent < 3 && !_isAdSlot(_currentIndex)) {
                    final prevRealIndex =
                        _realEditIndex(_currentIndex, isPremium);
                    if (prevRealIndex < edits.length) {
                      editsProvider.recordWatchTime(
                        editId: edits[prevRealIndex].id,
                        userId: currentUserId,
                        watchSeconds: 0,
                        watchPercent: 0.0,
                      );
                    }
                  }
                }
                _pageEntryTime = DateTime.now();

                setState(() {
                  _currentIndex = index;
                  if (!isPremium &&
                      _isAdSlot(index) &&
                      !_finishedAdIndexes.contains(index)) {
                    _isAdCurrentlyShowing = true;
                  } else {
                    _isAdCurrentlyShowing = false;
                  }
                });

                if (!isPremium && _isAdSlot(index)) return;
                final realIndex = _realEditIndex(index, isPremium);
                if (realIndex >= edits.length) return;
                final edit =
                    editsProvider.getEditById(edits[realIndex].id) ??
                        edits[realIndex];
                editsProvider.incrementViews(edit.id, currentUserId);
                _checkEndOfFeed(edits, index, isPremium);
              },
              itemBuilder: (context, index) {
                if (!isPremium && _isAdSlot(index)) {
                  if (_finishedAdIndexes.contains(index)) {
                    return const SizedBox.shrink();
                  }
                  return AdEditWidget(
                    onAdFinished: () {
                      if (!mounted) return;
                      if (_finishedAdIndexes.contains(index)) return;
                      setState(() {
                        _finishedAdIndexes.add(index);
                        _isAdCurrentlyShowing = false;
                      });
                      if (_currentIndex == index &&
                          _pageController.hasClients) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                  );
                }

                final realIndex = _realEditIndex(index, isPremium);
                if (realIndex >= edits.length) {
                  return const SizedBox.shrink();
                }

                final edit =
                    editsProvider.getEditById(edits[realIndex].id) ??
                        edits[realIndex];

                return Stack(
                  key: ValueKey(edit.id),
                  children: [
                    EditPlayerWidget(
                      key: ValueKey(edit.id),
                      edit: edit,
                      isActive: index == _currentIndex,
                      onWatchTime: (watchSeconds, watchPercent) {
                        editsProvider.recordWatchTime(
                          editId: edit.id,
                          userId: currentUserId,
                          watchSeconds: watchSeconds,
                          watchPercent: watchPercent,
                        );
                      },
                    ),
                    Positioned(
                      bottom: 90,
                      left: 16,
                      right: 88,
                      child: _buildEditInfo(edit, currentUserId),
                    ),
                    Positioned(
                      bottom: 100,
                      right: 12,
                      child: EditActionsBar(
                        edit: edit,
                        currentUserId: currentUserId,
                        onLike: () =>
                            editsProvider.toggleLike(edit.id, currentUserId),
                        onComment: () => _openComments(edit.id),
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

          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const UploadEditScreen())),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    const Icon(Icons.add, color: Colors.white, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }
}