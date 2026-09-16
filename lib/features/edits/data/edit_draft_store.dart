import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

final class EditDraftStore {
  EditDraftStore({SharedPreferences? preferences}) : _preferences = preferences;

  SharedPreferences? _preferences;
  static const _key = 'edit_upload_draft_v1';

  Future<SharedPreferences?> _prefs() async {
    try {
      return _preferences ??= await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  Future<void> save(Map<String, dynamic> draft) async {
    final prefs = await _prefs();
    await prefs?.setString(_key, jsonEncode(draft));
  }

  Future<Map<String, dynamic>?> load() async {
    final prefs = await _prefs();
    final raw = prefs?.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  Future<void> clear() async {
    final prefs = await _prefs();
    await prefs?.remove(_key);
  }
}
