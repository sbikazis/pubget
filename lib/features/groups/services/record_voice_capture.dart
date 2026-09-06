import 'dart:io';

import 'package:record/record.dart';

import 'voice_capture.dart';

/// Device microphone capture. Encodes AAC/M4A to match Storage rules.
final class RecordVoiceCapture implements VoiceCapture {
  RecordVoiceCapture({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  DateTime? _startedAt;
  String? _path;

  @override
  bool get isRecording => _startedAt != null;

  @override
  Future<void> start() async {
    final allowed = await _recorder.hasPermission();
    if (!allowed) {
      throw StateError('Microphone permission is required.');
    }
    _path =
        '${Directory.systemTemp.path}/pubget_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _startedAt = DateTime.now();
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _path!,
    );
  }

  @override
  Future<VoiceClip?> stop() async {
    final path = await _recorder.stop() ?? _path;
    final started = _startedAt;
    _startedAt = null;
    _path = null;
    if (path == null || started == null) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    return VoiceClip(
      bytes: await file.readAsBytes(),
      contentType: 'audio/mp4',
      fileName: 'voice.m4a',
      duration: DateTime.now().difference(started),
    );
  }
}
