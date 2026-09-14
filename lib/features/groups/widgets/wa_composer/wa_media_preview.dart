import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'wa_colors.dart';

class WaMediaPreviewPage extends StatefulWidget {
  const WaMediaPreviewPage({
    required this.bytes,
    required this.fileName,
    required this.contentType,
    required this.isVideo,
    super.key,
  });

  final Uint8List bytes;
  final String fileName;
  final String contentType;
  final bool isVideo;

  static Future<bool?> open(
    BuildContext context, {
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required bool isVideo,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => WaMediaPreviewPage(
          bytes: bytes,
          fileName: fileName,
          contentType: contentType,
          isVideo: isVideo,
        ),
      ),
    );
  }

  @override
  State<WaMediaPreviewPage> createState() => _WaMediaPreviewPageState();
}

class _WaMediaPreviewPageState extends State<WaMediaPreviewPage> {
  VideoPlayerController? _videoController;
  File? _tempVideoFile;
  bool _videoReady = false;

  bool get _isAudio =>
      !widget.isVideo && widget.contentType.startsWith('audio/');

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) _initVideo();
  }

  Future<void> _initVideo() async {
    // video_player 2.x has no in-memory source; stage the bytes on disk so the
    // preview shows a real first frame instead of a placeholder icon.
    final candidate = widget.fileName.split('.').last.toLowerCase();
    final extension = RegExp(r'^[a-z0-9]{1,5}$').hasMatch(candidate) &&
            !candidate.contains('video')
        ? candidate
        : 'mp4';
    final file = File(
      '${Directory.systemTemp.path}/pubget_preview_'
      '${DateTime.now().microsecondsSinceEpoch}.$extension',
    );
    _tempVideoFile = file;
    try {
      await file.writeAsBytes(widget.bytes, flush: true);
    } on Object {
      _clearVideo();
      return;
    }
    final controller = VideoPlayerController.file(file);
    _videoController = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      if (mounted) setState(() => _videoReady = true);
    } on Object {
      _clearVideo();
    }
  }

  void _clearVideo() {
    _videoController?.dispose();
    _videoController = null;
    final file = _tempVideoFile;
    _tempVideoFile = null;
    try {
      file?.deleteSync();
    } on Object {
      // Best-effort temp cleanup.
    }
  }

  void _togglePlayback() {
    final controller = _videoController;
    if (controller == null || !_videoReady) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _clearVideo();
    super.dispose();
  }

  Widget _preview() {
    if (widget.isVideo) {
      final controller = _videoController;
      if (controller != null && _videoReady) {
        return InkWell(
          onTap: _togglePlayback,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              VideoPlayer(controller),
              if (!controller.value.isPlaying)
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
            ],
          ),
        );
      }
      return const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      );
    }
    if (_isAudio) {
      return const Icon(Icons.graphic_eq, color: Colors.white54, size: 72);
    }
    return Image.memory(widget.bytes, fit: BoxFit.contain);
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        leading: IconButton(
          key: const Key('app-back'),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const BackButtonIcon(),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(child: Center(child: _preview())),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          widget.fileName,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        Text(
                          _formatBytes(widget.bytes.length),
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: WaColors.cursorGreen,
                    shape: const CircleBorder(),
                    child: InkWell(
                      key: const Key('media-preview-send'),
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.pop(context, true),
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(Icons.send_rounded, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}