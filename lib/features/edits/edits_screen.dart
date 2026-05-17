import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pubget/models/edits_model.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../providers/edits_provider.dart';
import '../../providers/user_provider.dart';
import '../profile/profile_sceen.dart';
import 'edit_player_widget.dart';
import 'edit_actions_bar.dart';
import 'upload_edit_screen.dart';
import 'edits_share_sheet.dart';

class _AdEditWidget extends StatefulWidget {
  final VoidCallback onAdFinished;
  const _AdEditWidget({required this.onAdFinished});

  @override
  State<_AdEditWidget> createState() => _AdEditWidgetState();
}

class _AdEditWidgetState extends State<_AdEditWidget> {
  NativeAd? _nativeAd;
  bool _adLoaded = false;
  int _secondsLeft = 5;
  bool _countdownStarted = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _nativeAd = NativeAd(
      adUnitId: 'ca-app-pub-3303379299409244/3972031025',
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _adLoaded = true);
          if (!_countdownStarted) {
            _countdownStarted = true;
            _startCountdown();
          }
        },
        onAdFailedToLoad: (_, __) {
          if (mounted) widget.onAdFinished();
        },
      ),
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(templateType: TemplateType.medium),
    )..load();
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        widget.onAdFinished();
        return false;
      }
      return true;
    });
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          color: Colors.black,
          child: _adLoaded
              ? AdWidget(ad: _nativeAd!)
              : const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white54),
                      SizedBox(height: 16),
                      Text('جاري تحميل الإعلان...',
                          style: TextStyle(color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('إعلان',
                style: TextStyle(
                    color: Colors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        if (_adLoaded)
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$_secondsLeft ث',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        Positioned.fill(child: AbsorbPointer()),
      ],
    );
  }
}

class EditsScreen extends StatefulWidget {
  final List<EditModel>? initialEdits;
  final int startIndex;

  const EditsScreen({
    super.key,
    this.initialEdits,
    this.startIndex = 0,
  });

  @override
  State<EditsScreen> createState() => _EditsScreenState();
}

class _EditsScreenState extends State<EditsScreen>
    with AutomaticKeepAliveClientMixin {
  late final PageController _pageController;
  int _currentIndex = 0;
  bool _initialized = false;
  bool _endDialogShown = false;

  static const int _adInterval = 5;
  final Set<int> _finishedAdIndexes = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.startIndex;
    _pageController = PageController(initialPage: widget.startIndex);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
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

  bool _isAdSlot(int index) {
    final cycleLength = _adInterval + 1;
    return (index % cycleLength) == _adInterval;
  }

  int _realEditIndex(int index) {
    final cycleLength = _adInterval + 1;
    final completeCycles = index ~/ cycleLength;
    final positionInCycle = index % cycleLength;
    return (completeCycles * _adInterval) + positionInCycle;
  }

  int _totalItemCount(int editsCount) {
    return editsCount + (editsCount ~/ _adInterval);
  }

  void _checkAndShowEndDialog(EditsProvider editsProvider, int index) {
    if (_endDialogShown) return;
    if (!editsProvider.allUnseenWatched) return;

    final realIndex = _realEditIndex(index);
    final editsCount = editsProvider.edits.length;

    if (realIndex >= editsCount - 1) {
      _endDialogShown = true;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _showEndDialog();
      });
    }
  }

  void _showEndDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
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
            const Text('هذا كل شيء حالياً!',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
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
                            builder: (_) => const UploadEditScreen()),
                      );
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final editsProvider = context.watch<EditsProvider>();
    final userProvider = context.watch<UserProvider>();
    final currentUserId = userProvider.currentUser?.id ?? '';
    final isPremium = userProvider.currentUser?.isPremium ?? false;

    final edits = widget.initialEdits ?? editsProvider.edits;
    final totalCount =
        isPremium ? edits.length : _totalItemCount(edits.length);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (widget.initialEdits == null && editsProvider.isLoading)
            const Center(child: CircularProgressIndicator()),

          if (widget.initialEdits == null &&
              !editsProvider.isLoading &&
              editsProvider.error != null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 50),
                  const SizedBox(height: 12),
                  Text('حدث خطأ:\n${editsProvider.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 13)),
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

          if (edits.isEmpty &&
              (widget.initialEdits != null || !editsProvider.isLoading))
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.movie_creation_outlined,
                      color: Colors.white54, size: 60),
                  SizedBox(height: 16),
                  Text('لا يوجد إيديتات بعد\nكن أول من ينشر!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 16)),
                ],
              ),
            ),

          if (edits.isNotEmpty)
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: totalCount,
              physics: !isPremium &&
                      _isAdSlot(_currentIndex) &&
                      !_finishedAdIndexes.contains(_currentIndex)
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              onPageChanged: (index) {
                setState(() => _currentIndex = index);

                if (isPremium) {
                  if (index < edits.length) {
                    editsProvider.incrementViews(
                        edits[index].id, currentUserId);
                  }
                } else if (!_isAdSlot(index)) {
                  final realIndex = _realEditIndex(index);
                  if (realIndex < edits.length) {
                    editsProvider.incrementViews(
                        edits[realIndex].id, currentUserId);
                    _checkAndShowEndDialog(editsProvider, index);
                  }
                }
              },
              itemBuilder: (context, index) {
                if (!isPremium &&
                    _isAdSlot(index) &&
                    widget.initialEdits == null) {
                  final adDone = _finishedAdIndexes.contains(index);

                  // ← التعديل: عندما adDone == true أرجع SizedBox فقط
                  // بدون أي nextPage هنا — nextPage حدث مرة واحدة في onAdFinished
                  if (adDone) {
                    return const SizedBox.shrink();
                  }

                  return _AdEditWidget(
                    onAdFinished: () {
                      // ← nextPage يُستدعى هنا فقط — مرة واحدة لا غير
                      setState(() => _finishedAdIndexes.add(index));
                      Future.delayed(const Duration(milliseconds: 300), () {
                        if (mounted) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                          );
                        }
                      });
                    },
                  );
                }

                final realIndex = isPremium ? index : _realEditIndex(index);
                if (realIndex >= edits.length) return const SizedBox.shrink();
                final edit = edits[realIndex];

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
                                  backgroundImage: edit.uploaderAvatar.isNotEmpty
                                      ? NetworkImage(edit.uploaderAvatar)
                                      : null,
                                  child: edit.uploaderAvatar.isEmpty
                                      ? const Icon(Icons.person, size: 18)
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Text(edit.uploaderName,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
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
                            child: Text('🎌 ${edit.animeTitle}',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13)),
                          ),
                          const SizedBox(height: 6),
                          if (edit.caption.isNotEmpty)
                            Text(edit.caption,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
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

          if (widget.initialEdits == null)
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
                  child: const Icon(Icons.add, color: Colors.white, size: 28),
                ),
              ),
            ),

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
                  child: const Icon(Icons.arrow_back,
                      color: Colors.white, size: 28),
                ),
              ),
            ),
        ],
      ),
    );
  }
}