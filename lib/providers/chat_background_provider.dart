// lib/providers/chat_background_provider.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

import '../models/chat_background_model.dart';
import '../services/firebase/chat_background_service.dart';
import '../services/local/chat_background_local_service.dart';
import '../core/constants/storage_paths.dart';

class ChatBackgroundProvider extends ChangeNotifier {
  final ChatBackgroundService _firebaseService = ChatBackgroundService();
  final ChatBackgroundLocalService _localService =
      ChatBackgroundLocalService();

  // ══════════════════════════════════════════════
  // ── الحالة
  // ══════════════════════════════════════════════

  /// خلفية دردشة المجموعة (من Firestore/Storage)
  ChatBackgroundModel _groupBackground = const ChatBackgroundModel.none();

  /// خلفية الدردشة الخاصة (محلية فقط)
  ChatBackgroundModel _privateBackground = const ChatBackgroundModel.none();

  /// هل يجري رفع/تحميل الخلفية؟
  bool _isLoading = false;

  // ══════════════════════════════════════════════
  // ── Getters
  // ══════════════════════════════════════════════

  ChatBackgroundModel get groupBackground => _groupBackground;
  ChatBackgroundModel get privateBackground => _privateBackground;
  bool get isLoading => _isLoading;

  /// مسار الخلفية الخاصة (للاستخدام في private_chat_screen)
  String? get privateBackgroundPath =>
      _privateBackground.hasBackground ? _privateBackground.path : null;

  // ══════════════════════════════════════════════
  // ── خلفية المجموعة
  // ══════════════════════════════════════════════

  /// تحميل خلفية المجموعة من URL مباشرةً (يُستدعى من chat_screen)
  void loadGroupBackgroundFromUrl(String? url) {
    if (url == null || url.isEmpty) {
      _groupBackground = const ChatBackgroundModel.none();
    } else {
      _groupBackground = ChatBackgroundModel.network(url: url);
    }
    notifyListeners();
  }

  /// رفع خلفية جديدة للمجموعة إلى Firebase
  /// يعود بالـ URL النهائي
  Future<String> uploadGroupBackground({
    required String groupId,
    required File file,
  }) async {
    _setLoading(true);
    try {
      final url = await _firebaseService.uploadGroupChatBackground(
        groupId: groupId,
        file: file,
      );

      _groupBackground = ChatBackgroundModel.network(url: url);
      notifyListeners();
      return url;
    } finally {
      _setLoading(false);
    }
  }

  /// حذف خلفية المجموعة من Firebase
  Future<void> deleteGroupBackground({required String groupId}) async {
    _setLoading(true);
    try {
      await _firebaseService.deleteGroupChatBackground(groupId: groupId);
      _groupBackground = const ChatBackgroundModel.none();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // ══════════════════════════════════════════════
  // ── خلفية الدردشة الخاصة
  // ══════════════════════════════════════════════

  /// تحميل الخلفية الخاصة من SharedPreferences
  Future<void> loadPrivateBackground({required String chatId}) async {
    try {
      final saved = await _localService.loadBackground(chatId: chatId);
      if (saved != null && saved.hasBackground) {
        _privateBackground = saved;
      } else {
        _privateBackground = const ChatBackgroundModel.none();
      }
      notifyListeners();
    } catch (_) {
      _privateBackground = const ChatBackgroundModel.none();
      notifyListeners();
    }
  }

  /// اختيار وحفظ خلفية محلية للدردشة الخاصة
  Future<void> setPrivateBackground({
    required String chatId,
    required String filePath,
  }) async {
    _setLoading(true);
    try {
      // ✅ استخراج اللون الغالب لحساب الـ overlay المناسب
      final opacity = await _computeOverlayOpacity(filePath: filePath);

      final background = ChatBackgroundModel.local(
        filePath: filePath,
        opacity: opacity,
      );

      await _localService.saveBackground(
        chatId: chatId,
        background: background,
      );

      _privateBackground = background;
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// حذف الخلفية الخاصة
  Future<void> deletePrivateBackground({required String chatId}) async {
    try {
      await _localService.deleteBackground(chatId: chatId);
      _privateBackground = const ChatBackgroundModel.none();
      notifyListeners();
    } catch (_) {}
  }

  // ══════════════════════════════════════════════
  // ── حساب الـ Overlay تلقائياً بناءً على الصورة
  // ══════════════════════════════════════════════

  /// يستخرج اللون الغالب من الصورة ويحدد نسبة الـ overlay
  /// صورة داكنة → overlay أقل (الصورة واضحة أصلاً)
  /// صورة فاتحة → overlay أكثر (نحتاج تعتيم أكثر)
  Future<double> _computeOverlayOpacity({required String filePath}) async {
    try {
      final imageProvider = FileImage(File(filePath));
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        imageProvider,
        maximumColorCount: 8,
      );

      final dominantColor =
          paletteGenerator.dominantColor?.color ?? Colors.grey;

      // حساب درجة الإضاءة (0.0 → أسود، 1.0 → أبيض)
      final luminance = dominantColor.computeLuminance();

      // صورة فاتحة (luminance > 0.5) → overlay أعلى لتعتيمها
      // صورة داكنة (luminance < 0.5) → overlay أقل لأنها داكنة أصلاً
      if (luminance > 0.6) {
        return 0.45; // صورة فاتحة جداً
      } else if (luminance > 0.4) {
        return 0.38; // صورة متوسطة
      } else {
        return 0.28; // صورة داكنة
      }
    } catch (_) {
      // fallback: قيمة افتراضية آمنة
      return 0.38;
    }
  }

  // ══════════════════════════════════════════════
  // ── تنظيف عند تسجيل الخروج
  // ══════════════════════════════════════════════

  /// يمسح جميع الخلفيات المحلية (يُستدعى عند logout)
  Future<void> clearAllLocalBackgrounds() async {
    await _localService.clearAllBackgrounds();
    _privateBackground = const ChatBackgroundModel.none();
    _groupBackground = const ChatBackgroundModel.none();
    notifyListeners();
  }

  /// إعادة تعيين حالة المجموعة فقط
  void resetGroupBackground() {
    _groupBackground = const ChatBackgroundModel.none();
    notifyListeners();
  }

  /// إعادة تعيين حالة الخاصة فقط
  void resetPrivateBackground() {
    _privateBackground = const ChatBackgroundModel.none();
    notifyListeners();
  }

  // ══════════════════════════════════════════════
  // ── Helper
  // ══════════════════════════════════════════════

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}