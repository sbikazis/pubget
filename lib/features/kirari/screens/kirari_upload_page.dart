import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../data/kirari_repository.dart';

class KirariUploadPage extends StatefulWidget {
  const KirariUploadPage({super.key});

  @override
  State<KirariUploadPage> createState() => _KirariUploadPageState();
}

class _KirariUploadPageState extends State<KirariUploadPage> {
  final _caption = TextEditingController();
  final _hashtags = TextEditingController();
  XFile? _video;
  VideoPlayerController? _preview;
  KirariUploadSession? _session;
  bool _busy = false;
  bool _submitted = false;
  double _progress = 0;
  String? _error;
  String? _status;

  @override
  void dispose() {
    _caption.dispose();
    _hashtags.dispose();
    final preview = _preview;
    if (preview != null) preview.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final repository = context.read<KirariRepository>();
    final picked = await repository.pickGalleryVideo();
    if (picked == null || !mounted) return;
    final file = File(picked.path);
    final size = await file.length();
    if (size > 500 * 1024 * 1024) {
      setState(() => _error = 'Video must be 500 MB or smaller.');
      return;
    }
    final controller = VideoPlayerController.file(file);
    try {
      await controller.initialize();
      final duration = controller.value.duration.inMilliseconds / 1000;
      if (duration < 3 || duration > 60) {
        await controller.dispose();
        setState(() => _error = 'Kirari videos must be between 3 and 60 seconds.');
        return;
      }
      await controller.setLooping(true);
      await controller.pause();
      await _preview?.dispose();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _video = picked;
        _preview = controller;
        _session = null;
        _progress = 0;
        _error = null;
        _status = null;
        _submitted = false;
      });
    } catch (_) {
      await controller.dispose();
      if (mounted) setState(() => _error = 'This video could not be previewed.');
    }
  }

  Future<void> _publish() async {
    final video = _video;
    if (video == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _status = 'Preparing secure upload…';
    });
    try {
      final repository = context.read<KirariRepository>();
      final session = _session ?? await repository.startUpload(
        caption: _caption.text.trim(),
        hashtags: _hashtags.text
            .split(RegExp(r'[,\s]+'))
            .map((tag) => tag.trim().replaceFirst(RegExp(r'^#'), '').toLowerCase())
            .where((tag) => tag.isNotEmpty)
            .toSet()
            .toList(),
        idempotencyKey: 'kirari-${DateTime.now().microsecondsSinceEpoch}',
      );
      _session = session;
      if (!mounted) return;
      setState(() => _status = 'Uploading video…');
      await repository.uploadSource(
        storagePath: session.storagePath,
        video: video,
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
      );
      if (!mounted) return;
      setState(() => _status = 'Processing video and creating quality versions…');
      await repository.finalizeUpload(session.reelId);
      if (!mounted) return;
      setState(() {
        _status = 'Upload received. Processing continues in the background.';
        _submitted = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kirari upload received.')),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Upload failed. Check your connection and retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return Scaffold(
      appBar: AppBar(title: const Text('Create on Kirari')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: _busy ? null : _pick,
            child: Container(
              height: 390,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              clipBehavior: Clip.antiAlias,
              child: preview?.value.isInitialized == true
                  ? Center(
                      child: AspectRatio(
                        aspectRatio: preview!.value.aspectRatio,
                        child: VideoPlayer(preview),
                      ),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.video_library_outlined, size: 52),
                        SizedBox(height: 12),
                        Text('Choose a video from your gallery'),
                        Text('Vertical video · 3–60 seconds · up to 500 MB'),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _caption,
            maxLength: 2200,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Caption',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hashtags,
            decoration: const InputDecoration(
              labelText: 'Hashtags',
              hintText: 'anime, one_piece, edits',
              helperText: 'Separate tags with spaces or commas.',
              border: OutlineInputBorder(),
            ),
          ),
          if (_busy || _progress > 0) ...[
            const SizedBox(height: 18),
            LinearProgressIndicator(value: _progress == 0 ? null : _progress),
          ],
          if (_status != null) ...[
            const SizedBox(height: 10),
            Text(_status!),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _busy || _video == null || _submitted ? null : _publish,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(_busy ? 'Uploading…' : _submitted ? 'Submitted' : 'Publish video'),
          ),
        ],
      ),
    );
  }
}
