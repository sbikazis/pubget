import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/group_models.dart';

/// Local draft recovery so changing type or leaving the form does not
/// silently drop filled fields.
final class GroupCreateDraftStore {
  GroupCreateDraftStore({SharedPreferences? preferences})
    : _preferences = preferences;

  SharedPreferences? _preferences;

  static String _key(GroupType type) => 'group_create_draft_v1_${type.name}';

  Future<SharedPreferences?> _prefs() async {
    try {
      return _preferences ??= await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  Future<void> save({
    required GroupType type,
    required Map<String, dynamic> draft,
  }) async {
    final prefs = await _prefs();
    if (prefs == null) return;
    await prefs.setString(_key(type), jsonEncode(draft));
  }

  Future<Map<String, dynamic>?> load(GroupType type) async {
    final prefs = await _prefs();
    final raw = prefs?.getString(_key(type));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  Future<void> clear(GroupType type) async {
    final prefs = await _prefs();
    await prefs?.remove(_key(type));
  }
}
