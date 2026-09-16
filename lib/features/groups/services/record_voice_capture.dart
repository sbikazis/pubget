import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:record/record.dart';

import 'voice_capture.dart';

/// Device microphone capture.
///
/// Encodes AAC-LC in an M4A container to match Storage upload rules (mobile
/// WhatsApp-equivalent quality/size). Enables echo/noise suppression and
/// interruption pause via the `record` audio session.
final class RecordVoiceCapture implements VoiceCapture {
  RecordVoiceCapture({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  DateTime? _startedAt;
  Duration _pausedAccumulated = Duration.zero;
  String? _path;
  StreamSubscription<Amplitude>? _ampSub;
  final _amplitude = StreamController<double>.broadcast();
  var _paused = false;

  @override
  bool get isRecording => _startedAt != null || _paused;

  @override
  bool get isPaused => _paused;

  @override
  Stream<double> get amplitudeStream => _amplitude.stream;

  @override
  String? get recordingPath => _path;

  @override
  Future<void> start() async {
    final allowed = await _recorder.hasPermission();
    if (!allowed) {
      throw StateError('Microphone permission is required.');
    }
    await cancel();
    _path =
        '${Directory.systemTemp.path}/pubget_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _startedAt = DateTime.now();
    _pausedAccumulated = Duration.zero;
    _paused = false;
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 44100,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
        autoGain: true,
        audioInterruption: AudioInterruptionMode.pause,
        androidConfig: AndroidRecordConfig(
          audioSource: AndroidAudioSource.voiceCommunication,
          manageBluetooth: true,
          audioManagerMode: AudioManagerMode.modeInCommunication,
        ),
        iosConfig: IosRecordConfig(
          categoryOptions: <IosAudioCategoryOption>[
            IosAudioCategoryOption.duckOthers,
            IosAudioCategoryOption.defaultToSpeaker,
            IosAudioCategoryOption.allowBluetooth,
            IosAudioCategoryOption.allowBluetoothA2DP,
          ],
        ),
      ),
      path: _path!,
    );
    _ampSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 80))
        .listen((amp) {
          final normalized = ((amp.current + 45) / 45).clamp(0.0, 1.0);
          if (!_amplitude.isClosed) {
            _amplitude.add(math.max(0.08, normalized));
          }
        });
  }

  @override
  Future<void> pause() async {
    if (!isRecording || _paused) return;
    await _recorder.pause();
    final started = _startedAt;
    if (started != null) {
      _pausedAccumulated += DateTime.now().difference(started);
    }
    _startedAt = null;
    _paused = true;
  }

  @override
  Future<void> resume() async {
    if (!_paused) return;
    await _recorder.resume();
    _paused = false;
    _startedAt = DateTime.now();
  }

  @override
  Future<VoiceClip?> stop() async {
    if (!isRecording && _path == null) return null;
    final path = await _recorder.stop() ?? _path;
    final started = _startedAt;
    var duration = _pausedAccumulated;
    if (!_paused && started != null) {
      duration += DateTime.now().difference(started);
    }
    await _cleanupSubscription();
    _startedAt = null;
    _paused = false;
    _path = null;
    _pausedAccumulated = Duration.zero;
    if (path == null) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    final bytes = await file.readAsBytes();
    try {
      await file.delete();
    } catch (_) {}
    if (bytes.isEmpty) return null;
    return VoiceClip(
      bytes: bytes,
      contentType: 'audio/mp4',
      fileName: 'voice.m4a',
      duration: duration < const Duration(milliseconds: 250)
          ? const Duration(milliseconds: 250)
          : duration,
    );
  }

  @override
  Future<void> cancel() async {
    try {
      await _recorder.cancel();
    } catch (_) {
      try {
        if (await _recorder.isRecording() || await _recorder.isPaused()) {
          await _recorder.stop();
        }
      } catch (_) {}
    }
    final path = _path;
    await _cleanupSubscription();
    _startedAt = null;
    _paused = false;
    _path = null;
    _pausedAccumulated = Duration.zero;
    if (path != null) {
      final file = File(path);
      if (file.existsSync()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> _cleanupSubscription() async {
    await _ampSub?.cancel();
    _ampSub = null;
  }
}
