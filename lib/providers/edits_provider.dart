// lib/providers/edits_provider.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/edits_model.dart';
import '../services/firebase/edits_service.dart';
import 'package:pubget/services/firebase/feed_service.dart';

class EditsProvider extends ChangeNotifier {
  final EditsService _service = EditsService();
  final FeedService _feedService = FeedService();
  final Map<String, EditModel> _editsMap = {};
  final Map<String, Set<String>> _pendingLikeUpdates = {};
  final Set<String> _seenIds = {};
  List<EditModel> _sessionFeed = [];
  StreamSubscription<List<EditModel>>? _editsSubscription;
  bool _isLoading = false;
  bool _isUploading = false;
  bool _isListening = false;
  bool _skipNextLoad = false; // ← flag لمنع مسح الـ feed بعد النشر
  String? _error;
  EditModel? _lastUploadedEdit;

  static const String _seenKey = 'seen_edit_ids';
  final ValueNotifier<EditModel?> uploadCompletedNotifier =
      ValueNotifier<EditModel?>(null);

  List<EditModel> get edits => List.unmodifiable(_sessionFeed);
  List<EditModel> get sessionFeed => List.unmodifiable(_sessionFeed);
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  String? get error => _error;
  EditModel? get lastUploadedEdit => _lastUploadedEdit;
  bool get allUnseenWatched => _sessionFeed.isEmpty;
  EditModel? getEditById(String id) => _editsMap[id];

  // ══════════════════════════════════════════════
  // ── الـ Seen System
  // ══════════════════════════════════════════════

  Future<void> loadSeenIds() async {
    final prefs = await SharedPreferences.getInstance();
    _seenIds.addAll(prefs.getStringList(_seenKey)?? []);
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
    if (userId!= null) {
      _feedService.markAsSeen(userId, editId);
    }
  }

  Future<void> resetSeen() async {
    _seenIds.clear();
    await _saveSeenIds();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId!= null) {
      await _feedService.clearSeenIds(userId);
    }
    _sessionFeed = _editsMap.values.toList()
     ..sort((a, b) => b.computeScore().compareTo(a.computeScore()));
    notifyListeners();
  }

  // ══════════════════════════════════════════════
  // ── جلب الـ Feed الذكي
  // ══════════════════════════════════════════════

  Future<void> loadSmartFeed(String userId) async {
    // ← إذا كان الـ flag مفعلاً، تخطَّ الجلسة الحالية ولا تمسح الـ feed
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
      userId: userId,
      seenIds: _seenIds.toList(),
    );

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
    // ← إزالة _isLoading = true لأن listenToEdits للتحديثات فقط وليس loading أولي

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

  void _mergeIncomingEdits(List<EditModel> incoming) {
    bool hasNewEdit = false; // ← track إضافة إيديت جديد فقط

    for (final edit in incoming) {
      final existing = _editsMap[edit.id];

      if (existing == null) {
        // ← إيديت جديد تماماً
        _editsMap[edit.id] = edit;
        if (!_seenIds.contains(edit.id)) {
          _sessionFeed.add(edit);
          hasNewEdit = true; // ← فقط هنا نُعيد الترتيب
        }
        continue;
      }

      // ← تحديث لايك أو كومنت — لا إعادة ترتيب
      final merged = _mergeEdit(existing, edit);
      _editsMap[edit.id] = merged;
      final idx = _sessionFeed.indexWhere((e) => e.id == edit.id);
      if (idx!= -1) _sessionFeed[idx] = merged;
    }

    // ← إعادة الترتيب فقط عند وجود إيديت جديد
    if (hasNewEdit) {
      _sessionFeed
         .sort((a, b) => b.computeScore().compareTo(a.computeScore()));
    }
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

  // ══════════════════════════════════════════════
  // ── التفاعلات
  // ══════════════════════════════════════════════

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
    wasLiked? updatedLikes.remove(userId) : updatedLikes.add(userId);

    _pendingLikeUpdates[editId] = updatedLikes.toSet();
    final updatedEdit = existing.copyWith(likes: updatedLikes);
    _editsMap[editId] = updatedEdit;

    final idx = _sessionFeed.indexWhere((e) => e.id == editId);
    if (idx!= -1) _sessionFeed[idx] = updatedEdit;
    notifyListeners();

    try {
      await _service.toggleLike(editId, userId, wasLiked);
    } catch (_) {
      _pendingLikeUpdates.remove(editId);
      _editsMap[editId] = existing;
      if (idx!= -1) _sessionFeed[idx] = existing;
      notifyListeners();
    }
  }

  Future<void> incrementViews(String editId, String userId) async {
    markAsSeen(editId);
    await _service.incrementViews(editId, userId);
  }

  Future<void> addComment({
    required String editId,
    required String userId,
    required String username,
    required String userAvatar,
    required String text,
  }) async {
    try {
      await _service.addComment(
        editId: editId,
        userId: userId,
        username: username,
        userAvatar: userAvatar,
        text: text,
      );

      final existing = _editsMap[editId];
      if (existing!= null) {
        final updated = existing.copyWith(
          commentsCount: existing.commentsCount + 1,
        );
        _editsMap[editId] = updated;
        final idx = _sessionFeed.indexWhere((e) => e.id == editId);
        if (idx!= -1) _sessionFeed[idx] = updated;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════
  // ── الرفع في الخلفية
  // ══════════════════════════════════════════════

  void uploadEditInBackground({
    required File videoFile,
    required File thumbnailFile,
    required String userId,
    required String uploaderName,
    required String uploaderAvatar,
    required String animeTitle,
    required String caption,
    void Function(EditModel)? onComplete,
    void Function(String)? onFailed,
  }) {
    if (_isUploading) return;
    _isUploading = true;
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
    void Function(EditModel)? onComplete,
    void Function(String)? onFailed,
  }) async {
    try {
      // ← رفع متوازٍ للفيديو والـ thumbnail معاً
      final urls = await _service.uploadVideoAndThumbnail(
          videoFile, thumbnailFile, userId);
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

      _lastUploadedEdit = uploadedEdit;

      // ← فعّل الـ flag لمنع loadSmartFeed من مسح الـ feed
      _skipNextLoad = true;

      _isUploading = false;
      notifyListeners(); // ← يُخفي الشريط
      uploadCompletedNotifier.value = uploadedEdit; // ← يُطلق الانتقال
      onComplete?.call(uploadedEdit);
    } catch (e) {
      _error = e.toString();
      _isUploading = false;
      notifyListeners();
      onFailed?.call(e.toString());
    }
  }
  void setSkipNextLoad(){
    _skipNextLoad = true;
  }

  // ══════════════════════════════════════════════
  // ── أدوات مساعدة
  // ══════════════════════════════════════════════

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
      if (edit!= null) _editsMap[editId] = edit;
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
