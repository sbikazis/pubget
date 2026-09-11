import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A locally saved sticker with attribution to the original creator.
final class UserStickerEntry {
  const UserStickerEntry({
    required this.id,
    required this.path,
    required this.creatorId,
    required this.creatorName,
    this.sourceMediaUrl,
  });

  final String id;
  final String path;
  final String creatorId;
  final String creatorName;
  final String? sourceMediaUrl;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'path': path,
    'creatorId': creatorId,
    'creatorName': creatorName,
    if (sourceMediaUrl != null) 'sourceMediaUrl': sourceMediaUrl,
  };

  factory UserStickerEntry.fromJson(Map<String, dynamic> json) {
    return UserStickerEntry(
      id: json['id'] as String? ?? '',
      path: json['path'] as String? ?? '',
      creatorId: json['creatorId'] as String? ?? '',
      creatorName: json['creatorName'] as String? ?? '',
      sourceMediaUrl: json['sourceMediaUrl'] as String?,
    );
  }
}

/// Persists user stickers (local files + original creator metadata).
final class UserStickerStore {
  UserStickerStore({SharedPreferences? preferences}) : _preferences = preferences;

  SharedPreferences? _preferences;
  static const _entriesKey = 'pubget.chat.stickers.user_entries';
  static const _legacyPathsKey = 'pubget.chat.stickers.user_paths';

  Future<SharedPreferences> _prefs() async =>
      _preferences ??= await SharedPreferences.getInstance();

  Future<List<UserStickerEntry>> entries() async {
    try {
      final prefs = await _prefs();
      await _migrateLegacy(prefs);
      final raw = prefs.getStringList(_entriesKey) ?? const <String>[];
      final out = <UserStickerEntry>[];
      for (final item in raw) {
        try {
          final map = jsonDecode(item);
          if (map is! Map) continue;
          final entry = UserStickerEntry.fromJson(
            Map<String, dynamic>.from(map),
          );
          if (entry.path.isEmpty) continue;
          if (!File(entry.path).existsSync()) continue;
          out.add(entry);
        } catch (_) {}
      }
      return out;
    } catch (_) {
      return const <UserStickerEntry>[];
    }
  }

  Future<List<String>> paths() async {
    return (await entries()).map((e) => e.path).toList(growable: false);
  }

  Future<UserStickerEntry?> entryForPath(String path) async {
    for (final entry in await entries()) {
      if (entry.path == path) return entry;
    }
    return null;
  }

  Future<bool> containsCreatorMedia({
    required String creatorId,
    required String? sourceMediaUrl,
  }) async {
    if (sourceMediaUrl == null || sourceMediaUrl.isEmpty) return false;
    for (final entry in await entries()) {
      if (entry.creatorId == creatorId &&
          entry.sourceMediaUrl == sourceMediaUrl) {
        return true;
      }
    }
    return false;
  }

  Future<UserStickerEntry> addFromBytes(
    List<int> bytes, {
    String extension = 'png',
    required String creatorId,
    required String creatorName,
    String? sourceMediaUrl,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final stickersDir = Directory('${dir.path}/user_stickers');
    if (!await stickersDir.exists()) {
      await stickersDir.create(recursive: true);
    }
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final dest = File('${stickersDir.path}/sticker_$id.$extension');
    await dest.writeAsBytes(bytes, flush: true);
    final entry = UserStickerEntry(
      id: id,
      path: dest.path,
      creatorId: creatorId,
      creatorName: creatorName,
      sourceMediaUrl: sourceMediaUrl,
    );
    final prefs = await _prefs();
    final current = prefs.getStringList(_entriesKey) ?? <String>[];
    final next = <String>[
      jsonEncode(entry.toJson()),
      ...current.where((raw) {
        try {
          final map = jsonDecode(raw);
          if (map is! Map) return true;
          return map['path'] != entry.path;
        } catch (_) {
          return true;
        }
      }),
    ];
    await prefs.setStringList(_entriesKey, next);
    return entry;
  }

  Future<UserStickerEntry> addFromFile(
    File source, {
    required String creatorId,
    required String creatorName,
    String? sourceMediaUrl,
  }) async {
    final bytes = await source.readAsBytes();
    final name = source.path.toLowerCase();
    final extension = name.endsWith('.jpg') || name.endsWith('.jpeg')
        ? 'jpg'
        : name.endsWith('.webp')
        ? 'webp'
        : 'png';
    return addFromBytes(
      bytes,
      extension: extension,
      creatorId: creatorId,
      creatorName: creatorName,
      sourceMediaUrl: sourceMediaUrl,
    );
  }

  Future<void> remove(String path) async {
    final prefs = await _prefs();
    final next = (prefs.getStringList(_entriesKey) ?? const <String>[]).where((
      raw,
    ) {
      try {
        final map = jsonDecode(raw);
        if (map is! Map) return true;
        return map['path'] != path;
      } catch (_) {
        return true;
      }
    }).toList(growable: false);
    await prefs.setStringList(_entriesKey, next);
    final file = File(path);
    if (file.existsSync()) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  Future<void> _migrateLegacy(SharedPreferences prefs) async {
    final legacy = prefs.getStringList(_legacyPathsKey);
    if (legacy == null || legacy.isEmpty) return;
    final existing = prefs.getStringList(_entriesKey) ?? <String>[];
    final existingPaths = <String>{};
    for (final raw in existing) {
      try {
        final map = jsonDecode(raw);
        if (map is Map && map['path'] is String) {
          existingPaths.add(map['path'] as String);
        }
      } catch (_) {}
    }
    final merged = <String>[...existing];
    for (final path in legacy) {
      if (existingPaths.contains(path)) continue;
      merged.add(
        jsonEncode(
          UserStickerEntry(
            id: path.hashCode.toString(),
            path: path,
            creatorId: '',
            creatorName: '',
          ).toJson(),
        ),
      );
    }
    await prefs.setStringList(_entriesKey, merged);
    await prefs.remove(_legacyPathsKey);
  }
}
