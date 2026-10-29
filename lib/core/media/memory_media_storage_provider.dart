import 'dart:math';
import 'dart:typed_data';

import 'media_kind.dart';
import 'media_keys.dart';
import 'media_storage_provider.dart';

/// In-memory backend for tests and previews. Bytes never leave the process,
/// and every key resolves to a `memory://` URL.
final class MemoryMediaStorageProvider implements MediaStorageProvider {
  MemoryMediaStorageProvider({Random? random})
      : _random = random ?? Random.secure();

  final Random _random;
  final Map<String, (Uint8List, String)> _objects =
      <String, (Uint8List, String)>{};

  /// Every stored key, in insertion order — test helper for list assertions.
  List<String> get keys => _objects.keys.toList(growable: false);

  @override
  MediaBackend get backend => MediaBackend.memory;

  @override
  Future<String> upload({
    required String ownerUid,
    required MediaKind kind,
    required Uint8List bytes,
    required String contentType,
    required String extension,
    void Function(double progress)? onProgress,
  }) async {
    final key = buildMediaKey(
      kind: kind,
      ownerUid: ownerUid,
      extension: extension,
      random: _random,
    );
    _objects[key] = (bytes, contentType);
    onProgress?.call(1);
    return key;
  }

  @override
  Future<void> delete(String storageKey) async {
    _objects.remove(storageKey);
  }

  @override
  Future<String> resolveUrl(String storageKey) async => 'memory://$storageKey';

  /// Test helper: the stored bytes for [storageKey], or null.
  Uint8List? bytesOf(String storageKey) => _objects[storageKey]?.$1;

  /// Test helper: raises when [storageKey] exists — used to prove deletes.
  bool contains(String storageKey) => _objects.containsKey(storageKey);
}
