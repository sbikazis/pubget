import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pubget/models/edits_model.dart';
import '../services/firebase/edits_service.dart';

class EditsProvider extends ChangeNotifier {
  final EditsService _service = EditsService();

  List<EditModel> _edits = [];
  final Set<String> _seenIds = {};
  bool _isLoading = false;
  bool _isUploading = false;
  bool _allUnseenWatched = false;
  String? _error;

  List<EditModel> get edits => _edits;
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  bool get allUnseenWatched => _allUnseenWatched;
  String? get error => _error;

  void resetError() {
    _error = null;
    notifyListeners();
  }

  // ══════════════════════════════════════════════
  // ── الاستماع للإيديتات
  // ══════════════════════════════════════════════
  void listenToEdits() {
    _isLoading = true;
    _error = null;
    notifyListeners();

    _service.getEdits(seenIds: _seenIds.toList()).listen(
      (data) {
        _edits = data;
        _isLoading = false;
        _checkAllUnseenWatched();
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  // ══════════════════════════════════════════════
  // ── تسجيل مشاهدة فيديو
  // ══════════════════════════════════════════════
  void markAsSeen(String editId) {
    if (_seenIds.contains(editId)) return;
    _seenIds.add(editId);
    _checkAllUnseenWatched();
    notifyListeners();
  }

  // ── التحقق هل شاهد المستخدم كل المحتوى
  // ── يعتمد على _seenIds مباشرة بدون الـ stream
  void _checkAllUnseenWatched() {
    if (_edits.isEmpty) {
      _allUnseenWatched = false;
      return;
    }
    // كل الإيديتات الموجودة حالياً شوفها المستخدم؟
    final allSeen = _edits.every((e) => _seenIds.contains(e.id));
    _allUnseenWatched = allSeen;
  }

  // ── إعادة تعيين المشاهدة
  void resetSeen() {
    _seenIds.clear();
    _allUnseenWatched = false;
    notifyListeners();
  }

  // ══════════════════════════════════════════════
  // ── رفع في الخلفية
  // ══════════════════════════════════════════════
  void uploadEditInBackground({
    required File videoFile,
    required File thumbnailFile,
    required String userId,
    required String uploaderName,
    required String uploaderAvatar,
    required String animeTitle,
    required String caption,
    void Function()? onComplete,
    void Function(String)? onFailed,
  }) {
    _isUploading = true;
    _error = null;
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
    void Function()? onComplete,
    void Function(String)? onFailed,
  }) async {
    try {
      final videoUrl = await _service.uploadVideo(videoFile, userId);
      final thumbnailUrl =
          await _service.uploadThumbnail(thumbnailFile, userId);

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

      await _service.postEdit(edit);

      _isUploading = false;
      notifyListeners();
      onComplete?.call();
    } catch (e) {
      _error = e.toString();
      _isUploading = false;
      notifyListeners();
      onFailed?.call(e.toString());
    }
  }

  // ══════════════════════════════════════════════
  // ── لايك مع تحديث فوري
  // ══════════════════════════════════════════════
  Future<void> toggleLike(String editId, String userId) async {
    final index = _edits.indexWhere((e) => e.id == editId);
    if (index == -1) return;

    final edit = _edits[index];
    final updatedLikes = List<String>.from(edit.likes);

    if (updatedLikes.contains(userId)) {
      updatedLikes.remove(userId);
    } else {
      updatedLikes.add(userId);
    }

    _edits[index] = edit.copyWith(likes: updatedLikes);
    notifyListeners();

    await _service.toggleLike(editId, userId);
  }

  // ══════════════════════════════════════════════
  // ── زيادة المشاهدات + تسجيل المشاهدة
  // ══════════════════════════════════════════════
  Future<void> incrementViews(String editId) async {
    markAsSeen(editId);
    await _service.incrementViews(editId);
  }

  // ── إيديتات مستخدم معين
  Stream<List<EditModel>> getUserEdits(String userId) {
    return _service.getUserEdits(userId);
  }

  // ── حذف إيديت
  Future<void> deleteEdit(EditModel edit) async {
    try {
      await _service.deleteEdit(edit);
      _edits.removeWhere((e) => e.id == edit.id);
      _seenIds.remove(edit.id);
      _checkAllUnseenWatched();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}