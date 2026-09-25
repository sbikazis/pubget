import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'fan_work_repository.dart';

/// File-backed draft persistence so unsaved work survives app restarts
/// (spec §17.2: "مسودات قابلة للاستعادة بعد إغلاق التطبيق").
final class SharedPreferencesFanWorkDraftStore implements FanWorkDraftStore {
  SharedPreferencesFanWorkDraftStore({SharedPreferences? preferences})
    : _preferences = preferences;

  static const _key = 'fan_work_drafts_v1';

  SharedPreferences? _preferences;

  Future<SharedPreferences?> _prefs() async {
    try {
      return _preferences ??= await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, Map<String, dynamic> data) async {
    final prefs = await _prefs();
    if (prefs == null) return;
    final raw = prefs.getString(_key);
    final all = _decode(raw);
    all[key] = Map<String, dynamic>.from(data);
    await prefs.setString(_key, jsonEncode(all));
  }

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    final prefs = await _prefs();
    if (prefs == null) return null;
    final all = _decode(prefs.getString(_key));
    final stored = all[key];
    return stored == null ? null : Map<String, dynamic>.from(stored);
  }

  @override
  Future<void> delete(String key) async {
    final prefs = await _prefs();
    if (prefs == null) return;
    final all = _decode(prefs.getString(_key));
    all.remove(key);
    await prefs.setString(_key, jsonEncode(all));
  }

  Map<String, dynamic> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return <String, dynamic>{};
  }
}
