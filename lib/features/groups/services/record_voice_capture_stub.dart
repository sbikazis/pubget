import 'voice_capture.dart';

/// Web/stub capture. Device recording uses the IO implementation.
final class RecordVoiceCapture implements VoiceCapture {
  var _recording = false;

  @override
  bool get isRecording => _recording;

  @override
  Future<void> start() async {
    _recording = true;
    throw UnsupportedError('Voice recording is available on mobile devices.');
  }

  @override
  Future<VoiceClip?> stop() async {
    _recording = false;
    return null;
  }
}
