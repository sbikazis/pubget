import 'dart:typed_data';

import '../models/chat_models.dart';

final class VoiceClip {
  const VoiceClip({
    required this.bytes,
    required this.contentType,
    required this.fileName,
    required this.duration,
  });

  final Uint8List bytes;
  final String contentType;
  final String fileName;
  final Duration duration;

  bool get exceedsLimits =>
      bytes.length > kChatAudioMaxBytes ||
      duration.inSeconds > kChatAudioMaxDurationSeconds;
}

abstract interface class VoiceCapture {
  Future<void> start();
  Future<VoiceClip?> stop();
  bool get isRecording;
}

/// Test/dev capture that records a generated silent clip.
final class MemoryVoiceCapture implements VoiceCapture {
  MemoryVoiceCapture({this.clip});

  final VoiceClip? clip;
  var _recording = false;

  @override
  bool get isRecording => _recording;

  @override
  Future<void> start() async {
    _recording = true;
  }

  @override
  Future<VoiceClip?> stop() async {
    _recording = false;
    return clip ??
        VoiceClip(
          bytes: Uint8List.fromList(const <int>[0, 1, 2, 3]),
          contentType: 'audio/mp4',
          fileName: 'voice.m4a',
          duration: const Duration(seconds: 2),
        );
  }
}
