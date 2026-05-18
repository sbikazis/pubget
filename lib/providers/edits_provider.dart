import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/edits_model.dart';
import '../services/firebase/edits_service.dart';

class EditsProvider extends ChangeNotifier {
  final EditsService _service = EditsService();
  final Map<String, EditModel> _editsMap = {};
  final Map<String, Set<String>> _pendingLikeUpdates = {};
  final Set<String> _seenIds = {};
  List<EditModel> _sessionFeed = [];
  StreamSubscription<List<EditModel>>? _editsSubscription;
  bool _isLoading = false, _isUploading = false, _isListening = false;
  String? _error;
  EditModel? _lastUploadedEdit;
  static const String _seenKey = 'seen_edit_ids';
  final ValueNotifier<EditModel?> uploadCompletedNotifier = ValueNotifier<EditModel?>(null);

  List<EditModel> get edits => List.unmodifiable(_sessionFeed);
  List<EditModel> get sessionFeed => List.unmodifiable(_sessionFeed);
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  String? get error => _error;
  EditModel? get lastUploadedEdit => _lastUploadedEdit;
  bool get allUnseenWatched => _sessionFeed.isEmpty;
  EditModel? getEditById(String id) => _editsMap[id];

  Future<void> loadSeenIds() async {
    final prefs = await SharedPreferences.getInstance();
    _seenIds.addAll(prefs.getStringList(_seenKey)?? []);
  }
  Future<void> _saveSeenIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_seenKey, _seenIds.toList());
  }

  Future<void> listenToEdits() async {
    if (_isListening) return;
    _isListening = true; _isLoading = true; notifyListeners();
    await _editsSubscription?.cancel();
    _editsSubscription = _service.getEdits().listen((incoming) {
      _mergeIncomingEdits(incoming); _isLoading = false; notifyListeners();
    }, onError: (e) { _error = e.toString(); _isLoading = false; notifyListeners(); });
  }

  void _mergeIncomingEdits(List<EditModel> incoming) {
    bool changed = false;
    for (final edit in incoming) {
      final existing = _editsMap[edit.id];
      if (existing == null) {
        _editsMap[edit.id] = edit;
        if (!_seenIds.contains(edit.id)) _sessionFeed.add(edit);
        changed = true; continue;
      }
      final merged = _mergeEdit(existing, edit);
      _editsMap[edit.id] = merged;
      final idx = _sessionFeed.indexWhere((e) => e.id == edit.id);
      if (idx!= -1) _sessionFeed[idx] = merged;
      changed = true;
    }
    if (changed) _sessionFeed.sort((a,b)=>b.createdAt.compareTo(a.createdAt));
  }

  EditModel _mergeEdit(EditModel local, EditModel remote) {
    final pending = _pendingLikeUpdates[local.id];
    if (pending == null) return remote;
    final remoteSet = remote.likes.toSet();
    if (remoteSet.length == pending.length && remoteSet.containsAll(pending)) {
      _pendingLikeUpdates.remove(local.id);
      return remote;
    }
    return remote.copyWith(likes: pending.toList());
  }

  void markAsSeen(String editId) {
    if (_seenIds.contains(editId)) return;
    _seenIds.add(editId); _saveSeenIds();
  }

  Future<void> toggleLike(String editId, String userId) async {
  final existing = _editsMap[editId]; if (existing == null) return;
  final updatedLikes = List<String>.from(existing.likes);
  updatedLikes.contains(userId)? updatedLikes.remove(userId) : updatedLikes.add(userId);
  _pendingLikeUpdates[editId] = updatedLikes.toSet();
  final updatedEdit = existing.copyWith(likes: updatedLikes);
  _editsMap[editId] = updatedEdit;
  final idx = _sessionFeed.indexWhere((e) => e.id == editId);
  if (idx!= -1) _sessionFeed[idx] = updatedEdit;

  _error = 'TEST ${updatedLikes.length}'; // ← سيظهر على الشاشة
  notifyListeners();

  try { await _service.toggleLike(editId, userId); _error = null; notifyListeners(); } catch(e){ _error = 'ERR $e'; notifyListeners(); }
}

  Future<void> incrementViews(String editId, String userId) async { markAsSeen(editId); await _service.incrementViews(editId, userId); }
  void prependEdit(EditModel edit) { _editsMap[edit.id]=edit; _sessionFeed.removeWhere((e)=>e.id==edit.id); _sessionFeed.insert(0,edit); notifyListeners(); }
  Future<void> resetSeen() async { _seenIds.clear(); await _saveSeenIds(); _sessionFeed=_editsMap.values.toList()..sort((a,b)=>b.createdAt.compareTo(a.createdAt)); notifyListeners(); }
  void resetError(){ _error=null; notifyListeners(); }
  void clearLastUploadedEdit(){ _lastUploadedEdit=null; uploadCompletedNotifier.value=null; notifyListeners(); }

  void uploadEditInBackground({required File videoFile, required File thumbnailFile, required String userId, required String uploaderName, required String uploaderAvatar, required String animeTitle, required String caption, void Function(EditModel)? onComplete, void Function(String)? onFailed}) {
    if (_isUploading) return; _isUploading=true; notifyListeners();
    _runUpload(videoFile:videoFile, thumbnailFile:thumbnailFile, userId:userId, uploaderName:uploaderName, uploaderAvatar:uploaderAvatar, animeTitle:animeTitle, caption:caption, onComplete:onComplete, onFailed:onFailed);
  }

  Future<void> _runUpload({required File videoFile, required File thumbnailFile, required String userId, required String uploaderName, required String uploaderAvatar, required String animeTitle, required String caption, void Function(EditModel)? onComplete, void Function(String)? onFailed}) async {
    try {
      final videoUrl = await _service.uploadVideo(videoFile, userId);
      final thumbnailUrl = await _service.uploadThumbnail(thumbnailFile, userId);
      final edit = EditModel(id:'', uploaderId:userId, uploaderName:uploaderName, uploaderAvatar:uploaderAvatar, videoUrl:videoUrl, thumbnailUrl:thumbnailUrl, animeTitle:animeTitle, caption:caption, likes:[], commentsCount:0, views:0, createdAt:DateTime.now());
      final docId = await _service.postEdit(edit);
      final uploadedEdit = edit.copyWith(id:docId);
      _lastUploadedEdit = uploadedEdit; uploadCompletedNotifier.value = uploadedEdit; _isUploading=false; notifyListeners(); onComplete?.call(uploadedEdit);
    } catch(e){ _error=e.toString(); _isUploading=false; notifyListeners(); onFailed?.call(e.toString()); }
  }

  Stream<List<EditModel>> getUserEdits(String userId) => _service.getUserEdits(userId);
  Future<void> deleteEdit(EditModel edit) async { try{ await _service.deleteEdit(edit); _editsMap.remove(edit.id); _sessionFeed.removeWhere((e)=>e.id==edit.id); _seenIds.remove(edit.id); await _saveSeenIds(); notifyListeners(); }catch(e){ _error=e.toString(); notifyListeners(); } }
  @override void dispose(){ _editsSubscription?.cancel(); uploadCompletedNotifier.dispose(); super.dispose(); }
}