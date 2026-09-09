import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/sticker_store.dart';
import '../../data/user_sticker_store.dart';
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
    required this.onSendVoice,
    required this.voiceCapture,
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
  final Future<void> Function(VoiceClip clip) onSendVoice;
  final VoiceCapture voiceCapture;
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
  Duration _recordElapsed = Duration.zero;
  Offset? _pointerStart;
  Timer? _tick;
  Timer? _waveTick;
  final _levels = List<double>.filled(30, 0.18);
  final _random = math.Random();

  late final AnimationController _micSendFlip;
  late final AnimationController _cameraFade;
  late final AnimationController _pulse;

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
    if (_hasText) _micSendFlip.value = 1;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    _tick?.cancel();
    _waveTick?.cancel();
    _micSendFlip.dispose();
    _cameraFade.dispose();
    _pulse.dispose();
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
    if (_hasText || _mode != WaComposerMode.idle) return;
    HapticFeedback.lightImpact();
    try {
      await widget.voiceCapture.start();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required.')),
      );
      return;
    }
    _pointerStart = global;
    _recordElapsed = Duration.zero;
    _slideCancel = false;
    _tick?.cancel();
    _waveTick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      setState(() => _recordElapsed += const Duration(milliseconds: 200));
    });
    _waveTick = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!mounted || _lockedPaused) return;
      setState(() {
        for (var i = 0; i < _levels.length; i++) {
          _levels[i] = 0.12 + _random.nextDouble() * 0.88;
        }
      });
    });
    setState(() => _mode = WaComposerMode.holding);
    unawaited(_pulse.repeat(reverse: true));
  }

  Future<void> _updateHold(Offset global) async {
    if (_mode != WaComposerMode.holding || _pointerStart == null) return;
    final dx = global.dx - _pointerStart!.dx;
    final dy = global.dy - _pointerStart!.dy;
    // RTL: swipe toward trailing (visual left in LTR is cancel; in RTL reverse).
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final cancelDelta = rtl ? dx : -dx;
    final locking = -dy > 80;
    final cancelling = cancelDelta > 120;
    if (locking) {
      setState(() {
        _mode = WaComposerMode.locked;
        _slideCancel = false;
      });
      return;
    }
    if (cancelling != _slideCancel) {
      setState(() => _slideCancel = cancelling);
    }
  }

  Future<void> _endHold() async {
    if (_mode == WaComposerMode.locked) return;
    if (_mode != WaComposerMode.holding) return;
    if (_slideCancel) {
      await _cancelRecord();
      return;
    }
    await _finishAndSend();
  }

  Future<void> _cancelRecord() async {
    _tick?.cancel();
    _waveTick?.cancel();
    _pulse.stop();
    _pulse.value = 0;
    try {
      await widget.voiceCapture.stop();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _mode = WaComposerMode.idle;
      _slideCancel = false;
      _lockedPaused = false;
      _recordElapsed = Duration.zero;
    });
  }

  Future<void> _finishAndSend() async {
    _tick?.cancel();
    _waveTick?.cancel();
    _pulse.stop();
    _pulse.value = 0;
    VoiceClip? clip;
    try {
      clip = await widget.voiceCapture.stop();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _mode = WaComposerMode.idle;
      _slideCancel = false;
      _lockedPaused = false;
      _recordElapsed = Duration.zero;
    });
    if (clip == null) return;
    await widget.onSendVoice(clip);
  }

  String _formatElapsed(Duration d) {
    final total = d.inSeconds;
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
                      }) async {
                        await widget.onSendMedia(
                          bytes: bytes,
                          fileName: fileName,
                          contentType: contentType,
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

    Widget _buildMicOrSend(bool dark) {
    final green = WaColors.send(context);
    final isSend = _hasText && _mode == WaComposerMode.idle;
    final holding = _mode == WaComposerMode.holding;
    final size = holding ? 60.0 : 48.0;
    final bg = holding ? WaColors.recordRed : green;

    return Tooltip(
      message: isSend || _mode == WaComposerMode.locked
          ? 'Send message'
          : 'Voice message',
      child: GestureDetector(
      onTap: () {
        if (isSend) {
          HapticFeedback.selectionClick();
          widget.onSendText();
          return;
        }
        if (_mode == WaComposerMode.locked) {
          unawaited(_finishAndSend());
        }
      },
      onLongPressStart: (details) {
        if (!isSend) unawaited(_startHold(details.globalPosition));
      },
      onLongPressMoveUpdate: (details) {
        unawaited(_updateHold(details.globalPosition));
      },
      onLongPressEnd: (_) {
        unawaited(_endHold());
      },
      onTapDown: (_) {
        if (!isSend && _mode == WaComposerMode.idle) {
          HapticFeedback.lightImpact();
        }
      },
      child: AnimatedScale(
        scale: holding ? 1.05 : 1,
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
            animation: Listenable.merge(<Listenable>[_micSendFlip, _pulse]),
            builder: (context, _) {
              final t = _micSendFlip.value;
              final icon = isSend
                  ? Icons.send_rounded
                  : (_mode == WaComposerMode.locked
                        ? Icons.send_rounded
                        : Icons.mic);
              return Transform.rotate(
                angle: t * math.pi,
                child: Transform.scale(
                  scale: holding ? 0.9 + (_pulse.value * 0.1) : 1,
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
              );
            },
          ),
        ),
      ),
      ),
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
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: WaColors.darkPill,
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
            _formatElapsed(_recordElapsed),
            style: const TextStyle(fontSize: 15, color: WaColors.iconMuted),
          ),
          const Spacer(),
          Icon(
            _slideCancel ? Icons.delete_outline : Icons.chevron_left,
            color: WaColors.iconMuted,
            size: 18,
          ),
          const SizedBox(width: 4),
          Text(
            _slideCancel ? 'إلغاء' : 'اسحب للإلغاء',
            style: const TextStyle(fontSize: 14, color: WaColors.iconMuted),
          ),
          const Spacer(),
          const Icon(Icons.lock_open, color: WaColors.iconMuted, size: 18),
          const Icon(Icons.keyboard_arrow_up, color: WaColors.iconMuted, size: 18),
        ],
      ),
    );
  }

  Widget _lockedBar(bool dark) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: WaColors.darkPill,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: _cancelRecord,
            icon: const Icon(Icons.delete, color: WaColors.recordRed),
          ),
          IconButton(
            onPressed: () => setState(() => _lockedPaused = !_lockedPaused),
            icon: Icon(
              _lockedPaused ? Icons.play_arrow : Icons.pause,
              color: WaColors.iconMuted,
            ),
          ),
          Expanded(
            child: Row(
              children: <Widget>[
                for (final level in _levels)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Align(
                        alignment: Alignment.center,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 80),
                          height: 8 + level * 22,
                          decoration: BoxDecoration(
                            color: WaColors.cursorGreen,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              _formatElapsed(_recordElapsed),
              style: const TextStyle(fontSize: 15, color: WaColors.iconMuted),
            ),
          ),
          IconButton(
            onPressed: _finishAndSend,
            icon: Icon(Icons.send_rounded, color: WaColors.send(context)),
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
