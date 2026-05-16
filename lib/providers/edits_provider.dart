import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pubget/models/edits_model.dart';
import '../services/firebase/edits_service.dart';

class EditsProvider extends ChangeNotifier {
  final EditsService _service = EditsService();

  List<EditModel> _edits = [];
  bool _isLoading = false;
  bool _isUploading = false;
  String? _error;

  List<EditModel> get edits => _edits;
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  String? get error => _error;

  void resetError() {
    _error = null;
    notifyListeners();
  }

  void listenToEdits() {
    _isLoading = true;
    _error = null;
    notifyListeners();

    _service.getEdits().listen(
      (data) {
        _edits = data;
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  // ── رفع في الخلفية بدون انتظار
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

  Future<void> incrementViews(String editId) async {
    await _service.incrementViews(editId);
  }

  // ── إيديتات مستخدم معين للبروفايل
  Stream<List<EditModel>> getUserEdits(String userId) {
    return _service.getUserEdits(userId);
  }

  // ── حذف إيديت
  Future<void> deleteEdit(EditModel edit) async {
    try {
      await _service.deleteEdit(edit);
      _edits.removeWhere((e) => e.id == edit.id);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}