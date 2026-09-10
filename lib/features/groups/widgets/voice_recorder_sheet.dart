import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../models/chat_models.dart';
import '../services/voice_capture.dart';

class VoiceRecorderSheet extends StatefulWidget {
  const VoiceRecorderSheet({required this.capture, this.onPreview, super.key});

  final VoiceCapture capture;
  final Future<void> Function(VoiceClip clip)? onPreview;

  static Future<VoiceClip?> show(
    BuildContext context, {
    required VoiceCapture capture,
    Future<void> Function(VoiceClip clip)? onPreview,
  }) {
    return PubgetBottomSheet.present<VoiceClip>(
      context: context,
      builder: (_) =>
          VoiceRecorderSheet(capture: capture, onPreview: onPreview),
    );
  }

  @override
  State<VoiceRecorderSheet> createState() => _VoiceRecorderSheetState();
}

class _VoiceRecorderSheetState extends State<VoiceRecorderSheet> {
  var _seconds = 0;
  var _recording = false;
  VoiceClip? _clip;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_recording) {
      _timer?.cancel();
      final clip = await widget.capture.stop();
      if (!mounted) return;
      setState(() {
        _recording = false;
        _clip = clip;
      });
      return;
    }
    await widget.capture.start();
    if (!mounted) return;
    setState(() {
      _recording = true;
      _seconds = 0;
      _clip = null;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;
      setState(() => _seconds += 1);
      if (_seconds >= kChatAudioMaxDurationSeconds) {
        timer.cancel();
        final clip = await widget.capture.stop();
        if (!mounted) return;
        setState(() {
          _recording = false;
          _clip = clip;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final clip = _clip;
    final tooLarge = clip?.exceedsLimits == true;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              _recording
                  ? 'Recording $_seconds / $kChatAudioMaxDurationSeconds s'
                  : clip == null
                  ? 'Voice message (max $kChatAudioMaxDurationSeconds s, 10 MB)'
                  : 'Preview ${_clip!.duration.inSeconds}s',
              key: const Key('voice-status'),
            ),
            const SizedBox(height: AppSpacing.md),
            PubgetPrimaryButton(
              key: const Key('voice-toggle'),
              onPressed: _toggle,
              semanticLabel: _recording ? 'Stop recording' : 'Start recording',
              child: Text(_recording ? 'Stop' : 'Record'),
            ),
            if (clip != null) ...[
              const SizedBox(height: AppSpacing.sm),
              if (tooLarge)
                const PubgetEmptyState(
                  title: 'Voice note is too long or too large',
                  compact: true,
                )
              else ...[
                PubgetPrimaryButton(
                  key: const Key('voice-preview'),
                  onPressed: widget.onPreview == null
                      ? null
                      : () => widget.onPreview!(clip),
                  semanticLabel: 'Preview voice message',
                  child: const Text('Preview'),
                ),
                const SizedBox(height: AppSpacing.sm),
                PubgetPrimaryButton(
                  key: const Key('voice-send'),
                  onPressed: () => Navigator.pop(context, clip),
                  semanticLabel: 'Send voice message',
                  child: const Text('Send voice message'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
