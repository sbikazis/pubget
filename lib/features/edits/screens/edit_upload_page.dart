import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../../app/app_back_button.dart';
import '../../../app/app_router.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/network/network_service.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../data/edit_draft_store.dart';
import '../data/edit_duration_probe.dart';
import '../data/edit_validator.dart';
import '../l10n/edit_copy.dart';
import '../models/edit_models.dart';
import '../repositories/edits_repository.dart';

enum _UploadPhase {
  idle,
  invalid,
  uploading,
  paused,
  processing,
  failed,
  published,
}

/// Short-form Edit studio — video-first composer with server reconciliation.
class EditUploadPage extends StatefulWidget {
  const EditUploadPage({super.key, this.draftStore, this.picker});

  final EditDraftStore? draftStore;
  final ImagePicker? picker;

  @override
  State<EditUploadPage> createState() => _EditUploadPageState();
}

class _EditUploadPageState extends State<EditUploadPage>
    with WidgetsBindingObserver {
  final _caption = TextEditingController();
  final _anime = TextEditingController();
  late final EditDraftStore _drafts = widget.draftStore ?? EditDraftStore();
  StreamSubscription<Result<Edit>>? _watch;
  VideoPlayerController? _preview;
  XFile? _video;
  double _progress = 0;
  _UploadPhase _phase = _UploadPhase.idle;
  String? _error;
  String? _editId;
  String? _videoPath;
  String? _idempotencyKey;
  String? _localPath;
  bool _restored = false;
  bool _syncing = false;
  bool _muted = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _caption.addListener(_persistDraft);
    _anime.addListener(_persistDraft);
    Future<void>.microtask(_restoreAndReconcile);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _watch?.cancel();
    _preview?.dispose();
    _caption.dispose();
    _anime.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _editId != null) {
      unawaited(_reconcileFromServer());
    }
  }

  Future<void> _restoreAndReconcile() async {
    final draft = await _drafts.load();
    if (!mounted) return;
    if (draft != null) {
      _caption.text = draft['caption'] as String? ?? '';
      _anime.text = draft['animeTag'] as String? ?? '';
      _editId = draft['editId'] as String?;
      _videoPath = draft['videoPath'] as String?;
      _idempotencyKey = draft['idempotencyKey'] as String?;
      _localPath = draft['localPath'] as String?;
      final phase = draft['phase'] as String?;
      if (phase == 'failed') {
        _phase = _UploadPhase.failed;
      } else if (phase == 'uploading' || phase == 'paused') {
        _phase = _UploadPhase.paused;
      } else if (phase == 'processing' || phase == 'published') {
        _phase = phase == 'published'
            ? _UploadPhase.published
            : _UploadPhase.processing;
      }
      if (_localPath != null && _localPath!.isNotEmpty && !kIsWeb) {
        final file = File(_localPath!);
        if (await file.exists()) {
          _video = XFile(_localPath!);
          await _bindPreview(_localPath!);
        }
      }
    }
    _restored = true;
    if (mounted) setState(() {});
    await _reconcileFromServer();
  }

  Future<void> _reconcileFromServer() async {
    final editId = _editId;
    if (editId == null || editId.isEmpty || !mounted) return;
    setState(() => _syncing = true);
    final result = await context.read<EditsRepository>().getEdit(editId);
    if (!mounted) return;
    result.fold(
      onSuccess: (edit) {
        _applyServerEdit(edit);
        _listen(edit.id);
      },
      onFailure: (_) {
        // Keep local draft; watch may still recover.
        if (_editId != null) _listen(_editId!);
      },
    );
    if (mounted) setState(() => _syncing = false);
  }

  void _applyServerEdit(Edit edit) {
    final copy = EditCopy.of(context);
    if (edit.isPublished) {
      _phase = _UploadPhase.published;
      _error = null;
      unawaited(_drafts.clear());
      return;
    }
    if (edit.isFailed) {
      _phase = _UploadPhase.failed;
      _error = copy.failureFor(edit);
      unawaited(_persistDraft());
      return;
    }
    if (edit.isProcessing) {
      _phase = _UploadPhase.processing;
      _error = null;
      unawaited(_persistDraft());
      return;
    }
  }

  Future<void> _persistDraft() async {
    if (!_restored) return;
    await _drafts.save(<String, dynamic>{
      'caption': _caption.text,
      'animeTag': _anime.text,
      'editId': _editId,
      'videoPath': _videoPath,
      'idempotencyKey': _idempotencyKey,
      'phase': _phase.name,
      'fileName': _video?.name,
      'localPath': _localPath ?? _video?.path,
    });
  }

  Future<void> _bindPreview(String path) async {
    await _preview?.dispose();
    _preview = null;
    if (kIsWeb || path.isEmpty) return;
    final controller = VideoPlayerController.file(File(path));
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(_muted ? 0 : 1);
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _preview = controller);
    } on Object {
      await controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = EditCopy.of(context);
    final offline = context.watch<NetworkService>().isOffline;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0A10),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: AppBackButton.maybeOf(context),
        title: Text(copy.uploadTitle),
        actions: <Widget>[
          if (_editId != null && _phase != _UploadPhase.published)
            TextButton(
              onPressed: _busy
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final savedLabel = copy.saveDraft;
                      await _persistDraft();
                      messenger.showSnackBar(
                        SnackBar(content: Text(savedLabel)),
                      );
                    },
              child: Text(copy.saveDraft),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: <Widget>[
          _PreviewStage(
            copy: copy,
            preview: _preview,
            hasVideo: _video != null,
            muted: _muted,
            phase: _phase,
            progress: _progress,
            syncing: _syncing,
            onToggleMute: () async {
              setState(() => _muted = !_muted);
              await _preview?.setVolume(_muted ? 0 : 1);
            },
            onTogglePlay: () async {
              final player = _preview;
              if (player == null) return;
              if (player.value.isPlaying) {
                await player.pause();
              } else {
                await player.play();
              }
              setState(() {});
            },
            onPickGallery: _busy ? null : () => _choose(ImageSource.gallery),
            onPickCamera: _busy ? null : () => _choose(ImageSource.camera),
          ),
          const SizedBox(height: AppSpacing.lg),
          _StatusBanner(
            copy: copy,
            phase: _phase,
            offline: offline,
            error: _error,
            progress: _progress,
            syncing: _syncing,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _caption,
            maxLines: 4,
            maxLength: 1000,
            style: const TextStyle(color: Colors.white, height: 1.35),
            decoration: InputDecoration(
              labelText: copy.caption,
              hintText: copy.captionHint,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _anime,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: copy.animeTag,
              hintText: copy.animeTagHint,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              prefixIcon: Icon(Icons.tag, color: scheme.secondary),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          ..._actions(copy, offline),
        ],
      ),
    );
  }

  bool get _busy =>
      _submitting ||
      _phase == _UploadPhase.uploading ||
      _phase == _UploadPhase.processing;

  List<Widget> _actions(EditCopy copy, bool offline) {
    if (_phase == _UploadPhase.published) {
      return <Widget>[
        PubgetPrimaryButton(
          onPressed: () => AppNavigation.go(context, '/edits'),
          semanticLabel: copy.openEdit,
          child: Text(copy.openEdit),
        ),
      ];
    }
    if (_phase == _UploadPhase.uploading) {
      return <Widget>[
        PubgetSecondaryButton(
          onPressed: _cancel,
          semanticLabel: copy.cancelUpload,
          child: Text(copy.cancelUpload),
        ),
      ];
    }
    if (_phase == _UploadPhase.failed || _phase == _UploadPhase.paused) {
      return <Widget>[
        PubgetPrimaryButton(
          onPressed: offline || _submitting ? null : _retryFailed,
          semanticLabel: copy.retryProcessing,
          loading: _submitting,
          child: Text(
            _video != null ? copy.retry : copy.retryProcessing,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_video != null)
          PubgetSecondaryButton(
            onPressed: _busy ? null : () => _choose(ImageSource.gallery),
            semanticLabel: copy.replaceVideo,
            child: Text(copy.replaceVideo),
          ),
        if (_video != null) const SizedBox(height: AppSpacing.sm),
        PubgetSecondaryButton(
          onPressed: _deleteDraft,
          semanticLabel: copy.deleteDraft,
          child: Text(copy.deleteDraft),
        ),
      ];
    }
    return <Widget>[
      PubgetPrimaryButton(
        onPressed: _busy || offline
            ? null
            : _video == null
                ? () => _choose(ImageSource.gallery)
                : _submit,
        semanticLabel: copy.publish,
        loading: _submitting,
        child: Text(
          copy.primaryActionLabel(
            hasVideo: _video != null,
            phase: _phase.name,
          ),
        ),
      ),
      if (_video != null) ...[
        const SizedBox(height: AppSpacing.sm),
        PubgetSecondaryButton(
          onPressed: _busy ? null : () => _choose(ImageSource.gallery),
          semanticLabel: copy.replaceVideo,
          child: Text(copy.replaceVideo),
        ),
      ],
    ];
  }

  Future<void> _choose(ImageSource source) async {
    final video = await (widget.picker ?? ImagePicker()).pickVideo(
      source: source,
    );
    if (video == null || !mounted) return;
    final size = await video.length();
    final duration = await probeEditDuration(video.path);
    final rejection = EditValidation.reject(
      fileName: video.name,
      contentType: 'video/mp4',
      sizeBytes: size,
      duration: duration,
    );
    if (rejection != null) {
      setState(() {
        _error = rejection.message;
        _phase = _UploadPhase.invalid;
      });
      return;
    }
    _localPath = video.path;
    setState(() {
      _video = video;
      _error = null;
      if (_phase == _UploadPhase.invalid ||
          _phase == _UploadPhase.idle ||
          _phase == _UploadPhase.failed) {
        _phase = _UploadPhase.idle;
      }
    });
    await _bindPreview(video.path);
    await _persistDraft();
  }

  Future<void> _submit() async {
    final video = _video;
    if (video == null || _submitting) return;
    final captionError = EditValidation.rejectCaption(_caption.text);
    if (captionError != null) {
      setState(() {
        _error = captionError.message;
        _phase = _UploadPhase.invalid;
      });
      return;
    }
    final size = await video.length();
    _idempotencyKey ??=
        '${DateTime.now().millisecondsSinceEpoch}-${video.name}-$size';
    setState(() {
      _submitting = true;
      _phase = _UploadPhase.uploading;
      _error = null;
      _progress = 0;
    });
    await _persistDraft();
    if (!mounted) return;
    final source = !kIsWeb && video.path.isNotEmpty
        ? EditUploadSource.file(video.path)
        : EditUploadSource.memory(await video.readAsBytes());
    if (!mounted) return;
    final copy = EditCopy.of(context);
    final result = await context.read<EditsRepository>().uploadEdit(
      source: source,
      contentType: 'video/mp4',
      caption: _caption.text,
      animeTag: _anime.text,
      fileName: video.name,
      sizeBytes: size,
      idempotencyKey: _idempotencyKey,
      resumeEditId: _editId,
      resumeVideoPath: _videoPath,
      onStarted: (editId, path) {
        _editId = editId;
        _videoPath = path;
        _persistDraft();
      },
      onProgress: (value) {
        if (mounted) setState(() => _progress = value);
      },
    );
    if (!mounted) return;
    result.fold(
      onSuccess: (edit) {
        _editId = edit.id;
        _applyServerEdit(edit);
        if (!edit.isPublished && !edit.isFailed) {
          _phase = _UploadPhase.processing;
          _listen(edit.id);
        }
        _submitting = false;
        _persistDraft();
        setState(() {});
      },
      onFailure: (failure) {
        final offline = context.read<NetworkService>().isOffline;
        setState(() {
          _submitting = false;
          _phase = offline ? _UploadPhase.paused : _UploadPhase.failed;
          _error = copy.friendlyFailure(failure);
        });
        _persistDraft();
      },
    );
  }

  void _listen(String editId) {
    _watch?.cancel();
    final repo = context.read<EditsRepository>();
    _watch = repo.watchEdit(editId).listen((result) {
      result.fold(
        onSuccess: (edit) {
          if (!mounted) return;
          setState(() => _applyServerEdit(edit));
        },
        onFailure: (_) {},
      );
    });
  }

  Future<void> _cancel() async {
    await context.read<EditsRepository>().cancelUpload();
    if (!mounted) return;
    setState(() {
      _phase = _UploadPhase.idle;
      _progress = 0;
      _submitting = false;
    });
    await _persistDraft();
  }

  Future<void> _retryFailed() async {
    final editId = _editId;
    final copy = EditCopy.of(context);
    // Prefer re-upload when local video is still available (covers auth/network
    // failures before the object landed in Storage).
    if (_video != null &&
        (editId == null ||
            _phase == _UploadPhase.paused ||
            _error?.toLowerCase().contains('upload') == true ||
            _error?.contains('آمن') == true)) {
      await _submit();
      return;
    }
    if (editId == null) {
      await _submit();
      return;
    }
    setState(() {
      _submitting = true;
      _phase = _UploadPhase.processing;
      _error = null;
    });
    final result =
        await context.read<EditsRepository>().retryProcessing(editId);
    if (!mounted) return;
    if (result.isSuccess) {
      _submitting = false;
      _listen(editId);
      setState(() {});
      return;
    }
    setState(() {
      _submitting = false;
      _phase = _UploadPhase.failed;
      _error = copy.friendlyFailure(
        result.failureOrNull ??
            const UnknownError(
              'Something went wrong while preparing your Edit. Please try again.',
            ),
      );
    });
  }

  Future<void> _deleteDraft() async {
    final editId = _editId;
    if (editId != null) {
      await context.read<EditsRepository>().deleteEdit(editId);
    }
    await _drafts.clear();
    await _preview?.dispose();
    _preview = null;
    if (!mounted) return;
    setState(() {
      _editId = null;
      _videoPath = null;
      _idempotencyKey = null;
      _localPath = null;
      _video = null;
      _phase = _UploadPhase.idle;
      _error = null;
      _progress = 0;
    });
  }
}

class _PreviewStage extends StatelessWidget {
  const _PreviewStage({
    required this.copy,
    required this.preview,
    required this.hasVideo,
    required this.muted,
    required this.phase,
    required this.progress,
    required this.syncing,
    required this.onToggleMute,
    required this.onTogglePlay,
    required this.onPickGallery,
    required this.onPickCamera,
  });

  final EditCopy copy;
  final VideoPlayerController? preview;
  final bool hasVideo;
  final bool muted;
  final _UploadPhase phase;
  final double progress;
  final bool syncing;
  final VoidCallback onToggleMute;
  final VoidCallback onTogglePlay;
  final VoidCallback? onPickGallery;
  final VoidCallback? onPickCamera;

  @override
  Widget build(BuildContext context) {
    final player = preview;
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF1A1228), Color(0xFF0B0A10)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (player != null && player.value.isInitialized)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: player.value.size.width,
                    height: player.value.size.height,
                    child: VideoPlayer(player),
                  ),
                )
              else
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.movie_creation_outlined,
                          size: 48,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          hasVideo ? copy.previewUnavailable : copy.noVideoYet,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          alignment: WrapAlignment.center,
                          children: <Widget>[
                            PubgetSecondaryButton(
                              onPressed: onPickGallery,
                              semanticLabel: copy.chooseVideo,
                              leadingIcon: Icons.video_library_outlined,
                              child: Text(copy.chooseVideo),
                            ),
                            PubgetSecondaryButton(
                              onPressed: onPickCamera,
                              semanticLabel: copy.recordVideoHint,
                              leadingIcon: Icons.videocam_outlined,
                              child: Text(copy.recordVideo),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              if (player != null && player.value.isInitialized)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Row(
                    children: <Widget>[
                      IconButton.filledTonal(
                        onPressed: onTogglePlay,
                        tooltip: player.value.isPlaying
                            ? copy.pause
                            : copy.play,
                        icon: Icon(
                          player.value.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: onToggleMute,
                        tooltip: muted ? copy.unmute : copy.mute,
                        icon: Icon(
                          muted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                        ),
                      ),
                      const Spacer(),
                      if (phase == _UploadPhase.uploading)
                        SizedBox(
                          width: 120,
                          child: LinearProgressIndicator(
                            value: progress > 0 ? progress : null,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                    ],
                  ),
                ),
              if (syncing)
                const Positioned(
                  top: 12,
                  right: 12,
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.copy,
    required this.phase,
    required this.offline,
    required this.error,
    required this.progress,
    required this.syncing,
  });

  final EditCopy copy;
  final _UploadPhase phase;
  final bool offline;
  final String? error;
  final double progress;
  final bool syncing;

  @override
  Widget build(BuildContext context) {
    if (phase == _UploadPhase.idle && error == null && !syncing) {
      return const SizedBox.shrink();
    }
    if (phase == _UploadPhase.published) {
      return PubgetEmptyState(
        icon: Icons.check_circle_outline,
        title: copy.published,
        message: copy.publishedMessage,
      );
    }
    final paused =
        phase == _UploadPhase.paused || (phase == _UploadPhase.uploading && offline);
    final title = syncing
        ? copy.syncing
        : paused
            ? copy.paused
            : phase == _UploadPhase.processing
                ? copy.processing
                : phase == _UploadPhase.uploading
                    ? '${copy.uploading} ${(progress * 100).round()}%'
                    : phase == _UploadPhase.failed
                        ? copy.failedStatus
                        : copy.draftStatus;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                error!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
