// lib/providers/edits_provider.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/edits_model.dart';
import '../services/firebase/edits_service.dart';
import '../services/firebase/feed_service.dart';
import '../services/monetization/coin_service.dart';
import '../providers/notifications_provider.dart';

class EditsProvider extends ChangeNotifier {
  final EditsService _service = EditsService();
  final FeedService _feedService = FeedService();
  final CoinService _coinService = CoinService();

  NotificationsProvider? _notificationsProvider;
  void setNotificationsProvider(NotificationsProvider p) {
    _notificationsProvider = p;
  }

  final Map<String, EditModel> _editsMap = {};
  final Map<String, Set<String>> _pendingLikeUpdates = {};
  final Set<String> _seenIds = {};
  List<EditModel> _sessionFeed = [];
  StreamSubscription<List<EditModel>>? _editsSubscription;
  bool _isLoading = false;
  bool _isUploading = false;
  bool _isListening = false;
  bool _skipNextLoad = false;
  String? _error;
  EditModel? _lastUploadedEdit;
  double _uploadProgress = 0.0;

  static const String _seenKey = 'seen_edit_ids';
  final ValueNotifier<EditModel?> uploadCompletedNotifier =
      ValueNotifier<EditModel?>(null);

  List<EditModel> get edits => List.unmodifiable(_sessionFeed);
  List<EditModel> get sessionFeed => List.unmodifiable(_sessionFeed);
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  double get uploadProgress => _uploadProgress;
  String? get error => _error;
  EditModel? get lastUploadedEdit => _lastUploadedEdit;
  bool get allUnseenWatched => _sessionFeed.isEmpty;
  EditModel? getEditById(String id) => _editsMap[id];

  Future<void> loadSeenIds() async {
    final prefs = await SharedPreferences.getInstance();
    _seenIds.addAll(prefs.getStringList(_seenKey) ?? []);
  }

  Future<void> _saveSeenIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_seenKey, _seenIds.toList());
  }

  void markAsSeen(String editId) {
    if (_seenIds.contains(editId)) return;
    _seenIds.add(editId);
    _saveSeenIds();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      _feedService.markAsSeen(userId, editId);
    }
  }

  Future<void> resetSeen() async {
    _seenIds.clear();
    await _saveSeenIds();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      await _feedService.clearSeenIds(userId);
    }
    // ✅ هذا الـ sort مقبول هنا لأنه يحدث فقط عند "عرض من البداية"
    // (إعادة تعيين كاملة وعمدية للفيد)، وليس أثناء جلسة تمرير نشطة.
    _sessionFeed = _editsMap.values.toList()
      ..sort((a, b) => b.computeScore().compareTo(a.computeScore()));
    notifyListeners();
  }

  Future<void> loadSmartFeed(String userId) async {
    if (_skipNextLoad) {
      _skipNextLoad = false;
      return;
    }
    _isLoading = true;
    notifyListeners();
    await loadSeenIds();
    final firestoreSeen = await _feedService.getSeenIds(userId);
    _seenIds.addAll(firestoreSeen);
    final feed = await _feedService.fetchSmartFeed(
        userId: userId, seenIds: _seenIds.toList());
    _sessionFeed = feed;
    _editsMap.clear();
    for (final e in feed) {
      _editsMap[e.id] = e;
    }
    _isLoading = false;
    notifyListeners();
    if (!_isListening) listenToEdits();
  }

  Future<void> listenToEdits() async {
    if (_isListening) return;
    _isListening = true;
    await _editsSubscription?.cancel();
    _editsSubscription = _service.getEdits().listen(
      (incoming) {
        _mergeIncomingEdits(incoming);
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  // ✅ FIX: تمت إزالة أي إعادة ترتيب (sort) للقائمة هنا بالكامل.
  // المشكلة كانت: كل تحديث لحظي من الستريم (حتى لو لايك بسيط على إيديت
  // آخر) كان يعيد ترتيب _sessionFeed كاملة بناءً على computeScore()
  // المتغيّرة، بينما المستخدم يتنقل بمؤشر ثابت (PageView index) — فيظهر
  // له فيديو شُوهد من جديد لأن محتوى القائمة تحت قدمه تغيّر بالكامل.
  // الحل: الترتيب الذكي يحدث مرة واحدة فقط عند التحميل الأولي
  // (loadSmartFeed → fetchSmartFeed). أي إيديت جديد يصل بعد ذلك يُضاف
  // فقط في آخر القائمة، أو يُحدَّث في مكانه الحالي دون أي تغيير في الموضع.
  void _mergeIncomingEdits(List<EditModel> incoming) {
    for (final edit in incoming) {
      final existing = _editsMap[edit.id];
      if (existing == null) {
        _editsMap[edit.id] = edit;
        if (!_seenIds.contains(edit.id)) {
          _sessionFeed.add(edit); // ✅ إضافة في الآخر فقط
        }
        continue;
      }
      final merged = _mergeEdit(existing, edit);
      _editsMap[edit.id] = merged;
      final idx = _sessionFeed.indexWhere((e) => e.id == edit.id);
      if (idx != -1) _sessionFeed[idx] = merged; // ✅ تحديث بدون تغيير الموضع
    }
    // ✅ لا sort بعد الآن أثناء الجلسة النشطة
  }

  EditModel _mergeEdit(EditModel local, EditModel remote) {
    final pending = _pendingLikeUpdates[local.id];
    if (pending == null) return remote;
    final remoteSet = remote.likes.toSet();
    if (remoteSet.length == pending.length &&
        remoteSet.containsAll(pending)) {
      _pendingLikeUpdates.remove(local.id);
      return remote;
    }
    return remote.copyWith(likes: pending.toList());
  }

  Future<void> recordWatchTime({
    required String editId,
    required String userId,
    required int watchSeconds,
    required double watchPercent,
  }) async {
    if (watchSeconds <= 0) return;
    try {
      await _service.recordWatchTime(
        editId: editId,
        userId: userId,
        watchSeconds: watchSeconds,
        watchPercent: watchPercent,
      );
    } catch (_) {}
  }

  Future<void> toggleLike(String editId, String userId) async {
    final existing = _editsMap[editId];
    if (existing == null) return;
    final wasLiked = existing.likes.contains(userId);
    final updatedLikes = List<String>.from(existing.likes);
    wasLiked ? updatedLikes.remove(userId) : updatedLikes.add(userId);
    _pendingLikeUpdates[editId] = updatedLikes.toSet();
    final updatedEdit = existing.copyWith(likes: updatedLikes);
    _editsMap[editId] = updatedEdit;
    final idx = _sessionFeed.indexWhere((e) => e.id == editId);
    if (idx != -1) _sessionFeed[idx] = updatedEdit;
    notifyListeners();
    try {
      await _service.toggleLike(editId, userId, wasLiked);

      if (!wasLiked && existing.uploaderId != userId) {
        final currentUser = FirebaseAuth.instance.currentUser;
        final username = currentUser?.displayName ?? 'مستخدم';
        _notificationsProvider?.createLikeNotification(
          toUserId: existing.uploaderId,
          fromUserId: userId,
          fromUsername: username,
          editId: editId,
          animeTitle: existing.animeTitle,
        );
      }
    } catch (_) {
      _pendingLikeUpdates.remove(editId);
      _editsMap[editId] = existing;
      if (idx != -1) _sessionFeed[idx] = existing;
      notifyListeners();
    }
  }

  Future<void> incrementViews(String editId, String userId) async {
    markAsSeen(editId);
    await _service.incrementViews(editId, userId);
  }

  Future<String?> addComment({
    required String editId,
    required String userId,
    required String username,
    required String userAvatar,
    required String text,
  }) async {
    try {
      final commentId = await _service.addComment(
        editId: editId,
        userId: userId,
        username: username,
        userAvatar: userAvatar,
        text: text,
      );

      final existing = _editsMap[editId];
      if (existing != null) {
        final updated =
            existing.copyWith(commentsCount: existing.commentsCount + 1);
        _editsMap[editId] = updated;
        final idx = _sessionFeed.indexWhere((e) => e.id == editId);
        if (idx != -1) _sessionFeed[idx] = updated;
        notifyListeners();
      }

      return commentId;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Stream<List<CommentModel>> streamComments(String editId) {
    return _service.streamComments(editId).asyncMap((comments) async {
      final enriched = <CommentModel>[];
      for (final c in comments) {
        if (c.userAvatar.isEmpty) {
          try {
            final userDoc = await FirebaseFirestore.instance
                .collection('Users')
                .doc(c.userId)
                .get();
            final data = userDoc.data();
            final avatar = data?['avatarUrl'] ?? '';
            final name = data?['username'] ?? c.userName;
            enriched.add(c.copyWith(userAvatar: avatar, userName: name));
          } catch (_) {
            enriched.add(c);
          }
        } else {
          enriched.add(c);
        }
      }
      return enriched;
    });
  }

  Future<bool> subscribeToUploader({
    required String uploaderId,
    required String currentUserId,
    required String currentUsername,
  }) async {
    if (uploaderId == currentUserId) return false;
    try {
      // ✅ FIX: البحث بـ query على الحقول (fromUserId + toUserId) بدل
      // الاعتماد على doc ID ثابت بصيغة "${currentUserId}_$uploaderId".
      // المستندات الفعلية في الكولكشن تُكتب بـ auto-generated ID، فكان
      // البحث القديم لا يجدها أبداً ويعتقد دائماً أن الاشتراك غير موجود.
      final existing = await FirebaseFirestore.instance
          .collection('respects')
          .where('fromUserId', isEqualTo: currentUserId)
          .where('toUserId', isEqualTo: uploaderId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) return false;

      final batch = FirebaseFirestore.instance.batch();

      // ✅ FIX: doc() عشوائي بدل doc('${currentUserId}_$uploaderId')
      final respectRef =
          FirebaseFirestore.instance.collection('respects').doc();

      batch.set(respectRef, {
        'fromUserId': currentUserId,
        'toUserId': uploaderId,
        'value': 7,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final userRef =
          FirebaseFirestore.instance.collection('Users').doc(uploaderId);
      batch.update(userRef, {
        'totalRespect': FieldValue.increment(7),
      });

      await batch.commit();

      _notificationsProvider?.createRespectNotification(
        toUserId: uploaderId,
        fromUserId: currentUserId,
        fromUsername: currentUsername,
        respectValue: 7,
      );

      debugPrint('✅ اشتراك: منح 7 نقاط احترام لـ $uploaderId');
      return true;
    } catch (e) {
      debugPrint('❌ subscribeToUploader failed: $e');
      return false;
    }
  }

  void uploadEditInBackground({
    required File videoFile,
    required File thumbnailFile,
    required String userId,
    required String uploaderName,
    required String uploaderAvatar,
    required String animeTitle,
    required String caption,
    void Function(EditModel, bool)? onComplete,
    void Function(String)? onFailed,
  }) {
    if (_isUploading) return;
    _isUploading = true;
    _uploadProgress = 0.0;
    notifyListeners();
    _runUpload(
      videoFile: videoFile,
      thumbnailFile: thumbnailFile,
      userId: userId,
      uploaderName: uploaderName,
      uploaderAvatar: uploaderAvatar,
      animeTitle: animeTitle,
      caption: caption,
      onComplete: onComplete,
      onFailed: onFailed,
    );
  }

  Future<void> _runUpload({
    required File videoFile,
    required File thumbnailFile,
    required String userId,
    required String uploaderName,
    required String uploaderAvatar,
    required String animeTitle,
    required String caption,
    void Function(EditModel, bool)? onComplete,
    void Function(String)? onFailed,
  }) async {
    bool rewarded = false;
    try {
      final urls = await _service.uploadVideoAndThumbnail(
        videoFile,
        thumbnailFile,
        userId,
        onProgress: (progress) {
          _uploadProgress = progress;
          notifyListeners();
        },
      );
      final videoUrl = urls[0];
      final thumbnailUrl = urls[1];
      final edit = EditModel(
        id: '',
        uploaderId: userId,
        uploaderName: uploaderName,
        uploaderAvatar: uploaderAvatar,
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
        animeTitle: animeTitle,
        caption: caption,
        likes: [],
        commentsCount: 0,
        views: 0,
        createdAt: DateTime.now(),
      );
      final docId = await _service.postEdit(edit);
      final uploadedEdit = edit.copyWith(id: docId);

      try {
        rewarded =
            await _coinService.rewardForPublishingEdit(userId: userId);
        if (rewarded) {
          debugPrint('✅ تمت مكافأة نشر الإديت +10');
        } else {
          debugPrint('⚠️ وصلت للحد اليومي لنشر الإديت');
        }
      } catch (e) {
        debugPrint('⚠️ فشل مكافأة الإديت: $e');
      }

      _lastUploadedEdit = uploadedEdit;
      _skipNextLoad = true;
      _isUploading = false;
      _uploadProgress = 0.0;
      notifyListeners();
      uploadCompletedNotifier.value = uploadedEdit;
      onComplete?.call(uploadedEdit, rewarded);
    } catch (e) {
      _error = e.toString();
      _isUploading = false;
      _uploadProgress = 0.0;
      notifyListeners();
      onFailed?.call(e.toString());
    }
  }

  void setSkipNextLoad() {
    _skipNextLoad = true;
  }

  void prependEdit(EditModel edit) {
    _editsMap[edit.id] = edit;
    _sessionFeed.removeWhere((e) => e.id == edit.id);
    _sessionFeed.insert(0, edit);
    notifyListeners();
  }

  void resetError() {
    _error = null;
    notifyListeners();
  }

  void clearLastUploadedEdit() {
    _lastUploadedEdit = null;
    uploadCompletedNotifier.value = null;
    notifyListeners();
  }

  Stream<List<EditModel>> getUserEdits(String userId) =>
      _service.getUserEdits(userId);

  Future<EditModel?> fetchEditById(String editId) async {
    if (_editsMap.containsKey(editId)) return _editsMap[editId];
    try {
      final edit = await _service.getEditById(editId);
      if (edit != null) _editsMap[editId] = edit;
      return edit;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteEdit(EditModel edit) async {
    try {
      await _service.deleteEdit(edit);
      _editsMap.remove(edit.id);
      _sessionFeed.removeWhere((e) => e.id == edit.id);
      _seenIds.remove(edit.id);
      await _saveSeenIds();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _editsSubscription?.cancel();
    uploadCompletedNotifier.dispose();
    super.dispose();
  }
}
