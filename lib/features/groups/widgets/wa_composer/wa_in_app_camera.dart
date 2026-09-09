import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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

class WaInAppCameraPage extends StatefulWidget {
  const WaInAppCameraPage({super.key});

  static Future<WaCapturedMedia?> open(BuildContext context) {
    return Navigator.of(context).push<WaCapturedMedia>(
      MaterialPageRoute<WaCapturedMedia>(
        fullscreenDialog: true,
        builder: (_) => const WaInAppCameraPage(),
      ),
    );
  }

  @override
  State<WaInAppCameraPage> createState() => _WaInAppCameraPageState();
}

class _WaInAppCameraPageState extends State<WaInAppCameraPage> {
  CameraController? _controller;
  var _ready = false;
  var _usingFront = false;
  var _flashOn = false;
  var _recording = false;
  DateTime? _recordStarted;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaitedInit();
  }

  Future<void> unawaitedInit() async {
    if (kIsWeb) {
      setState(() => _error = 'fallback');
      return;
    }
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'fallback');
        return;
      }
      final cam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        cam,
        ResolutionPreset.high,
        enableAudio: true,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _ready = true;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'fallback');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _flip() async {
    final cameras = await availableCameras();
    if (cameras.length < 2) return;
    final next = cameras.firstWhere(
      (c) =>
          c.lensDirection ==
          (_usingFront
              ? CameraLensDirection.back
              : CameraLensDirection.front),
      orElse: () => cameras.first,
    );
    await _controller?.dispose();
    final controller = CameraController(
      next,
      ResolutionPreset.high,
      enableAudio: true,
    );
    await controller.initialize();
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _controller = controller;
      _usingFront = !_usingFront;
      _ready = true;
    });
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    _flashOn = !_flashOn;
    await controller.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
    setState(() {});
  }

  Future<void> _shutterTap() async {
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      Navigator.pop(
        context,
        WaCapturedMedia(
          bytes: bytes,
          fileName: 'capture.jpg',
          contentType: 'image/jpeg',
          isVideo: false,
        ),
      );
      return;
    }
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    Navigator.pop(
      context,
      WaCapturedMedia(
        bytes: bytes,
        fileName: picked.name,
        contentType: 'image/jpeg',
        isVideo: false,
      ),
    );
  }

  Future<void> _shutterLongStart() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      final picked = await ImagePicker().pickVideo(source: ImageSource.camera);
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      Navigator.pop(
        context,
        WaCapturedMedia(
          bytes: bytes,
          fileName: picked.name,
          contentType: 'video/mp4',
          isVideo: true,
        ),
      );
      return;
    }
    await controller.startVideoRecording();
    setState(() {
      _recording = true;
      _recordStarted = DateTime.now();
    });
  }

  Future<void> _shutterLongEnd() async {
    final controller = _controller;
    if (!_recording || controller == null) return;
    final file = await controller.stopVideoRecording();
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    Navigator.pop(
      context,
      WaCapturedMedia(
        bytes: bytes,
        fileName: 'capture.mp4',
        contentType: 'video/mp4',
        isVideo: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = _recordStarted == null
        ? null
        : DateTime.now().difference(_recordStarted!);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (_ready && _controller != null)
              CameraPreview(_controller!)
            else
              const ColoredBox(color: Colors.black),
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                children: <Widget>[
                  IconButton(
                    onPressed: _flip,
                    icon: const Icon(Icons.cameraswitch, color: Colors.white),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _toggleFlash,
                    icon: Icon(
                      _flashOn ? Icons.flash_on : Icons.flash_off,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white, size: 24),
                  ),
                ],
              ),
            ),
            if (_recording && elapsed != null)
              Positioned(
                top: 64,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    _format(elapsed),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Row(
                children: <Widget>[
                  IconButton(
                    onPressed: _flip,
                    icon: const Icon(Icons.cameraswitch, color: Colors.white),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _shutterTap,
                    onLongPressStart: (_) => _shutterLongStart(),
                    onLongPressEnd: (_) => _shutterLongEnd(),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _recording ? WaColors.recordRed : Colors.white,
                          width: 4,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: _recording ? WaColors.recordRed : Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white54),
                      color: Colors.white24,
                    ),
                    child: const Icon(
                      Icons.photo,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            if (_error == 'fallback' && !_ready)
              const Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'اضغط الغالق لفتح الكاميرا',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
