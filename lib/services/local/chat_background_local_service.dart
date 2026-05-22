// lib/services/local/chat_background_local_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/chat_background_model.dart';

class ChatBackgroundLocalService {
  // ══════════════════════════════════════════════
  // ── مفاتيح SharedPreferences
  // ══════════════════════════════════════════════

  /// مفتاح خلفية الدردشة الخاصة
  /// الصيغة: chat_bg_{chatId}
  static String _bgKey(String chatId) => 'chat_bg_$chatId';

  // ══════════════════════════════════════════════
  // ── حفظ الخلفية محلياً
  // ══════════════════════════════════════════════

  /// يحفظ خلفية الدردشة الخاصة في SharedPreferences
  Future<void> saveBackground({
    required String chatId,
    required ChatBackgroundModel background,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(background.toLocalMap());
      await prefs.setString(_bgKey(chatId), encoded);
    } catch (e) {
      throw Exception('فشل حفظ الخلفية محلياً: $e');
    }
  }

  // ══════════════════════════════════════════════
  // ── تحميل الخلفية المحفوظة
  // ══════════════════════════════════════════════

  /// يجلب خلفية الدردشة الخاصة من SharedPreferences
  /// يعود بـ null إذا لم تكن هناك خلفية محفوظة
  Future<ChatBackgroundModel?> loadBackground({
    required String chatId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_bgKey(chatId));

      if (raw == null || raw.isEmpty) return null;

      final map = jsonDecode(raw) as Map<String, dynamic>;
      return ChatBackgroundModel.fromLocalMap(map);
    } catch (e) {
      // إذا تلف الـ JSON → إرجاع null بدل crash
      return null;
    }
  }

  // ══════════════════════════════════════════════
  // ── حذف الخلفية
  // ══════════════════════════════════════════════

  /// يحذف خلفية الدردشة الخاصة من SharedPreferences
  Future<void> deleteBackground({
    required String chatId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_bgKey(chatId));
    } catch (e) {
      throw Exception('فشل حذف الخلفية المحلية: $e');
    }
  }

  // ══════════════════════════════════════════════
  // ── حذف جميع الخلفيات (تنظيف شامل)
  // ══════════════════════════════════════════════

  /// يحذف جميع الخلفيات المحفوظة محلياً
  /// مفيد عند تسجيل الخروج
  Future<void> clearAllBackgrounds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final bgKeys = keys.where((k) => k.startsWith('chat_bg_')).toList();

      for (final key in bgKeys) {
        await prefs.remove(key);
      }
    } catch (e) {
      throw Exception('فشل مسح الخلفيات المحلية: $e');
    }
  }

  // ══════════════════════════════════════════════
  // ── التحقق من وجود خلفية
  // ══════════════════════════════════════════════

  /// يتحقق إذا كانت هناك خلفية محفوظة لهذه المحادثة
  Future<bool> hasBackground({required String chatId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_bgKey(chatId));
    } catch (e) {
      return false;
    }
  }
}