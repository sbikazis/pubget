import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists user-created sticker image paths (local files only).
final class UserStickerStore {
  UserStickerStore({SharedPreferences? preferences}) : _preferences = preferences;

  SharedPreferences? _preferences;
  static const _pathsKey = 'pubget.chat.stickers.user_paths';

  Future<SharedPreferences> _prefs() async =>
      _preferences ??= await SharedPreferences.getInstance();

  Future<List<String>> paths() async {
    try {
      final raw = (await _prefs()).getStringList(_pathsKey) ?? const <String>[];
      return raw.where((path) {
        try {
          return File(path).existsSync();
        } catch (_) {
          return false;
        }
      }).toList(growable: false);
    } catch (_) {
      return const <String>[];
    }
  }

  Future<String> addFromBytes(List<int> bytes, {String extension = 'png'}) async {
    final dir = await getApplicationDocumentsDirectory();
    final stickersDir = Directory('${dir.path}/user_stickers');
    if (!await stickersDir.exists()) {
      await stickersDir.create(recursive: true);
    }
    final id = DateTime.now().millisecondsSinceEpoch;
    final dest = File('${stickersDir.path}/sticker_$id.$extension');
    await dest.writeAsBytes(bytes, flush: true);
    final prefs = await _prefs();
    final next = <String>[
      dest.path,
      ...(prefs.getStringList(_pathsKey) ?? const <String>[]).where(
        (path) => path != dest.path,
      ),
    ];
    await prefs.setStringList(_pathsKey, next);
    return dest.path;
  }

  Future<String> addFromFile(File source) async {
    final bytes = await source.readAsBytes();
    final name = source.path.toLowerCase();
    final extension = name.endsWith('.jpg') || name.endsWith('.jpeg')
        ? 'jpg'
        : name.endsWith('.webp')
        ? 'webp'
        : 'png';
    return addFromBytes(bytes, extension: extension);
  }

  Future<void> remove(String path) async {
    final prefs = await _prefs();
    final next = (prefs.getStringList(_pathsKey) ?? const <String>[])
        .where((item) => item != path)
        .toList(growable: false);
    await prefs.setStringList(_pathsKey, next);
    final file = File(path);
    if (file.existsSync()) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }
}
