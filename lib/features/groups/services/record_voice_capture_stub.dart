import 'dart:async';

import 'voice_capture.dart';

/// Web/stub capture. Device recording uses the IO implementation.
final class RecordVoiceCapture implements VoiceCapture {
  var _recording = false;
  var _paused = false;
  final _amplitude = StreamController<double>.broadcast();

  @override
  bool get isRecording => _recording;

  @override
  bool get isPaused => _paused;

  @override
  Stream<double> get amplitudeStream => _amplitude.stream;

  @override
  String? get recordingPath => null;

  @override
  Future<void> start() async {
    _recording = true;
    _paused = false;
    throw UnsupportedError('Voice recording is available on mobile devices.');
  }

  @override
  Future<void> pause() async {
    if (_recording) _paused = true;
  }

  @override
  Future<void> resume() async {
    if (_recording) _paused = false;
  }

  @override
  Future<VoiceClip?> stop() async {
    _recording = false;
    _paused = false;
    return null;
  }

  @override
  Future<void> cancel() async {
    _recording = false;
    _paused = false;
  }
}
