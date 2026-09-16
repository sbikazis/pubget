import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Plays a chat voice note. Storage paths are resolved to download URLs.
abstract interface class ChatAudioPlayer {
  Future<void> play(String storagePathOrUrl);
  Future<void> playBytes(Uint8List bytes);
}

final class StorageChatAudioPlayer implements ChatAudioPlayer {
  StorageChatAudioPlayer({AudioPlayer? player, FirebaseStorage? storage})
    : _player = player ?? AudioPlayer(),
      _storage = storage ?? FirebaseStorage.instance;

  final AudioPlayer _player;
  final FirebaseStorage _storage;

  @override
  Future<void> play(String storagePathOrUrl) async {
    final url =
        storagePathOrUrl.startsWith('http://') ||
            storagePathOrUrl.startsWith('https://')
        ? storagePathOrUrl
        : await _storage.ref(storagePathOrUrl).getDownloadURL();
    await _player.stop();
    await _player.play(UrlSource(url));
  }

  @override
  Future<void> playBytes(Uint8List bytes) async {
    await _player.stop();
    await _player.play(BytesSource(bytes));
  }
}

/// Test double that records play requests without touching plugins.
final class MemoryChatAudioPlayer implements ChatAudioPlayer {
  final played = <String>[];

  @override
  Future<void> play(String storagePathOrUrl) async {
    played.add(storagePathOrUrl);
  }

  @override
  Future<void> playBytes(Uint8List bytes) async {
    played.add('bytes:${bytes.length}');
  }
}
