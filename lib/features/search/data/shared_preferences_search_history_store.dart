import 'package:shared_preferences/shared_preferences.dart';

import '../search_history.dart';

/// Device-local persistence for [SearchHistory] (spec §6).
///
/// Same pattern as every other local store in the app: the plugin is resolved
/// lazily and every failure is swallowed into "no history". Losing a
/// convenience list must never be able to break the search box.
final class SharedPreferencesSearchHistoryStore implements SearchHistoryStore {
  SharedPreferencesSearchHistoryStore({SharedPreferences? preferences})
    : _preferences = preferences;

  static const _key = 'pubget.search.history.v1';

  SharedPreferences? _preferences;

  Future<SharedPreferences?> _prefs() async {
    try {
      return _preferences ??= await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<String>> read() async {
    try {
      final prefs = await _prefs();
      return prefs?.getStringList(_key) ?? const <String>[];
    } catch (_) {
      return const <String>[];
    }
  }

  @override
  Future<void> write(List<String> entries) async {
    try {
      final prefs = await _prefs();
      await prefs?.setStringList(_key, entries);
    } catch (_) {
      // History is a convenience; a failed write is not worth an error state.
    }
  }
}
