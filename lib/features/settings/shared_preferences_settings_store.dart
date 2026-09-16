import 'package:shared_preferences/shared_preferences.dart';

import 'settings_store.dart';

final class SharedPreferencesSettingsStore implements SettingsStore {
  SharedPreferencesSettingsStore({SharedPreferences? preferences})
    : _preferences = preferences;

  SharedPreferences? _preferences;
  static const _themeKey = 'pubget.settings.themeMode';
  static const _localeKey = 'pubget.settings.locale';

  Future<SharedPreferences> _instance() async =>
      _preferences ??= await SharedPreferences.getInstance();

  @override
  Future<Map<String, String>> read() async {
    final prefs = await _instance();
    return <String, String>{
      if (prefs.getString(_themeKey) != null)
        'themeMode': prefs.getString(_themeKey)!,
      if (prefs.getString(_localeKey) != null)
        'locale': prefs.getString(_localeKey)!,
    };
  }

  @override
  Future<void> write(Map<String, String> values) async {
    final prefs = await _instance();
    final theme = values['themeMode'];
    final locale = values['locale'];
    if (theme != null) {
      await prefs.setString(_themeKey, theme);
    }
    if (locale != null) {
      await prefs.setString(_localeKey, locale);
    }
  }
}
