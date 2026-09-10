import 'dart:async';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import 'wa_colors.dart';

final class WaCapturedMedia {
  const WaCapturedMedia({
    required this.bytes,
    required this.fileName,
    required this.contentType,
    required this.isVideo,
  });

  final Uint8List bytes;
  final String fileName;
  final String contentType;
  final bool isVideo;
}

enum _FlashCycle { auto, on, off }

enum _CaptureQuality { max, high }

/// Back-compat entry used by the chat composer.
class WaInAppCameraPage {
  const WaInAppCameraPage._();

  static Future<WaCapturedMedia?> open(BuildContext context) {
    return Navigator.of(context).push<WaCapturedMedia>(
      MaterialPageRoute<WaCapturedMedia>(
        fullscreenDialog: true,
        builder: (_) => const CameraScreen(),
      ),
    );
  }
}

/// Premium in-app camera — correct aspect preview, glass UI, focus/zoom.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription> _cameras = const <CameraDescription>[];
  var _ready = false;
  var _usingFront = false;
  var _busy = false;
  var _recording = false;
  var _controlsOpen = false;
  var _flash = _FlashCycle.auto;
  var _quality = _CaptureQuality.max;
  var _timerSecs = 0;
  var _zoom = 1.0;
  var _baseZoom = 1.0;
  var _minZoom = 1.0;
  var _maxZoom = 1.0;
  Offset? _focusPoint;
  DateTime? _recordStarted;
  String? _error;
  Uint8List? _galleryThumb;
  Uint8List? _capturedBytes;
  String? _capturedName;
  String? _capturedType;
  var _capturedIsVideo = false;
  Timer? _countdownTimer;
  Timer? _recordingTick;
  var _countdown = 0;

  late final AnimationController _focusPulse;
  late final AnimationController _shutterScale;

  @override
  void initState() {
    super.initState();
    _focusPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _shutterScale = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      lowerBound: 0.9,
      upperBound: 1,
      value: 1,
    );
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _recordingTick?.cancel();
    _focusPulse.dispose();
    _shutterScale.dispose();
    unawaited(_controller?.dispose() ?? Future<void>.value());
    super.dispose();
  }

  ResolutionPreset get _preset => _quality == _CaptureQuality.max
      ? ResolutionPreset.max
      : ResolutionPreset.veryHigh;

  Future<void> _bootstrap() async {
    if (kIsWeb) {
      setState(() => _error = 'fallback');
      return;
    }
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _error = 'fallback');
        return;
      }
      final cam = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );
      await _attachCamera(cam, front: false);
    } catch (_) {
      if (mounted) setState(() => _error = 'fallback');
    }
  }

  Future<void> _attachCamera(
    CameraDescription description, {
    required bool front,
  }) async {
    final previous = _controller;
    final controller = CameraController(
      description,
      _preset,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await controller.initialize();
      await controller.setFocusMode(FocusMode.auto);
      await controller.setExposureMode(ExposureMode.auto);
      await _applyFlash(controller);
      final minZ = await controller.getMinZoomLevel();
      final maxZ = await controller.getMaxZoomLevel();
      await previous?.dispose();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _usingFront = front;
        _ready = true;
        _error = null;
        _minZoom = minZ;
        _maxZoom = maxZ;
        _zoom = minZ.clamp(minZ, maxZ);
        _baseZoom = _zoom;
      });
      await controller.setZoomLevel(_zoom);
    } catch (_) {
      await controller.dispose();
      if (mounted) setState(() => _error = 'fallback');
    }
  }

  Future<void> _applyFlash(CameraController controller) async {
    try {
      final mode = switch (_flash) {
        _FlashCycle.auto => FlashMode.auto,
        _FlashCycle.on => FlashMode.always,
        _FlashCycle.off => FlashMode.off,
      };
      await controller.setFlashMode(mode);
    } catch (_) {
      // Front cameras often reject flash modes.
    }
  }

  Future<void> _cycleFlash() async {
    setState(() {
      _flash = switch (_flash) {
        _FlashCycle.auto => _FlashCycle.on,
        _FlashCycle.on => _FlashCycle.off,
        _FlashCycle.off => _FlashCycle.auto,
      };
    });
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      await _applyFlash(controller);
    }
  }

  Future<void> _flip() async {
    if (_cameras.length < 2 || _busy) return;
    final next = _cameras.firstWhere(
      (c) =>
          c.lensDirection ==
          (_usingFront ? CameraLensDirection.back : CameraLensDirection.front),
      orElse: () => _cameras.first,
    );
    HapticFeedback.selectionClick();
    await _attachCamera(next, front: !_usingFront);
  }

  Future<void> _onFocusTap(TapUpDetails details, Size viewSize) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final local = details.localPosition;
    final xp = (local.dx / viewSize.width).clamp(0.0, 1.0);
    final yp = (local.dy / viewSize.height).clamp(0.0, 1.0);
    setState(() => _focusPoint = local);
    _focusPulse
      ..reset()
      ..forward();
    HapticFeedback.selectionClick();
    try {
      await controller.setFocusPoint(Offset(xp, yp));
      await controller.setExposurePoint(Offset(xp, yp));
      await controller.setFocusMode(FocusMode.auto);
      await controller.setExposureMode(ExposureMode.auto);
    } catch (_) {}
  }

  Future<void> _onScaleStart(ScaleStartDetails _) async {
    _baseZoom = _zoom;
  }

  Future<void> _onScaleUpdate(ScaleUpdateDetails details) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (details.pointerCount < 2) return;
    final next = (_baseZoom * details.scale).clamp(_minZoom, _maxZoom);
    if ((next - _zoom).abs() < 0.01) return;
    setState(() => _zoom = next);
    try {
      await controller.setZoomLevel(_zoom);
    } catch (_) {}
  }

  String get _zoomLabel {
    if (_zoom < 1.4) return '1×';
    if (_zoom < 2.4) return '2×';
    return '${_zoom.toStringAsFixed(1)}×';
  }

  Future<void> _openGallery() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
      requestFullMetadata: true,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _galleryThumb = bytes;
      _capturedBytes = bytes;
      _capturedName = picked.name;
      _capturedType = 'image/jpeg';
      _capturedIsVideo = false;
    });
  }

  Future<void> _shutterPressed() async {
    if (_busy) return;
    HapticFeedback.heavyImpact();
    unawaited(_shutterScale.reverse().then((_) => _shutterScale.forward()));
    if (_timerSecs > 0) {
      await _runCountdownThenCapture();
      return;
    }
    await _capturePhoto();
  }

  Future<void> _runCountdownThenCapture() async {
    setState(() => _countdown = _timerSecs);
    final completer = Completer<void>();
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdown <= 1) {
        timer.cancel();
        setState(() => _countdown = 0);
        completer.complete();
        return;
      }
      HapticFeedback.selectionClick();
      setState(() => _countdown -= 1);
    });
    await completer.future;
    if (!mounted) return;
    await _capturePhoto();
  }

  Future<void> _capturePhoto() async {
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      setState(() => _busy = true);
      try {
        final file = await controller.takePicture();
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        setState(() {
          _capturedBytes = bytes;
          _capturedName = 'capture_${DateTime.now().millisecondsSinceEpoch}.jpg';
          _capturedType = 'image/jpeg';
          _capturedIsVideo = false;
          _galleryThumb = bytes;
          _busy = false;
        });
      } catch (_) {
        if (mounted) setState(() => _busy = false);
        await _fallbackPickImage();
      }
      return;
    }
    await _fallbackPickImage();
  }

  Future<void> _fallbackPickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 100,
      requestFullMetadata: true,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _capturedBytes = bytes;
      _capturedName = picked.name;
      _capturedType = 'image/jpeg';
      _capturedIsVideo = false;
      _galleryThumb = bytes;
    });
  }

  Future<void> _shutterLongStart() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      final picked = await ImagePicker().pickVideo(source: ImageSource.camera);
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _capturedBytes = bytes;
        _capturedName = picked.name;
        _capturedType = 'video/mp4';
        _capturedIsVideo = true;
      });
      return;
    }
    if (_recording || _busy) return;
    HapticFeedback.mediumImpact();
    await controller.startVideoRecording();
    _recordingTick?.cancel();
    _recordingTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    setState(() {
      _recording = true;
      _recordStarted = DateTime.now();
    });
  }

  Future<void> _shutterLongEnd() async {
    final controller = _controller;
    if (!_recording || controller == null) return;
    _recordingTick?.cancel();
    _recordingTick = null;
    setState(() => _busy = true);
    try {
      final file = await controller.stopVideoRecording();
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _recording = false;
        _recordStarted = null;
        _capturedBytes = bytes;
        _capturedName = 'capture_${DateTime.now().millisecondsSinceEpoch}.mp4';
        _capturedType = 'video/mp4';
        _capturedIsVideo = true;
        _busy = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _recording = false;
          _recordStarted = null;
          _busy = false;
        });
      }
    }
  }

  void _retake() {
    setState(() {
      _capturedBytes = null;
      _capturedName = null;
      _capturedType = null;
      _capturedIsVideo = false;
    });
  }

  void _sendCapture() {
    final bytes = _capturedBytes;
    if (bytes == null) return;
    Navigator.pop(
      context,
      WaCapturedMedia(
        bytes: bytes,
        fileName: _capturedName ?? 'capture.jpg',
        contentType: _capturedType ?? 'image/jpeg',
        isVideo: _capturedIsVideo,
      ),
    );
  }

  Future<void> _rebuildWithQuality(_CaptureQuality quality) async {
    if (_quality == quality) return;
    setState(() => _quality = quality);
    final current = _controller?.description;
    if (current == null) return;
    await _attachCamera(current, front: _usingFront);
  }

  @override
  Widget build(BuildContext context) {
    if (_capturedBytes != null) {
      return _CaptureReview(
        bytes: _capturedBytes!,
        isVideo: _capturedIsVideo,
        onRetake: _retake,
        onSend: _sendCapture,
      );
    }

    final elapsed = _recordStarted == null
        ? null
        : DateTime.now().difference(_recordStarted!);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _buildPreviewLayer(),
          if (_countdown > 0)
            Center(
              child: Text(
                '$_countdown',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 96,
                  fontWeight: FontWeight.w700,
                  shadows: const <Shadow>[
                    Shadow(color: Colors.black54, blurRadius: 24),
                  ],
                ),
              ),
            ),
          SafeArea(
            child: Column(
              children: <Widget>[
                _TopBar(
                  flash: _flash,
                  onClose: () => Navigator.pop(context),
                  onFlash: _cycleFlash,
                  onFlip: _flip,
                ),
                if (_recording && elapsed != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _RecordingChip(label: _format(elapsed)),
                  ),
                const Spacer(),
                if (_zoom > _minZoom + 0.05)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _GlassChip(label: _zoomLabel),
                  ),
                _BottomBar(
                  galleryThumb: _galleryThumb,
                  recording: _recording,
                  shutterScale: _shutterScale,
                  onGallery: _openGallery,
                  onShutterTap: _shutterPressed,
                  onShutterLongStart: _shutterLongStart,
                  onShutterLongEnd: _shutterLongEnd,
                  onFlip: _flip,
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onVerticalDragEnd: (details) {
                    if ((details.primaryVelocity ?? 0) < -200) {
                      setState(() => _controlsOpen = true);
                    }
                  },
                  child: Column(
                    children: <Widget>[
                      Icon(
                        PhosphorIconsDuotone.caretUp,
                        color: Colors.white.withValues(alpha: 0.55),
                        size: 18,
                      ),
                      Text(
                        'اسحب للأعلى للخيارات',
                        style: GoogleFonts.cairo(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_controlsOpen)
            _ControlsSheet(
              flash: _flash,
              timerSecs: _timerSecs,
              quality: _quality,
              onClose: () => setState(() => _controlsOpen = false),
              onFlash: (value) async {
                setState(() => _flash = value);
                final c = _controller;
                if (c != null && c.value.isInitialized) await _applyFlash(c);
              },
              onTimer: (value) => setState(() => _timerSecs = value),
              onQuality: _rebuildWithQuality,
            ),
          if (_error == 'fallback' && !_ready)
            Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'اضغط الغالق لفتح الكاميرا',
                  style: GoogleFonts.cairo(color: Colors.white70, fontSize: 15),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewLayer() {
    final controller = _controller;
    if (!_ready || controller == null || !controller.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewSize = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => _onFocusTap(details, viewSize),
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _UnstretchedCameraPreview(controller: controller),
              if (_focusPoint != null)
                Positioned(
                  left: _focusPoint!.dx - 28,
                  top: _focusPoint!.dy - 28,
                  child: FadeTransition(
                    opacity: Tween<double>(begin: 1, end: 0).animate(
                      CurvedAnimation(
                        parent: _focusPulse,
                        curve: const Interval(0.45, 1),
                      ),
                    ),
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 1.15, end: 1).animate(
                        CurvedAnimation(
                          parent: _focusPulse,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFFF2C94C),
                            width: 1.6,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

/// Full-bleed camera preview that never stretches the sensor image.
class _UnstretchedCameraPreview extends StatelessWidget {
  const _UnstretchedCameraPreview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize;
    final aspect = controller.value.aspectRatio;

    return ColoredBox(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Prefer native previewSize when available so cover math matches sensor.
          final childWidth = previewSize?.height ?? constraints.maxWidth;
          final childHeight = previewSize == null
              ? childWidth / aspect
              : previewSize.width;

          return ClipRRect(
            borderRadius: BorderRadius.zero,
            child: OverflowBox(
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: childWidth,
                  height: childHeight,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: aspect,
                      child: CameraPreview(controller),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.flash,
    required this.onClose,
    required this.onFlash,
    required this.onFlip,
  });

  final _FlashCycle flash;
  final VoidCallback onClose;
  final VoidCallback onFlash;
  final VoidCallback onFlip;

  IconData get _flashIcon => switch (flash) {
        _FlashCycle.auto => PhosphorIconsDuotone.lightning,
        _FlashCycle.on => PhosphorIconsFill.lightning,
        _FlashCycle.off => PhosphorIconsDuotone.lightningSlash,
      };

  String get _flashLabel => switch (flash) {
        _FlashCycle.auto => 'تلقائي',
        _FlashCycle.on => 'تشغيل',
        _FlashCycle.off => 'إيقاف',
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Row(
              children: <Widget>[
                _GlassIconButton(
                  icon: PhosphorIconsDuotone.x,
                  onTap: onClose,
                ),
                const Spacer(),
                _GlassIconButton(
                  icon: _flashIcon,
                  onTap: onFlash,
                  tooltip: _flashLabel,
                ),
                const SizedBox(width: 8),
                _GlassIconButton(
                  icon: PhosphorIconsDuotone.cameraRotate,
                  onTap: onFlip,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.galleryThumb,
    required this.recording,
    required this.shutterScale,
    required this.onGallery,
    required this.onShutterTap,
    required this.onShutterLongStart,
    required this.onShutterLongEnd,
    required this.onFlip,
  });

  final Uint8List? galleryThumb;
  final bool recording;
  final AnimationController shutterScale;
  final VoidCallback onGallery;
  final VoidCallback onShutterTap;
  final Future<void> Function() onShutterLongStart;
  final Future<void> Function() onShutterLongEnd;
  final VoidCallback onFlip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: <Widget>[
          _GalleryThumb(bytes: galleryThumb, onTap: onGallery),
          const Spacer(),
          GestureDetector(
            onTap: onShutterTap,
            onLongPressStart: (_) => onShutterLongStart(),
            onLongPressEnd: (_) => onShutterLongEnd(),
            child: ScaleTransition(
              scale: shutterScale,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: recording ? WaColors.recordRed : Colors.white,
                    width: 4,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: recording ? WaColors.recordRed : Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          _GlassIconButton(
            size: 48,
            iconSize: 22,
            icon: PhosphorIconsDuotone.cameraRotate,
            onTap: onFlip,
          ),
        ],
      ),
    );
  }
}

class _GalleryThumb extends StatelessWidget {
  const _GalleryThumb({required this.bytes, required this.onTap});

  final Uint8List? bytes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white, width: 2),
          color: Colors.white.withValues(alpha: 0.12),
          image: bytes == null
              ? null
              : DecorationImage(image: MemoryImage(bytes!), fit: BoxFit.cover),
        ),
        child: bytes == null
            ? PhosphorIcon(
                PhosphorIconsDuotone.images,
                color: Colors.white.withValues(alpha: 0.85),
                size: 22,
              )
            : null,
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    this.size = 32,
    this.iconSize = 18,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.black.withValues(alpha: 0.40),
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Center(
                child: PhosphorIcon(
                  icon,
                  size: iconSize,
                  color: Colors.white,
                  duotoneSecondaryOpacity: 0.35,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class _GlassChip extends StatelessWidget {
  const _GlassChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.40),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Text(
            label,
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordingChip extends StatelessWidget {
  const _RecordingChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: WaColors.recordRed.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.circle, size: 8, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlsSheet extends StatelessWidget {
  const _ControlsSheet({
    required this.flash,
    required this.timerSecs,
    required this.quality,
    required this.onClose,
    required this.onFlash,
    required this.onTimer,
    required this.onQuality,
  });

  final _FlashCycle flash;
  final int timerSecs;
  final _CaptureQuality quality;
  final VoidCallback onClose;
  final ValueChanged<_FlashCycle> onFlash;
  final ValueChanged<int> onTimer;
  final ValueChanged<_CaptureQuality> onQuality;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: onClose,
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 200) onClose();
        },
        child: Container(
          color: Colors.black.withValues(alpha: 0.35),
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    12,
                    20,
                    20 + MediaQuery.paddingOf(context).bottom,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E222B).withValues(alpha: 0.92),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 36,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'خيارات التصوير',
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _ControlRow(
                        label: 'الفلاش',
                        child: Wrap(
                          spacing: 8,
                          children: <Widget>[
                            _ChipButton(
                              label: 'تلقائي',
                              selected: flash == _FlashCycle.auto,
                              onTap: () => onFlash(_FlashCycle.auto),
                            ),
                            _ChipButton(
                              label: 'تشغيل',
                              selected: flash == _FlashCycle.on,
                              onTap: () => onFlash(_FlashCycle.on),
                            ),
                            _ChipButton(
                              label: 'إيقاف',
                              selected: flash == _FlashCycle.off,
                              onTap: () => onFlash(_FlashCycle.off),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _ControlRow(
                        label: 'المؤقت',
                        child: Wrap(
                          spacing: 8,
                          children: <Widget>[
                            _ChipButton(
                              label: 'إيقاف',
                              selected: timerSecs == 0,
                              onTap: () => onTimer(0),
                            ),
                            _ChipButton(
                              label: '3ث',
                              selected: timerSecs == 3,
                              onTap: () => onTimer(3),
                            ),
                            _ChipButton(
                              label: '10ث',
                              selected: timerSecs == 10,
                              onTap: () => onTimer(10),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _ControlRow(
                        label: 'الجودة',
                        child: Wrap(
                          spacing: 8,
                          children: <Widget>[
                            _ChipButton(
                              label: 'HD+',
                              selected: quality == _CaptureQuality.max,
                              onTap: () => onQuality(_CaptureQuality.max),
                            ),
                            _ChipButton(
                              label: 'HD',
                              selected: quality == _CaptureQuality.high,
                              onTap: () => onQuality(_CaptureQuality.high),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ).animate().slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
          ),
        ),
      ),
    );
  }
}

class _ControlRow extends StatelessWidget {
  const _ControlRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: GoogleFonts.cairo(
              color: Colors.white.withValues(alpha: 0.7),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _ChipButton extends StatelessWidget {
  const _ChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _CaptureReview extends StatelessWidget {
  const _CaptureReview({
    required this.bytes,
    required this.isVideo,
    required this.onRetake,
    required this.onSend,
  });

  final Uint8List bytes;
  final bool isVideo;
  final VoidCallback onRetake;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Center(
            child: isVideo
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      PhosphorIcon(
                        PhosphorIconsDuotone.videoCamera,
                        size: 64,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'معاينة الفيديو جاهزة للإرسال',
                        style: GoogleFonts.cairo(
                          color: Colors.white70,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      gaplessPlayback: true,
                    ),
                  ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.42),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: onRetake,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                'إعادة',
                                style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: onSend,
                              style: FilledButton.styleFrom(
                                backgroundColor: WaColors.cursorGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                'إرسال',
                                style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
