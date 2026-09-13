import 'dart:async';
import 'dart:math' as math;
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

/// WhatsApp-style microphone capture contract.
abstract interface class VoiceCapture {
  Future<void> start();

  /// Finalize and return the recorded clip (or null if empty/cancelled).
  Future<VoiceClip?> stop();

  /// Discard the in-progress recording without returning a clip.
  Future<void> cancel();

  Future<void> pause();

  Future<void> resume();

  bool get isRecording;

  bool get isPaused;

  /// Normalized amplitude samples in `0..1` while recording (not paused).
  Stream<double> get amplitudeStream;

  /// Local file path for locked-mode preview playback (null if unavailable).
  String? get recordingPath;
}

/// Test/dev capture that records a generated silent clip with fake amplitude.
class MemoryVoiceCapture implements VoiceCapture {
  MemoryVoiceCapture({this.clip, this.amplitudePeriod = const Duration(milliseconds: 80)});

  final VoiceClip? clip;
  final Duration amplitudePeriod;
  var _recording = false;
  var _paused = false;
  DateTime? _startedAt;
  Duration _accumulated = Duration.zero;
  Timer? _ampTimer;
  final _amplitude = StreamController<double>.broadcast();
  final _random = math.Random(7);

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
    // Reset quietly — do not call cancel() so test spies can distinguish
    // user discard from session restart.
    _tearDown();
    _recording = true;
    _paused = false;
    _startedAt = DateTime.now();
    _accumulated = Duration.zero;
    _ampTimer = Timer.periodic(amplitudePeriod, (_) {
      if (!_recording || _paused || _amplitude.isClosed) return;
      _amplitude.add(0.15 + _random.nextDouble() * 0.85);
    });
  }

  @override
  Future<void> pause() async {
    if (!_recording || _paused) return;
    final started = _startedAt;
    if (started != null) {
      _accumulated += DateTime.now().difference(started);
    }
    _paused = true;
    _startedAt = null;
  }

  @override
  Future<void> resume() async {
    if (!_recording || !_paused) return;
    _paused = false;
    _startedAt = DateTime.now();
  }

  @override
  Future<VoiceClip?> stop() async {
    if (!_recording) return null;
    final started = _startedAt;
    var duration = _accumulated;
    if (!_paused && started != null) {
      duration += DateTime.now().difference(started);
    }
    _tearDown();
    return clip ??
        VoiceClip(
          bytes: Uint8List.fromList(const <int>[0, 1, 2, 3]),
          contentType: 'audio/mp4',
          fileName: 'voice.m4a',
          duration: duration == Duration.zero
              ? const Duration(seconds: 2)
              : duration,
        );
  }

  @override
  Future<void> cancel() async {
    _tearDown();
  }

  void _tearDown() {
    _ampTimer?.cancel();
    _ampTimer = null;
    _recording = false;
    _paused = false;
    _startedAt = null;
    _accumulated = Duration.zero;
  }
}
