import 'voice_capture.dart';
import 'record_voice_capture_stub.dart'
    if (dart.library.io) 'record_voice_capture.dart';

VoiceCapture createDeviceVoiceCapture() => RecordVoiceCapture();
