import 'package:shared_preferences/shared_preferences.dart';

final class StickerStore {
  StickerStore({SharedPreferences? preferences}) : _preferences = preferences;

  SharedPreferences? _preferences;
  static const _recentKey = 'pubget.chat.stickers.recent';
  static const _favoriteKey = 'pubget.chat.stickers.favorites';

  Future<SharedPreferences> _prefs() async =>
      _preferences ??= await SharedPreferences.getInstance();

  Future<List<String>> recent() async {
    return (await _prefs()).getStringList(_recentKey) ?? const <String>[];
  }

  Future<Set<String>> favorites() async {
    return ((await _prefs()).getStringList(_favoriteKey) ?? const <String>[])
        .toSet();
  }

  Future<void> remember(String key) async {
    final prefs = await _prefs();
    final next = <String>[
      key,
      ...((prefs.getStringList(_recentKey) ?? const <String>[]).where(
        (item) => item != key,
      )),
    ];
    await prefs.setStringList(
      _recentKey,
      next.take(12).toList(growable: false),
    );
  }

  Future<void> toggleFavorite(String key) async {
    final prefs = await _prefs();
    final current = (prefs.getStringList(_favoriteKey) ?? const <String>[])
        .toSet();
    if (!current.add(key)) current.remove(key);
    await prefs.setStringList(_favoriteKey, current.toList(growable: false));
  }
}
