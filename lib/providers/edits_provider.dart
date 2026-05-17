import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pubget/models/edits_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firebase/edits_service.dart';

class EditsProvider extends ChangeNotifier {
  final EditsService _service = EditsService();

  List<EditModel> _edits = [];
  final Set<String> _seenIds = {};
  int _totalEditsCount = 0;
  bool _isLoading = false;
  bool _isUploading = false;
  bool _allUnseenWatched = false;
  String? _error;
  EditModel? _lastUploadedEdit;

  List<EditModel> get edits => _edits;
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  bool get allUnseenWatched => _allUnseenWatched;
  String? get error => _error;
  EditModel? get lastUploadedEdit => _lastUploadedEdit;

  static const _seenKey = 'seen_edit_ids';

  Future<void> loadSeenIds() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_seenKey) ?? [];
    _seenIds.addAll(saved);
    notifyListeners();
  }

  Future<void> _saveSeenIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_seenKey, _seenIds.toList());
  }

  void resetError() {
    _error = null;
    notifyListeners();
  }

  void clearLastUploadedEdit() {
    _lastUploadedEdit = null;
    notifyListeners();
  }

  void prependEdit(EditModel edit) {
    _edits.removeWhere((e) => e.id == edit.id);
    _edits = [edit, ..._edits];
    notifyListeners();
  }

  void listenToEdits() {
    _isLoading = true;
    _error = null;
    notifyListeners();

    _service.getEdits(seenIdsGetter: () => _seenIds).listen(
      (data) {
        // ← التعديل: نستخرج القائمة والعدد الكلي من الـ Map
        _edits = (data['edits'] as List<EditModel>);
        _totalEditsCount = data['totalCount'] as int;
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

  void markAsSeen(String editId) {
    if (_seenIds.contains(editId)) return;
    _seenIds.add(editId);
    _saveSeenIds();
    _checkAllUnseenWatched();
    notifyListeners();
  }

  void _checkAllUnseenWatched() {
    if (_totalEditsCount == 0) {
      _allUnseenWatched = false;
      return;
    }
    _allUnseenWatched = _seenIds.length >= _totalEditsCount;
  }

  void resetSeen() {
    _seenIds.clear();
    _saveSeenIds();
    _allUnseenWatched = false;
    notifyListeners();
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

  Future<void> incrementViews(String editId, String userId) async {
    markAsSeen(editId);
    await _service.incrementViews(editId, userId);
  }

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
    void Function(EditModel)? onComplete,
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

      final docId = await _service.postEdit(edit);

      _lastUploadedEdit = edit.copyWith(id: docId);
      _isUploading = false;
      notifyListeners();
      onComplete?.call(_lastUploadedEdit!);
    } catch (e) {
      _error = e.toString();
      _isUploading = false;
      notifyListeners();
      onFailed?.call(e.toString());
    }
  }

  Stream<List<EditModel>> getUserEdits(String userId) {
    return _service.getUserEdits(userId);
  }

  Future<void> deleteEdit(EditModel edit) async {
    try {
      await _service.deleteEdit(edit);
      _edits.removeWhere((e) => e.id == edit.id);
      _seenIds.remove(edit.id);
      _saveSeenIds();
      _checkAllUnseenWatched();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}