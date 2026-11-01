import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../data/kirari_repository.dart';
import '../l10n/kirari_copy.dart';

class KirariUploadPage extends StatefulWidget {
  const KirariUploadPage({super.key});

  @override
  State<KirariUploadPage> createState() => _KirariUploadPageState();
}

class _KirariUploadPageState extends State<KirariUploadPage> {
  static const _pendingKey = 'kirari.pendingUpload.v1';
  final _caption = TextEditingController();
  final _hashtags = TextEditingController();
  final _overlayText = TextEditingController();
  final AudioPlayer _audioPreview = AudioPlayer();
  XFile? _video;
  VideoPlayerController? _preview;
  KirariUploadSession? _session;
  List<KirariAudioTrack> _audioTracks = const [];
  String? _audioId;
  String? _previewingAudioId;
  String? _idempotencyKey;
  RangeValues _trim = const RangeValues(0, 3);
  double _speed = 1;
  double _coverTime = 0;
  String _filter = 'none';
  double _duration = 3;
  bool _busy = false;
  bool _submitted = false;
  double _progress = 0;
  String? _error;
  String? _status;

  @override
  void initState() {
    super.initState();
    _loadAudio();
    _restorePendingUpload();
  }

  @override
  void dispose() {
    _caption.dispose();
    _hashtags.dispose();
    _overlayText.dispose();
    _audioPreview.dispose();
    _preview?.removeListener(_previewLoop);
    _preview?.dispose();
    super.dispose();
  }

  Future<void> _loadAudio() async {
    try {
      final tracks = await context.read<KirariRepository>().getAudioLibrary();
      if (mounted) setState(() => _audioTracks = tracks);
    } catch (_) {
      // Audio catalog is optional; the original source audio remains available.
    }
  }

  Future<void> _restorePendingUpload() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingKey);
      if (raw == null) return;
      final data = jsonDecode(raw);
      if (data is! Map) return;
      final path = data['localPath'] as String?;
      if (path == null || !await File(path).exists()) {
        await prefs.remove(_pendingKey);
        return;
      }
      final file = File(path);
      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      await controller.setLooping(true);
      controller.addListener(_previewLoop);
      final seconds = controller.value.duration.inMilliseconds / 1000;
      if (!mounted) {
        await controller.dispose();
        return;
      }
      final start = (data['trimStartSeconds'] as num?)?.toDouble() ?? 0;
      final end = (data['trimEndSeconds'] as num?)?.toDouble() ?? seconds;
      setState(() {
        _video = XFile(path);
        _preview = controller;
        _duration = seconds;
        _trim = RangeValues(
          start.clamp(0, seconds - 3).toDouble(),
          end.clamp(3, seconds).toDouble(),
        );
        _speed = (data['speed'] as num?)?.toDouble() ?? 1;
        _filter = data['filter'] as String? ?? 'none';
        _coverTime = (data['coverTimeSeconds'] as num?)?.toDouble() ?? 0;
        _overlayText.text = data['overlayText'] as String? ?? '';
        _caption.text = data['caption'] as String? ?? '';
        _hashtags.text = (data['hashtags'] as List? ?? const []).join(' ');
        _audioId = data['audioId'] as String?;
        _idempotencyKey = data['idempotencyKey'] as String?;
        final reelId = data['reelId'] as String?;
        final storagePath = data['storagePath'] as String?;
        if (reelId != null && storagePath != null) {
          _session = KirariUploadSession(reelId: reelId, storagePath: storagePath);
        }
        _status = KirariCopy.of(context).resumeUpload;
      });
    } catch (_) {
      if (mounted) setState(() => _error = KirariCopy.of(context).loadError);
    }
  }

  Future<File> _keepLocalCopy(XFile picked) async {
    final directory = await getApplicationSupportDirectory();
    final folder = Directory('${directory.path}/kirari_uploads');
    await folder.create(recursive: true);
    final extension = picked.name.contains('.')
        ? picked.name.substring(picked.name.lastIndexOf('.'))
        : '.mp4';
    final target = File('${folder.path}/${DateTime.now().microsecondsSinceEpoch}$extension');
    return File(picked.path).copy(target.path);
  }

  void _previewLoop() {
    final controller = _preview;
    if (controller == null || !controller.value.isInitialized || !controller.value.isPlaying) return;
    final position = controller.value.position.inMilliseconds / 1000;
    if (position >= _trim.end) {
      controller.pause();
      controller.seekTo(Duration(milliseconds: (_trim.start * 1000).round()));
      if (mounted) setState(() {});
    }
  }

  Future<void> _pick() async {
    final picked = await context.read<KirariRepository>().pickGalleryVideo();
    if (picked == null || !mounted) return;
    File? durableFile;
    VideoPlayerController? controller;
    try {
      final sourceFile = File(picked.path);
      final size = await sourceFile.length();
      if (size > 500 * 1024 * 1024) {
        setState(() => _error = KirariCopy.of(context).videoLimits);
        return;
      }
      final sourceController = VideoPlayerController.file(sourceFile);
      await sourceController.initialize();
      final duration = sourceController.value.duration.inMilliseconds / 1000;
      await sourceController.dispose();
      if (duration < 3 || duration > 60) {
        setState(() => _error = KirariCopy.of(context).videoLimits);
        return;
      }
      durableFile = await _keepLocalCopy(picked);
      controller = VideoPlayerController.file(durableFile);
      await controller.initialize();
      await controller.setLooping(true);
      controller.addListener(_previewLoop);
      _preview?.removeListener(_previewLoop);
      await _preview?.dispose();
      if (!mounted) {
        await controller.dispose();
        await durableFile.delete().catchError((_) => durableFile!);
        return;
      }
      setState(() {
        _video = XFile(durableFile!.path);
        _preview = controller;
        _duration = duration;
        _trim = RangeValues(0, duration);
        _coverTime = 0;
        _session = null;
        _idempotencyKey = 'kirari-' + DateTime.now().microsecondsSinceEpoch.toString();
        _progress = 0;
        _error = null;
        _status = null;
        _submitted = false;
      });
      await _savePendingUpload();
    } catch (_) {
      if (controller != null) await controller.dispose();
      if (durableFile != null) await durableFile.delete().catchError((_) => durableFile!);
      if (mounted) setState(() => _error = KirariCopy.of(context).playbackError);
    }
  }

  Map<String, dynamic> _editorSettings() => <String, dynamic>{
    'trimStartSeconds': _trim.start,
    'trimEndSeconds': _trim.end,
    'speed': _speed,
    'filter': _filter,
    'overlayText': _overlayText.text.trim(),
    'coverTimeSeconds': _coverTime,
  };

  Future<void> _savePendingUpload() async {
    final video = _video;
    if (video == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingKey, jsonEncode(<String, dynamic>{
      'localPath': video.path,
      'reelId': _session?.reelId,
      'storagePath': _session?.storagePath,
      'idempotencyKey': _idempotencyKey,
      'caption': _caption.text,
      'hashtags': _hashtags.text.split(RegExp(r'[,\\s]+')).where((tag) => tag.isNotEmpty).toList(),
      'audioId': _audioId,
      ..._editorSettings(),
    }));
  }

  Future<void> _clearPendingUpload({bool deleteLocalFile = true}) async {
    final path = _video?.path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingKey);
    if (deleteLocalFile && path != null) {
      await File(path).delete().catchError((_) => File(path));
    }
  }

  Future<void> _publish() async {
    final video = _video;
    if (video == null || _busy || _submitted) return;
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
            .split(RegExp(r'[,\\s]+'))
            .map((tag) => tag.trim().replaceFirst(RegExp(r'^#'), '').toLowerCase())
            .where((tag) => tag.isNotEmpty)
            .toSet()
            .toList(),
        idempotencyKey: _idempotencyKey ??= 'kirari-${DateTime.now().microsecondsSinceEpoch}',
        editSettings: _editorSettings(),
        audioId: _audioId,
      );
      _session = session;
      await _savePendingUpload();
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
      setState(() => _status = KirariCopy.of(context).processing);
      await repository.finalizeUpload(session.reelId);
      await _clearPendingUpload();
      if (!mounted) return;
      setState(() {
        _status = KirariCopy.of(context).received;
        _submitted = true;
        _video = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(KirariCopy.of(context).uploadReceived)),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = KirariCopy.of(context).uploadError);
        await _savePendingUpload();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelUpload() async {
    final session = _session;
    if (session != null) {
      await context.read<KirariRepository>().cancelUpload(session.reelId);
    }
    await _clearPendingUpload();
    await _preview?.dispose();
    if (!mounted) return;
    setState(() {
      _session = null;
      _video = null;
      _preview = null;
      _error = null;
      _status = 'Upload canceled.';
      _progress = 0;
      _submitted = false;
    });
  }

  Future<void> _chooseAudio() async {
    final copy = KirariCopy.of(context);
    final selectedId = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, updateSheet) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(title: Text(copy.audioLibrary), subtitle: Text(copy.originalAudio)),
              ListTile(
                leading: const Icon(Icons.music_off_outlined),
                title: Text(copy.originalAudio),
                onTap: () async {
                  await _audioPreview.stop();
                  if (sheetContext.mounted) Navigator.pop(sheetContext, '');
                },
              ),
              for (final track in _audioTracks)
                ListTile(
                  leading: const Icon(Icons.music_note),
                  title: Text(track.title),
                  subtitle: Text(track.artist + ' · ' + track.license),
                  trailing: IconButton(
                    tooltip: 'Preview audio',
                    icon: Icon(_previewingAudioId == track.id ? Icons.stop : Icons.play_arrow),
                    onPressed: () async {
                      if (_previewingAudioId == track.id) {
                        await _audioPreview.stop();
                        updateSheet(() => _previewingAudioId = null);
                      } else {
                        await _audioPreview.stop();
                        await _audioPreview.play(UrlSource(track.audioUrl));
                        updateSheet(() => _previewingAudioId = track.id);
                      }
                    },
                  ),
                  onTap: () async {
                    await _audioPreview.stop();
                    if (sheetContext.mounted) Navigator.pop(sheetContext, track.id);
                  },
                ),
              if (_audioTracks.isEmpty)
                const ListTile(title: Text('No approved reusable audio is available yet.')),
            ],
          ),
        ),
      ),
    );
    await _audioPreview.stop();
    if (!mounted || selectedId == null) return;
    setState(() { _previewingAudioId = null; _audioId = selectedId.isEmpty ? null : selectedId; });
    await _savePendingUpload();
  }


  ColorFilter? _previewFilter() {
    switch (_filter) {
      case 'warm':
        return const ColorFilter.matrix(<double>[
          1.08, 0, 0, 0, 8, 0, 1.02, 0, 0, 3, 0, 0, .9, 0, 0, 0, 0, 0, 1, 0,
        ]);
      case 'cool':
        return const ColorFilter.matrix(<double>[
          .92, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1.12, 0, 8, 0, 0, 0, 1, 0,
        ]);
      case 'mono':
        return const ColorFilter.matrix(<double>[
          .213, .715, .072, 0, 0, .213, .715, .072, 0, 0, .213, .715, .072, 0, 0, 0, 0, 0, 1, 0,
        ]);
      case 'vivid':
        return const ColorFilter.matrix(<double>[
          1.25, -.1, -.1, 0, 0, -.1, 1.25, -.1, 0, 0, -.1, -.1, 1.25, 0, 0, 0, 0, 0, 1, 0,
        ]);
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = KirariCopy.of(context);
    final preview = _preview;
    final filter = _previewFilter();
    final selectedTracks = _audioTracks.where((track) => track.id == _audioId);
    final selectedTrack = selectedTracks.isEmpty ? null : selectedTracks.first;
    return Scaffold(
      appBar: AppBar(title: Text(copy.create)),
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
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        if (filter == null)
                          VideoPlayer(preview!)
                        else
                          ColorFiltered(colorFilter: filter, child: VideoPlayer(preview!)),
                        if (_overlayText.text.trim().isNotEmpty)
                          Center(
                            child: Text(
                              _overlayText.text,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white, fontSize: 24,
                                fontWeight: FontWeight.bold,
                                shadows: [Shadow(blurRadius: 5, color: Colors.black)],
                              ),
                            ),
                          ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: IconButton(
                            color: Colors.white,
                            icon: Icon(preview.value.isPlaying ? Icons.pause : Icons.play_arrow),
                            onPressed: () async {
                              if (preview.value.isPlaying) {
                                await preview.pause();
                              } else {
                                await preview.setPlaybackSpeed(_speed);
                                await preview.seekTo(Duration(milliseconds: (_trim.start * 1000).round()));
                                await preview.play();
                              }
                              if (mounted) setState(() {});
                            },
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.video_library_outlined, size: 52),
                        const SizedBox(height: 12),
                        Text(copy.chooseVideo),
                        Text(copy.videoLimits),
                      ],
                    ),
            ),
          ),
          if (_video != null) ...[
            const SizedBox(height: 18),
            Text(copy.trim, style: Theme.of(context).textTheme.titleMedium),
            RangeSlider(
              min: 0,
              max: _duration,
              divisions: (_duration * 2).round().clamp(6, 120).toInt(),
              values: _trim,
              labels: RangeLabels('${_trim.start.toStringAsFixed(1)}s', '${_trim.end.toStringAsFixed(1)}s'),
              onChanged: _busy ? null : (value) {
                var start = value.start;
                var end = value.end;
                if (end - start < 3) {
                  if (start != _trim.start) {
                    start = (end - 3).clamp(0, _duration - 3).toDouble();
                  } else {
                    end = (start + 3).clamp(3, _duration).toDouble();
                  }
                }
                setState(() {
                  _trim = RangeValues(start, end);
                  _coverTime = _coverTime.clamp(start, end).toDouble();
                });
                _savePendingUpload();
              },
            ),
            Text(copy.speed, style: Theme.of(context).textTheme.titleMedium),
            DropdownButtonFormField<double>(
              value: _speed,
              items: const [
                DropdownMenuItem(value: .5, child: Text('0.5×')),
                DropdownMenuItem(value: .75, child: Text('0.75×')),
                DropdownMenuItem(value: 1, child: Text('1×')),
                DropdownMenuItem(value: 1.25, child: Text('1.25×')),
                DropdownMenuItem(value: 1.5, child: Text('1.5×')),
                DropdownMenuItem(value: 2, child: Text('2×')),
              ],
              onChanged: _busy ? null : (value) {
                if (value == null) return;
                setState(() => _speed = value);
                _preview?.setPlaybackSpeed(value);
                _savePendingUpload();
              },
            ),
            const SizedBox(height: 12),
            Text(copy.filter, style: Theme.of(context).textTheme.titleMedium),
            DropdownButtonFormField<String>(
              value: _filter,
              items: const [
                DropdownMenuItem(value: 'none', child: Text('Original')),
                DropdownMenuItem(value: 'warm', child: Text('Warm')),
                DropdownMenuItem(value: 'cool', child: Text('Cool')),
                DropdownMenuItem(value: 'mono', child: Text('Mono')),
                DropdownMenuItem(value: 'vivid', child: Text('Vivid')),
              ],
              onChanged: _busy ? null : (value) {
                if (value != null) setState(() => _filter = value);
                _savePendingUpload();
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _overlayText,
              maxLength: 80,
              decoration: InputDecoration(labelText: copy.overlayText),
              onChanged: (_) {
                setState(() {});
                _savePendingUpload();
              },
            ),
            Text(copy.coverFrame, style: Theme.of(context).textTheme.titleMedium),
            Slider(
              min: _trim.start,
              max: _trim.end,
              value: _coverTime.clamp(_trim.start, _trim.end).toDouble(),
              onChanged: _busy ? null : (value) {
                setState(() => _coverTime = value);
                _savePendingUpload();
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.music_note),
              title: Text(copy.audioLibrary),
              subtitle: Text(selectedTrack == null
                  ? copy.originalAudio
                  : '${selectedTrack.title} · ${selectedTrack.artist} · ${selectedTrack.license}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _busy ? null : _chooseAudio,
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _caption,
            maxLength: 2200,
            maxLines: 3,
            decoration: InputDecoration(labelText: copy.caption, border: const OutlineInputBorder()),
            onChanged: (_) => _savePendingUpload(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hashtags,
            decoration: InputDecoration(
              labelText: copy.hashtags,
              hintText: 'anime, one_piece, edits',
              helperText: 'Separate tags with spaces or commas.',
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => _savePendingUpload(),
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
          if (_session != null && _error != null && !_busy)
            TextButton(
              onPressed: _cancelUpload,
              child: Text(copy.cancelUpload),
            ),
          FilledButton.icon(
            onPressed: _busy || _video == null || _submitted ? null : _publish,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(_busy ? copy.uploading : _submitted ? copy.received : copy.publish),
          ),
        ],
      ),
    );
  }
}
