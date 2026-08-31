// lib/providers/sticker_provider.dart
import 'dart:io';
import 'package:flutter/material.dart';

import '../models/sticker_model.dart';
import '../services/firebase/sticker_service.dart';

class StickerProvider extends ChangeNotifier {
  final StickerService _service;

  StickerProvider(this._service);

  // ─── State ─────────────────────────────────────────────────
  List<StickerModel> _stickers = [];
  bool _isLoading = false;
  String? _currentUserId;

  List<StickerModel> get stickers => _stickers;
  bool get isLoading => _isLoading;

  // ─── تحميل ملصقات المستخدم ──────────────────────────────────
  Future<void> loadStickers(String userId) async {
    // لا تعيد التحميل إذا نفس المستخدم وعنده ملصقات
    if (_currentUserId == userId && _stickers.isNotEmpty) return;

    _currentUserId = userId;
    _isLoading = true;
    notifyListeners();

    _stickers = await _service.getUserStickers(userId);

    _isLoading = false;
    notifyListeners();
  }

  // ─── رفع ملصق جديد ─────────────────────────────────────────
  Future<StickerModel?> uploadSticker({
    required String userId,
    required File imageFile,
  }) async {
    final sticker = await _service.uploadSticker(
      userId: userId,
      imageFile: imageFile,
    );

    if (sticker != null) {
      _stickers.insert(0, sticker); // يظهر أول في القائمة
      notifyListeners();
    }

    return sticker;
  }

  // ─── حفظ ملصق مستلم ────────────────────────────────────────
  Future<void> saveReceivedSticker({
    required String userId,
    required StickerModel sticker,
  }) async {
    // تحقق إذا موجود مسبقاً
    final alreadySaved = _stickers.any((s) => s.id == sticker.id);
    if (alreadySaved) return;

    await _service.saveReceivedSticker(userId: userId, sticker: sticker);
    _stickers.insert(0, sticker);
    notifyListeners();
  }

  // ─── حذف ملصق ───────────────────────────────────────────────
  Future<void> deleteSticker({
    required String userId,
    required String stickerId,
  }) async {
    await _service.deleteSticker(userId: userId, stickerId: stickerId);
    _stickers.removeWhere((s) => s.id == stickerId);
    notifyListeners();
  }

  // ─── تفريغ عند تسجيل الخروج ─────────────────────────────────
  void clear() {
    _stickers = [];
    _currentUserId = null;
    notifyListeners();
  }
}