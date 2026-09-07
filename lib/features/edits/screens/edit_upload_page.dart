import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../app/app_router.dart';
import '../../../core/errors/result.dart';
import '../../../core/network/network_service.dart';
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

class EditUploadPage extends StatefulWidget {
  const EditUploadPage({super.key, this.draftStore, this.picker});

  final EditDraftStore? draftStore;
  final ImagePicker? picker;

  @override
  State<EditUploadPage> createState() => _EditUploadPageState();
}

class _EditUploadPageState extends State<EditUploadPage> {
  final _caption = TextEditingController();
  final _anime = TextEditingController();
  late final EditDraftStore _drafts = widget.draftStore ?? EditDraftStore();
  StreamSubscription<Result<Edit>>? _watch;
  XFile? _video;
  double _progress = 0;
  _UploadPhase _phase = _UploadPhase.idle;
  String? _error;
  String? _editId;
  String? _videoPath;
  String? _idempotencyKey;
  bool _restored = false;

  @override
  void initState() {
    super.initState();
    _caption.addListener(_persistDraft);
    _anime.addListener(_persistDraft);
    Future<void>.microtask(_restoreDraft);
  }

  @override
  void dispose() {
    _watch?.cancel();
    _caption.dispose();
    _anime.dispose();
    super.dispose();
  }

  Future<void> _restoreDraft() async {
    final draft = await _drafts.load();
    if (!mounted || draft == null) {
      _restored = true;
      return;
    }
    _caption.text = draft['caption'] as String? ?? '';
    _anime.text = draft['animeTag'] as String? ?? '';
    _editId = draft['editId'] as String?;
    _videoPath = draft['videoPath'] as String?;
    _idempotencyKey = draft['idempotencyKey'] as String?;
    final phase = draft['phase'] as String?;
    if (_editId != null && _editId!.isNotEmpty) {
      _listen(_editId!);
      _phase = phase == 'failed' ? _UploadPhase.failed : _UploadPhase.processing;
    }
    _restored = true;
    if (mounted) setState(() {});
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final copy = EditCopy.of(context);
    final offline = context.watch<NetworkService>().isOffline;
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(copy.uploadTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: PubgetSecondaryButton(
                  onPressed: _busy ? null : () => _choose(ImageSource.gallery),
                  semanticLabel: copy.chooseVideo,
                  leadingIcon: Icons.video_library_outlined,
                  child: Text(_video?.name ?? copy.chooseVideo),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              PubgetSecondaryButton(
                onPressed: _busy ? null : () => _choose(ImageSource.camera),
                semanticLabel: 'Record video',
                leadingIcon: Icons.videocam_outlined,
                child: const Text('Camera'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          PubgetTextField(
            controller: _caption,
            label: copy.caption,
            maxLines: 4,
          ),
          const SizedBox(height: AppSpacing.md),
          PubgetTextField(controller: _anime, label: copy.animeTag),
          const SizedBox(height: AppSpacing.lg),
          _statusCard(copy, offline),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            PubgetErrorState(message: _error!),
          ],
          const SizedBox(height: AppSpacing.xl),
          ..._actions(copy, offline),
        ],
      ),
    );
  }

  bool get _busy =>
      _phase == _UploadPhase.uploading || _phase == _UploadPhase.processing;

  Widget _statusCard(EditCopy copy, bool offline) {
    final paused = _phase == _UploadPhase.paused ||
        (_phase == _UploadPhase.uploading && offline);
    if (_phase == _UploadPhase.idle || _phase == _UploadPhase.invalid) {
      return const SizedBox.shrink();
    }
    if (_phase == _UploadPhase.published) {
      return PubgetEmptyState(
        icon: Icons.check_circle_outline,
        title: copy.published,
        message: 'Your Edit is live. Open it in the feed.',
        action: PubgetPrimaryButton(
          onPressed: () => AppNavigation.go(context, '/edits'),
          semanticLabel: copy.openEdit,
          child: Text(copy.openEdit),
        ),
      );
    }
    if (_phase == _UploadPhase.failed) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LinearProgressIndicator(
          value: _phase == _UploadPhase.uploading && _progress > 0
              ? _progress
              : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          paused
              ? copy.paused
              : _phase == _UploadPhase.processing
              ? copy.processing
              : '${copy.uploading} ${(_progress * 100).round()}%',
        ),
      ],
    );
  }

  List<Widget> _actions(EditCopy copy, bool offline) {
    if (_phase == _UploadPhase.published) return const <Widget>[];
    if (_phase == _UploadPhase.uploading) {
      return <Widget>[
        PubgetSecondaryButton(
          onPressed: _cancel,
          semanticLabel: copy.cancelUpload,
          child: Text(copy.cancelUpload),
        ),
      ];
    }
    if (_phase == _UploadPhase.failed) {
      return <Widget>[
        PubgetPrimaryButton(
          onPressed: offline ? null : _retryFailed,
          semanticLabel: copy.retryProcessing,
          child: Text(copy.retryProcessing),
        ),
        const SizedBox(height: AppSpacing.sm),
        PubgetSecondaryButton(
          onPressed: _deleteDraft,
          semanticLabel: copy.deleteDraft,
          child: Text(copy.deleteDraft),
        ),
      ];
    }
    return <Widget>[
      PubgetPrimaryButton(
        onPressed: _busy || _video == null ? null : _submit,
        semanticLabel: copy.publish,
        loading: _phase == _UploadPhase.uploading,
        child: Text(_error == null ? copy.publish : copy.retry),
      ),
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
      contentType: video.mimeType ?? 'video/mp4',
      sizeBytes: size,
      duration: duration,
    );
    setState(() {
      _video = rejection == null ? video : null;
      _error = rejection?.message;
      _phase = rejection == null ? _UploadPhase.idle : _UploadPhase.invalid;
    });
  }

  Future<void> _submit() async {
    final video = _video;
    if (video == null) return;
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
        _videoPath = edit.videoUrl.isNotEmpty ? null : _videoPath;
        _phase = _UploadPhase.processing;
        _listen(edit.id);
        _persistDraft();
        setState(() {});
      },
      onFailure: (failure) {
        final offline = context.read<NetworkService>().isOffline;
        setState(() {
          _phase = offline ? _UploadPhase.paused : _UploadPhase.failed;
          _error = failure.message;
        });
        _persistDraft();
      },
    );
  }

  void _listen(String editId) {
    _watch?.cancel();
    _watch = context.read<EditsRepository>().watchEdit(editId).listen((result) {
      result.fold(
        onSuccess: (edit) {
          if (!mounted) return;
          if (edit.isPublished) {
            setState(() {
              _phase = _UploadPhase.published;
              _error = null;
            });
            _drafts.clear();
            return;
          }
          if (edit.isFailed) {
            setState(() {
              _phase = _UploadPhase.failed;
              _error = edit.userFacingFailure;
            });
            _persistDraft();
            return;
          }
          if (edit.isProcessing && _phase != _UploadPhase.uploading) {
            setState(() => _phase = _UploadPhase.processing);
          }
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
    });
  }

  Future<void> _retryFailed() async {
    final editId = _editId;
    if (editId == null) {
      await _submit();
      return;
    }
    setState(() {
      _phase = _UploadPhase.processing;
      _error = null;
    });
    final result = await context.read<EditsRepository>().retryProcessing(editId);
    if (!mounted) return;
    if (result.isSuccess) {
      _listen(editId);
      return;
    }
    setState(() {
      _phase = _UploadPhase.failed;
      _error = result.failureOrNull?.message;
    });
  }

  Future<void> _deleteDraft() async {
    final editId = _editId;
    if (editId != null) {
      await context.read<EditsRepository>().deleteEdit(editId);
    }
    await _drafts.clear();
    if (!mounted) return;
    setState(() {
      _editId = null;
      _videoPath = null;
      _idempotencyKey = null;
      _video = null;
      _phase = _UploadPhase.idle;
      _error = null;
    });
  }
}
