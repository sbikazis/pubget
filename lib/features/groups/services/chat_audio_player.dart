import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import '../../../core/media/media_reference.dart';

/// Plays a chat voice note from a short-lived Cloudflare R2 URL or bytes.
abstract interface class ChatAudioPlayer {
  Future<void> play(String storagePathOrUrl);
  Future<void> playBytes(Uint8List bytes);
}

final class StorageChatAudioPlayer implements ChatAudioPlayer {
  StorageChatAudioPlayer({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> play(String storagePathOrUrl) async {
    final url = await resolveMediaDownloadUrl(storagePathOrUrl);
    if (url == null) {
      throw StateError('This audio file is unavailable or you do not have access.');
    }
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
