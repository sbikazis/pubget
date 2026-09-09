import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/sticker_store.dart';
import '../../data/user_sticker_store.dart';
import '../../models/chat_models.dart';
import '../../services/voice_capture.dart';
import 'wa_attachment_sheet.dart';
import 'wa_colors.dart';
import 'wa_emoji_panel.dart';
import 'wa_in_app_camera.dart';
import 'wa_media_preview.dart';

enum WaComposerMode { idle, holding, locked }

/// WhatsApp-style group chat composer (mic + pill + panels).
class WhatsAppChatComposer extends StatefulWidget {
  const WhatsAppChatComposer({
    required this.controller,
    required this.groupId,
    required this.focusNode,
    required this.onSendText,
    required this.onSendMedia,
    required this.onSendSticker,
    required this.onSendCustomSticker,
    required this.onSendVoice,
    required this.voiceCapture,
    required this.currentUserId,
    required this.currentUserName,
    this.stickerStore,
    this.userStickerStore,
    this.hintText,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String groupId;
  final VoidCallback onSendText;
  final Future<void> Function({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  })
  onSendMedia;
  final Future<void> Function(String stickerKey) onSendSticker;
  final Future<void> Function({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required String stickerCreatorId,
    required String stickerCreatorName,
  })
  onSendCustomSticker;
  final Future<void> Function(VoiceClip clip) onSendVoice;
  final VoiceCapture voiceCapture;
  final String currentUserId;
  final String currentUserName;
  final StickerStore? stickerStore;
  final UserStickerStore? userStickerStore;
  final String? hintText;

  @override
  State<WhatsAppChatComposer> createState() => _WhatsAppChatComposerState();
}

class _WhatsAppChatComposerState extends State<WhatsAppChatComposer>
    with TickerProviderStateMixin {
  static const _tabPrefKey = 'pubget.chat.emoji_panel.tab';

  var _hasText = false;
  var _panelOpen = false;
  var _mode = WaComposerMode.idle;
  var _slideCancel = false;
  var _lockedPaused = false;
  var _previewPlaying = false;
  var _cancelProgress = 0.0; // 0..1 while sliding to cancel
  Duration _recordElapsed = Duration.zero;
  Offset? _pointerStart;
  Timer? _tick;
  Timer? _armHoldTimer;
  int? _activePointer;
  StreamSubscription<double>? _ampSub;
  final _levels = List<double>.filled(30, 0.18);
  AudioPlayer? _previewPlayer;
  /// True while [voiceCapture.start] is in flight after long-press arm.
  var _holdStarting = false;
  var _finishAfterStart = false;
  var _cancelAfterStart = false;
  var _sending = false;

  late final AnimationController _micSendFlip;
  late final AnimationController _cameraFade;
  late final AnimationController _pulse;
  late final AnimationController _trashBurst;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_onText);
    _micSendFlip = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _cameraFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      value: _hasText ? 0 : 1,
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _trashBurst = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    if (_hasText) _micSendFlip.value = 1;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    _tick?.cancel();
    _armHoldTimer?.cancel();
    if (_activePointer != null) {
      _detachPointerRoute(_activePointer!);
      _activePointer = null;
    }
    unawaited(_ampSub?.cancel());
    unawaited(_previewPlayer?.dispose());
    _micSendFlip.dispose();
    _cameraFade.dispose();
    _pulse.dispose();
    _trashBurst.dispose();
    super.dispose();
  }

  void _onText() {
    final next = widget.controller.text.trim().isNotEmpty;
    if (next == _hasText) return;
    setState(() => _hasText = next);
    if (next) {
      _cameraFade.reverse();
      _micSendFlip.forward();
    } else {
      _cameraFade.forward();
      _micSendFlip.reverse();
    }
  }

  Future<void> _togglePanel() async {
    if (_panelOpen) {
      setState(() => _panelOpen = false);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      if (!mounted) return;
      widget.focusNode.requestFocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.show');
      return;
    }
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    widget.focusNode.unfocus();
    // Keep selection; reopen focus soft without keyboard when panel closes.
    setState(() => _panelOpen = true);
  }

  Future<void> _closePanelToKeyboard() async {
    if (!_panelOpen) return;
    setState(() => _panelOpen = false);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    if (!mounted) return;
    widget.focusNode.requestFocus();
  }

  Future<void> _openAttach() async {
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    if (!mounted) return;
    setState(() => _panelOpen = false);
    await WaAttachmentSheet.show(
      context,
      groupId: widget.groupId,
      onCamera: () {
        Navigator.of(context).pop();
        unawaited(_openCamera());
      },
      onGallery: () {
        Navigator.of(context).pop();
        unawaited(_openGalleryFlow());
      },
      onGames: () {
        // Sheet opens nested games sheet itself.
      },
      onCreateEvent: () {
        Navigator.of(context).pop();
        // Navigation handled inside sheet.
      },
    );
  }

  Future<void> _openCamera() async {
    final result = await WaInAppCameraPage.open(context);
    if (result == null || !mounted) return;
    await _previewAndSend(result);
  }

  Future<void> _openGalleryFlow() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty || !mounted) {
      // Allow video via single pick if multi returned empty after cancel.
      return;
    }
    for (final file in files.take(30)) {
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      final ext = file.name.split('.').last.toLowerCase();
      final contentType = ext == 'png'
          ? 'image/png'
          : ext == 'gif'
          ? 'image/gif'
          : 'image/jpeg';
      final confirmed = await WaMediaPreviewPage.open(
        context,
        bytes: bytes,
        fileName: file.name,
        contentType: contentType,
        isVideo: false,
      );
      if (confirmed == true) {
        await widget.onSendMedia(
          bytes: bytes,
          fileName: file.name,
          contentType: contentType,
        );
      }
    }
  }

  Future<void> _previewAndSend(WaCapturedMedia media) async {
    final confirmed = await WaMediaPreviewPage.open(
      context,
      bytes: media.bytes,
      fileName: media.fileName,
      contentType: media.contentType,
      isVideo: media.isVideo,
    );
    if (confirmed == true && mounted) {
      await widget.onSendMedia(
        bytes: media.bytes,
        fileName: media.fileName,
        contentType: media.contentType,
      );
    }
  }

  Future<void> _startHold(Offset global) async {
    if (_hasText || _mode != WaComposerMode.idle || _holdStarting) return;
    _holdStarting = true;
    _finishAfterStart = false;
    _cancelAfterStart = false;
    HapticFeedback.lightImpact();
    try {
      await widget.voiceCapture.start();
    } catch (_) {
      _holdStarting = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'يلزم السماح بالوصول إلى الميكروفون لتسجيل رسالة صوتية.',
          ),
        ),
      );
      return;
    }
    if (!mounted) {
      _holdStarting = false;
      try {
        await widget.voiceCapture.cancel();
      } catch (_) {}
      return;
    }
    if (_cancelAfterStart) {
      _holdStarting = false;
      _cancelAfterStart = false;
      _finishAfterStart = false;
      await _cancelRecord();
      return;
    }
    _pointerStart = global;
    _recordElapsed = Duration.zero;
    _slideCancel = false;
    _cancelProgress = 0;
    _lockedPaused = false;
    _previewPlaying = false;
    _tick?.cancel();
    await _ampSub?.cancel();
    for (var i = 0; i < _levels.length; i++) {
      _levels[i] = 0.18;
    }
    _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted || _lockedPaused) return;
      setState(() {
        _recordElapsed += const Duration(milliseconds: 200);
        if (_recordElapsed.inSeconds >= kChatAudioMaxDurationSeconds) {
          unawaited(_finishAndSend());
        }
      });
    });
    _ampSub = widget.voiceCapture.amplitudeStream.listen((level) {
      if (!mounted || _lockedPaused) return;
      setState(() {
        for (var i = 0; i < _levels.length - 1; i++) {
          _levels[i] = _levels[i + 1];
        }
        _levels[_levels.length - 1] = level.clamp(0.08, 1.0);
      });
    });
    setState(() => _mode = WaComposerMode.holding);
    _holdStarting = false;
    unawaited(_pulse.repeat(reverse: true));
    if (_finishAfterStart) {
      _finishAfterStart = false;
      await _finishAndSend();
    }
  }

  Future<void> _updateHold(Offset global) async {
    if (_mode != WaComposerMode.holding || _pointerStart == null) return;
    final dx = global.dx - _pointerStart!.dx;
    final dy = global.dy - _pointerStart!.dy;
    // Composer is forced RTL: swipe toward visual left (positive dx in RTL).
    final cancelDelta = dx;
    final locking = -dy > 80;
    final cancelling = cancelDelta > 80;
    final progress = (cancelDelta / 120).clamp(0.0, 1.0);
    if (locking) {
      HapticFeedback.mediumImpact();
      setState(() {
        _mode = WaComposerMode.locked;
        _slideCancel = false;
        _cancelProgress = 0;
      });
      return;
    }
    if (cancelling != _slideCancel || progress != _cancelProgress) {
      setState(() {
        _slideCancel = cancelling;
        _cancelProgress = progress;
      });
    }
  }

  Future<void> _endHold() async {
    if (_holdStarting) {
      if (_slideCancel || _cancelAfterStart) {
        _cancelAfterStart = true;
        _finishAfterStart = false;
      } else {
        _finishAfterStart = true;
        _cancelAfterStart = false;
      }
      return;
    }
    if (_mode == WaComposerMode.locked) return;
    if (_mode != WaComposerMode.holding) return;
    if (_slideCancel) {
      await _cancelRecord(animated: true);
      return;
    }
    await _finishAndSend();
  }

  Future<void> _cancelRecord({bool animated = false}) async {
    _tick?.cancel();
    final sub = _ampSub;
    _ampSub = null;
    unawaited(sub?.cancel());
    try {
      await widget.voiceCapture.cancel();
    } catch (_) {
      try {
        await widget.voiceCapture.stop();
      } catch (_) {}
    }
    if (!mounted) return;
    if (_pulse.isAnimating) _pulse.stop();
    _pulse.reset();
    await _stopPreview();
    if (animated) {
      HapticFeedback.heavyImpact();
      unawaited(
        _trashBurst.forward(from: 0).then((_) {
          if (mounted) _trashBurst.reset();
        }),
      );
    }
    setState(() {
      _mode = WaComposerMode.idle;
      _slideCancel = false;
      _cancelProgress = 0;
      _lockedPaused = false;
      _previewPlaying = false;
      _recordElapsed = Duration.zero;
    });
  }

  Future<void> _finishAndSend() async {
    if (_sending || _mode == WaComposerMode.idle) return;
    _sending = true;
    _tick?.cancel();
    final sub = _ampSub;
    _ampSub = null;
    unawaited(sub?.cancel());

    // Stop capture before UI teardown so callers/tests observe `stop` even if
    // the widget is disposed mid-await.
    VoiceClip? clip;
    try {
      clip = await widget.voiceCapture.stop();
    } catch (_) {}

    if (!mounted) {
      _sending = false;
      return;
    }
    if (_pulse.isAnimating) _pulse.stop();
    _pulse.reset();
    await _stopPreview();
    if (!mounted) {
      _sending = false;
      return;
    }
    setState(() {
      _mode = WaComposerMode.idle;
      _slideCancel = false;
      _cancelProgress = 0;
      _lockedPaused = false;
      _previewPlaying = false;
      _recordElapsed = Duration.zero;
    });
    _sending = false;
    if (clip == null) return;
    if (clip.exceedsLimits) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرسائل الصوتية محدودة بـ 60 ثانية و 10 ميجابايت.'),
        ),
      );
      return;
    }
    await widget.onSendVoice(clip);
  }

  Future<void> _toggleLockedPause() async {
    if (_mode != WaComposerMode.locked) return;
    if (_lockedPaused) {
      await _stopPreview();
      try {
        await widget.voiceCapture.resume();
      } catch (_) {}
      if (!mounted) return;
      setState(() => _lockedPaused = false);
      return;
    }
    try {
      await widget.voiceCapture.pause();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _lockedPaused = true);
  }

  Future<void> _togglePreviewPlayback() async {
    if (!_lockedPaused) return;
    final path = widget.voiceCapture.recordingPath;
    if (path == null || path.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('المعاينة غير متاحة على هذا الجهاز.')),
      );
      return;
    }
    _previewPlayer ??= AudioPlayer();
    if (_previewPlaying) {
      await _stopPreview();
      return;
    }
    try {
      await _previewPlayer!.stop();
      await _previewPlayer!.play(DeviceFileSource(path));
      if (!mounted) return;
      setState(() => _previewPlaying = true);
      _previewPlayer!.onPlayerComplete.listen((_) {
        if (!mounted) return;
        setState(() => _previewPlaying = false);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تشغيل المعاينة.')),
      );
    }
  }

  Future<void> _stopPreview() async {
    try {
      await _previewPlayer?.stop();
    } catch (_) {}
    if (_previewPlaying && mounted) {
      setState(() => _previewPlaying = false);
    } else {
      _previewPlaying = false;
    }
  }

  String _formatElapsed(Duration d) {
    final total = d.inSeconds.clamp(0, kChatAudioMaxDurationSeconds);
    final m = (total ~/ 60).toString().padLeft(1, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final dark = WaColors.isDark(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: Directionality(
              // Spec: Arabic/RTL layout — mic on the visual start side.
              textDirection: TextDirection.rtl,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  _buildMicOrSend(dark),
                  const SizedBox(width: 8),
                  Expanded(child: _buildPillOrRecording(dark)),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.fastOutSlowIn,
          child: _panelOpen
              ? WaEmojiPanel(
                  userStickerStore: widget.userStickerStore,
                  currentUserId: widget.currentUserId,
                  currentUserName: widget.currentUserName,
                  onInsertEmoji: (emoji) {
                    final value = widget.controller.text;
                    final selection = widget.controller.selection;
                    final start = selection.isValid
                        ? selection.start
                        : value.length;
                    final end = selection.isValid ? selection.end : value.length;
                    final next = value.replaceRange(start, end, emoji);
                    widget.controller.value = TextEditingValue(
                      text: next,
                      selection: TextSelection.collapsed(
                        offset: start + emoji.length,
                      ),
                    );
                  },
                  onSendCustomSticker:
                      ({
                        required bytes,
                        required fileName,
                        required contentType,
                        required stickerCreatorId,
                        required stickerCreatorName,
                      }) async {
                        await widget.onSendCustomSticker(
                          bytes: bytes,
                          fileName: fileName,
                          contentType: contentType,
                          stickerCreatorId: stickerCreatorId,
                          stickerCreatorName: stickerCreatorName,
                        );
                        if (mounted) setState(() => _panelOpen = false);
                      },
                  onClose: _closePanelToKeyboard,
                  tabPrefKey: _tabPrefKey,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  void _attachPointerRoute(int pointer) {
    if (_activePointer != null && _activePointer != pointer) {
      _detachPointerRoute(_activePointer!);
    }
    _activePointer = pointer;
    GestureBinding.instance.pointerRouter.addRoute(pointer, _onGlobalPointer);
  }

  void _detachPointerRoute(int pointer) {
    GestureBinding.instance.pointerRouter.removeRoute(pointer, _onGlobalPointer);
    if (_activePointer == pointer) {
      _activePointer = null;
    }
  }

  void _onGlobalPointer(PointerEvent event) {
    if (_activePointer != null && event.pointer != _activePointer) return;
    if (event is PointerMoveEvent) {
      if (_mode == WaComposerMode.holding) {
        unawaited(_updateHold(event.position));
      }
      return;
    }
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _armHoldTimer?.cancel();
      _armHoldTimer = null;
      _detachPointerRoute(event.pointer);
      if (event is PointerCancelEvent) {
        if (_holdStarting) {
          _cancelAfterStart = true;
          _finishAfterStart = false;
          return;
        }
        if (_mode == WaComposerMode.holding) {
          unawaited(_cancelRecord());
        }
        return;
      }
      // Pointer up: finish/cancel hold, or ignore when already locked.
      unawaited(_endHold());
    }
  }

  Widget _buildMicOrSend(bool dark) {
    final green = WaColors.send(context);
    final isSend = _hasText && _mode == WaComposerMode.idle;
    final holding = _mode == WaComposerMode.holding;
    final locked = _mode == WaComposerMode.locked;
    final size = holding ? 60.0 : 48.0;
    final bg = holding ? WaColors.recordRed : green;

    final visual = AnimatedScale(
      scale: holding ? 1.05 + (_cancelProgress * 0.08) : 1,
      duration: const Duration(milliseconds: 120),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: Listenable.merge(<Listenable>[
            _micSendFlip,
            _pulse,
            _trashBurst,
          ]),
          builder: (context, _) {
            final t = _micSendFlip.value;
            final IconData icon;
            if (isSend || locked) {
              icon = Icons.send_rounded;
            } else if (holding && _slideCancel) {
              icon = Icons.delete;
            } else if (holding && _cancelProgress > 0.55) {
              icon = Icons.lock;
            } else {
              icon = Icons.mic;
            }
            return Transform.rotate(
              angle: t * math.pi + (_trashBurst.value * 0.35),
              child: Transform.scale(
                scale: holding
                    ? 0.9 +
                          (_pulse.value * 0.1) +
                          (_trashBurst.value * 0.2)
                    : 1,
                child: Icon(icon, color: Colors.white, size: holding ? 28 : 24),
              ),
            );
          },
        ),
      ),
    );

    if (isSend || locked) {
      return GestureDetector(
        key: const Key('composer-mic'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (isSend) {
            HapticFeedback.selectionClick();
            widget.onSendText();
            return;
          }
          unawaited(_finishAndSend());
        },
        child: visual,
      );
    }

    return Listener(
      key: const Key('composer-mic'),
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        if (_mode != WaComposerMode.idle || _hasText || _holdStarting) return;
        _pointerStart = event.position;
        _attachPointerRoute(event.pointer);
        _armHoldTimer?.cancel();
        _armHoldTimer = Timer(const Duration(milliseconds: 120), () {
          if (!mounted) return;
          if (_mode != WaComposerMode.idle || _hasText) return;
          unawaited(_startHold(event.position));
        });
      },
      child: visual,
    );
  }

  Widget _buildPillOrRecording(bool dark) {
    if (_mode == WaComposerMode.holding) {
      return _holdingBar(dark);
    }
    if (_mode == WaComposerMode.locked) {
      return _lockedBar(dark);
    }
    return _idlePill(dark);
  }

  Widget _idlePill(bool dark) {
    final hint = widget.hintText ?? 'مراسلة';
    return Container(
      constraints: const BoxConstraints(minHeight: 46),
      decoration: BoxDecoration(
        color: WaColors.pill(context),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          // Trailing in RTL visual = emoji (right in the Arabic screenshot).
          IconButton(
            key: const Key('composer-emoji'),
            padding: const EdgeInsets.all(10),
            constraints: const BoxConstraints(minWidth: 46, minHeight: 46),
            onPressed: _togglePanel,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(scale: anim, child: child),
              ),
              child: Icon(
                _panelOpen ? Icons.keyboard_outlined : Icons.emoji_emotions,
                key: ValueKey<bool>(_panelOpen),
                size: 26,
                color: WaColors.iconMuted,
              ),
            ),
          ),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: Theme(
                data: Theme.of(context).copyWith(
                  inputDecorationTheme: const InputDecorationTheme(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                  ),
                ),
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  style: TextStyle(
                    fontSize: 16,
                    color: WaColors.fieldText(context),
                  ),
                  cursorColor: WaColors.cursorGreen,
                  cursorWidth: 2,
                  onTap: () {
                    if (_panelOpen) setState(() => _panelOpen = false);
                  },
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    hintText: hint,
                    hintStyle: const TextStyle(
                      fontSize: 16,
                      color: WaColors.iconMuted,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            key: const Key('composer-attach'),
            tooltip: 'Attachments',
            onPressed: _openAttach,
            icon: Transform.rotate(
              angle: -math.pi / 4,
              child: const Icon(
                Icons.attach_file,
                size: 26,
                color: WaColors.iconMuted,
              ),
            ),
          ),
          FadeTransition(
            opacity: _cameraFade,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.8, end: 1).animate(_cameraFade),
              child: IgnorePointer(
                ignoring: _hasText,
                child: IconButton(
                  key: const Key('composer-camera'),
                  onPressed: _openCamera,
                  icon: const Icon(
                    Icons.photo_camera_outlined,
                    size: 26,
                    color: WaColors.iconMuted,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _holdingBar(bool dark) {
    return Transform.translate(
      offset: Offset(_cancelProgress * 28, 0),
      child: AnimatedContainer(
        key: const Key('composer-voice-holding'),
        duration: const Duration(milliseconds: 120),
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _slideCancel
              ? const Color(0xFF3A2025)
              : WaColors.darkPill,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: <Widget>[
            FadeTransition(
              opacity: _pulse,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: WaColors.pulseRed,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              key: const Key('composer-voice-timer'),
              _formatElapsed(_recordElapsed),
              style: const TextStyle(fontSize: 15, color: WaColors.iconMuted),
            ),
            const SizedBox(width: 10),
            Expanded(child: _waveform()),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 120),
              child: _slideCancel
                  ? const Row(
                      key: ValueKey('cancel'),
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.delete, color: WaColors.recordRed, size: 18),
                        SizedBox(width: 4),
                        Text(
                          'إلغاء',
                          style: TextStyle(
                            fontSize: 14,
                            color: WaColors.recordRed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : const Row(
                      key: ValueKey('hint'),
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.chevron_left,
                          color: WaColors.iconMuted,
                          size: 18,
                        ),
                        SizedBox(width: 2),
                        Text(
                          'اسحب للإلغاء',
                          style: TextStyle(
                            fontSize: 13,
                            color: WaColors.iconMuted,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.lock_open, color: WaColors.iconMuted, size: 18),
            const Icon(
              Icons.keyboard_arrow_up,
              color: WaColors.iconMuted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _lockedBar(bool dark) {
    const btnConstraints = BoxConstraints(minWidth: 36, minHeight: 36);
    return Container(
      key: const Key('composer-voice-locked'),
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: WaColors.darkPill,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Row(
              children: <Widget>[
                IconButton(
                  key: const Key('composer-voice-delete'),
                  tooltip: 'Delete',
                  padding: EdgeInsets.zero,
                  constraints: btnConstraints,
                  onPressed: () => unawaited(_cancelRecord(animated: true)),
                  icon: const Icon(Icons.delete, color: WaColors.recordRed),
                ),
                IconButton(
                  key: const Key('composer-voice-pause'),
                  tooltip: _lockedPaused ? 'Resume' : 'Pause',
                  padding: EdgeInsets.zero,
                  constraints: btnConstraints,
                  onPressed: () => unawaited(_toggleLockedPause()),
                  icon: Icon(
                    _lockedPaused ? Icons.mic : Icons.pause,
                    color: WaColors.iconMuted,
                  ),
                ),
                if (_lockedPaused)
                  IconButton(
                    key: const Key('composer-voice-preview'),
                    tooltip: 'Preview',
                    padding: EdgeInsets.zero,
                    constraints: btnConstraints,
                    onPressed: () => unawaited(_togglePreviewPlayback()),
                    icon: Icon(
                      _previewPlaying ? Icons.stop : Icons.play_arrow,
                      color: WaColors.cursorGreen,
                    ),
                  ),
                Expanded(child: _waveform()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    key: const Key('composer-voice-timer'),
                    _formatElapsed(_recordElapsed),
                    style: const TextStyle(
                      fontSize: 15,
                      color: WaColors.iconMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            key: const Key('composer-voice-send'),
            behavior: HitTestBehavior.opaque,
            onTap: () => unawaited(_finishAndSend()),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.send_rounded,
                color: WaColors.send(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _waveform() {
    return SizedBox(
      height: 30,
      child: Row(
        children: <Widget>[
          for (final level in _levels)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0.8),
                child: Align(
                  alignment: Alignment.center,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 70),
                    height: 6 + level * 22,
                    decoration: BoxDecoration(
                      color: _slideCancel
                          ? WaColors.recordRed.withValues(alpha: 0.85)
                          : WaColors.cursorGreen,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pref helper used by the emoji panel.
Future<int> loadWaPanelTab(String key) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt(key) ?? 0;
}

Future<void> saveWaPanelTab(String key, int index) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(key, index);
}
