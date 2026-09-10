import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../models/edit_models.dart';
import '../repositories/edits_repository.dart';

enum EditUploadJobPhase {
  queued,
  uploading,
  processing,
  published,
  needsReview,
  failed,
  canceled,
}

/// One background Edit upload/processing job tracked by [EditUploadManager].
final class EditUploadJob {
  EditUploadJob({
    required this.localId,
    required this.caption,
    required this.animeTag,
    required this.contentType,
    required this.fileName,
    this.localPath,
    this.bytes,
    this.sizeBytes,
    this.idempotencyKey,
    this.editId,
    this.videoPath,
    this.phase = EditUploadJobPhase.queued,
    this.progress = 0,
    this.errorMessage,
    this.failureReason,
  });

  final String localId;
  String caption;
  String animeTag;
  String contentType;
  String fileName;
  String? localPath;
  List<int>? bytes;
  int? sizeBytes;
  String? idempotencyKey;
  String? editId;
  String? videoPath;
  EditUploadJobPhase phase;
  double progress;
  String? errorMessage;
  String? failureReason;

  bool get isActive =>
      phase == EditUploadJobPhase.queued ||
      phase == EditUploadJobPhase.uploading ||
      phase == EditUploadJobPhase.processing;

  bool get isTerminal =>
      phase == EditUploadJobPhase.published ||
      phase == EditUploadJobPhase.needsReview ||
      phase == EditUploadJobPhase.failed ||
      phase == EditUploadJobPhase.canceled;

  bool get isFailed => phase == EditUploadJobPhase.failed;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'localId': localId,
    'caption': caption,
    'animeTag': animeTag,
    'contentType': contentType,
    'fileName': fileName,
    'localPath': localPath,
    'sizeBytes': sizeBytes,
    'idempotencyKey': idempotencyKey,
    'editId': editId,
    'videoPath': videoPath,
    'phase': phase.name,
    'progress': progress,
    'errorMessage': errorMessage,
    'failureReason': failureReason,
  };

  factory EditUploadJob.fromJson(Map<String, dynamic> json) {
    return EditUploadJob(
      localId: json['localId'] as String? ?? '',
      caption: json['caption'] as String? ?? '',
      animeTag: json['animeTag'] as String? ?? '',
      contentType: json['contentType'] as String? ?? 'video/mp4',
      fileName: json['fileName'] as String? ?? 'edit.mp4',
      localPath: json['localPath'] as String?,
      sizeBytes: json['sizeBytes'] is num
          ? (json['sizeBytes'] as num).toInt()
          : null,
      idempotencyKey: json['idempotencyKey'] as String?,
      editId: json['editId'] as String?,
      videoPath: json['videoPath'] as String?,
      phase: EditUploadJobPhase.values.firstWhere(
        (value) => value.name == json['phase'],
        orElse: () => EditUploadJobPhase.failed,
      ),
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      errorMessage: json['errorMessage'] as String?,
      failureReason: json['failureReason'] as String?,
    );
  }
}

/// App-wide Edit upload queue — YouTube/TikTok-style background publishing.
final class EditUploadManager extends ChangeNotifier
    with WidgetsBindingObserver {
  EditUploadManager({
    required EditsRepository repository,
    SharedPreferences? preferences,
    this.onNavigateToPublished,
    this.onPublishedWhileBackgrounded,
    this.onFailedWhileBackgrounded,
    this.shouldForceNavigateToPublished,
  }) : _repository = repository,
       _preferences = preferences;

  static const _queueKey = 'edit_upload_queue_v2';

  final EditsRepository _repository;
  SharedPreferences? _preferences;
  void Function(String editId)? onNavigateToPublished;
  void Function(String editId)? onPublishedWhileBackgrounded;
  void Function(String editId, String? message)? onFailedWhileBackgrounded;
  /// When false, show a soft "ready" offer instead of forcing feed navigation.
  bool Function(String editId)? shouldForceNavigateToPublished;

  final List<EditUploadJob> _jobs = <EditUploadJob>[];
  final Map<String, StreamSubscription<Result<Edit>>> _watches =
      <String, StreamSubscription<Result<Edit>>>{};
  var _pumping = false;
  var _restored = false;
  var _expanded = false;
  var _foreground = true;
  var _disposed = false;
  String? _highlightEditId;
  String? _cancelingEditId;
  String? _softPublishedOfferId;

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  List<EditUploadJob> get jobs => List.unmodifiable(_jobs);
  List<EditUploadJob> get visibleJobs => _jobs
      .where(
        (job) =>
            job.phase != EditUploadJobPhase.canceled &&
            (job.isActive ||
                job.isFailed ||
                job.phase == EditUploadJobPhase.needsReview ||
                // Keep published briefly until dismissed by consume/nav.
                job.phase == EditUploadJobPhase.published),
      )
      .toList(growable: false);

  bool get hasVisibleJobs => visibleJobs.isNotEmpty;
  bool get expanded => _expanded;
  String? get highlightEditId => _highlightEditId;
  String? get softPublishedOfferId => _softPublishedOfferId;

  String? consumeHighlightEditId() {
    final id = _highlightEditId;
    _highlightEditId = null;
    return id;
  }

  String? consumeSoftPublishedOffer() {
    final id = _softPublishedOfferId;
    _softPublishedOfferId = null;
    return id;
  }

  /// Accept a deferred soft offer — focuses the feed on [editId].
  void acceptSoftPublishedOffer(String editId) {
    _softPublishedOfferId = null;
    _highlightEditId = editId;
    _notify();
  }

  void setHighlightEditId(String editId) {
    _highlightEditId = editId;
    _notify();
  }

  EditUploadJob? get primaryJob {
    final visible = visibleJobs;
    if (visible.isEmpty) return null;
    return visible.firstWhere(
      (job) => job.isFailed,
      orElse: () => visible.firstWhere(
        (job) => job.isActive,
        orElse: () => visible.first,
      ),
    );
  }

  Future<SharedPreferences?> _prefs() async {
    try {
      return _preferences ??= await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  Future<void> attachLifecycle() async {
    WidgetsBinding.instance.addObserver(this);
    await restore();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) {
      unawaited(_reconcileActiveJobs());
    }
  }

  Future<void> restore() async {
    if (_restored) return;
    _restored = true;
    final prefs = await _prefs();
    final raw = prefs?.getString(_queueKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is! Map) continue;
            final job = EditUploadJob.fromJson(
              Map<String, dynamic>.from(item),
            );
            if (job.localId.isEmpty) continue;
            if (job.phase == EditUploadJobPhase.published ||
                job.phase == EditUploadJobPhase.canceled) {
              continue;
            }
            // Drop in-memory bytes across restarts — keep path/resume ids.
            job.bytes = null;
            if (job.phase == EditUploadJobPhase.uploading ||
                job.phase == EditUploadJobPhase.queued) {
              // Mid-upload was interrupted; mark failed so user can retry.
              if (job.editId == null ||
                  job.editId!.isEmpty ||
                  (job.localPath == null && job.bytes == null)) {
                job.phase = EditUploadJobPhase.failed;
                job.errorMessage =
                    'Upload interrupted. Your draft is saved — retry when ready.';
              } else {
                job.phase = EditUploadJobPhase.queued;
                job.progress = 0;
              }
            }
            _jobs.add(job);
            final editId = job.editId;
            if (editId != null &&
                editId.isNotEmpty &&
                (job.phase == EditUploadJobPhase.processing ||
                    job.phase == EditUploadJobPhase.failed ||
                    job.phase == EditUploadJobPhase.queued)) {
              _watchServer(job);
            }
          }
        }
      } catch (_) {
        // Corrupt queue — start clean.
      }
    }
    _notify();
    unawaited(_reconcileActiveJobs());
    unawaited(_pump());
  }

  Future<void> _persist() async {
    final prefs = await _prefs();
    final payload = _jobs
        .where((job) => job.phase != EditUploadJobPhase.canceled)
        .map((job) => job.toJson())
        .toList(growable: false);
    await prefs?.setString(_queueKey, jsonEncode(payload));
  }

  /// Enqueue a publish job and return immediately (non-blocking).
  Future<EditUploadJob> enqueue({
    required String caption,
    required String animeTag,
    required String contentType,
    required String fileName,
    String? localPath,
    List<int>? bytes,
    int? sizeBytes,
    String? idempotencyKey,
    String? resumeEditId,
    String? resumeVideoPath,
  }) async {
    await restore();
    final job = EditUploadJob(
      localId: 'local-${DateTime.now().microsecondsSinceEpoch}',
      caption: caption,
      animeTag: animeTag,
      contentType: contentType,
      fileName: fileName,
      localPath: localPath,
      bytes: bytes,
      sizeBytes: sizeBytes,
      idempotencyKey:
          idempotencyKey ??
          '${DateTime.now().millisecondsSinceEpoch}-$fileName',
      editId: resumeEditId,
      videoPath: resumeVideoPath,
      phase: EditUploadJobPhase.queued,
    );
    _jobs.insert(0, job);
    await _persist();
    _notify();
    unawaited(_pump());
    return job;
  }

  void setExpanded(bool value) {
    if (_expanded == value) return;
    _expanded = value;
    _notify();
  }

  void toggleExpanded() => setExpanded(!_expanded);

  Future<void> cancel(String localId) async {
    final job = _jobs.cast<EditUploadJob?>().firstWhere(
      (item) => item?.localId == localId,
      orElse: () => null,
    );
    if (job == null) return;
    if (job.phase == EditUploadJobPhase.uploading) {
      _cancelingEditId = job.editId;
      await _repository.cancelUpload();
      _cancelingEditId = null;
    }
    _watches.remove(localId)?.cancel();
    job.phase = EditUploadJobPhase.canceled;
    await _persist();
    _notify();
  }

  Future<void> retry(String localId) async {
    final job = _jobs.cast<EditUploadJob?>().firstWhere(
      (item) => item?.localId == localId,
      orElse: () => null,
    );
    if (job == null) return;
    job.errorMessage = null;
    job.failureReason = null;
    job.progress = 0;
    if (job.editId != null &&
        job.editId!.isNotEmpty &&
        (job.localPath == null && job.bytes == null)) {
      // Storage object may already exist — retry server processing only.
      job.phase = EditUploadJobPhase.processing;
      await _persist();
      _notify();
      final result = await _repository.retryProcessing(job.editId!);
        if (!result.isSuccess) {
          job.phase = EditUploadJobPhase.failed;
          job.errorMessage = result.failureOrNull?.message;
          await _persist();
          _notify();
          return;
        }
      _watchServer(job);
      return;
    }
    job.phase = EditUploadJobPhase.queued;
    await _persist();
    _notify();
    unawaited(_pump());
  }

  Future<void> dismiss(String localId) async {
    final index = _jobs.indexWhere((job) => job.localId == localId);
    if (index < 0) return;
    _watches.remove(localId)?.cancel();
    _jobs.removeAt(index);
    await _persist();
    _notify();
  }

  Future<void> deleteDraft(String localId) async {
    final job = _jobs.cast<EditUploadJob?>().firstWhere(
      (item) => item?.localId == localId,
      orElse: () => null,
    );
    if (job == null) return;
    final editId = job.editId;
    if (editId != null && editId.isNotEmpty) {
      await _repository.deleteEdit(editId);
    }
    await dismiss(localId);
  }

  Future<void> _pump() async {
    if (_pumping) return;
    _pumping = true;
    try {
      while (true) {
        final next = _jobs.cast<EditUploadJob?>().firstWhere(
          (job) => job?.phase == EditUploadJobPhase.queued,
          orElse: () => null,
        );
        if (next == null) break;
        await _runUpload(next);
      }
    } finally {
      _pumping = false;
    }
  }

  Future<void> _runUpload(EditUploadJob job) async {
    final hasSource =
        (job.localPath != null && job.localPath!.isNotEmpty) ||
        (job.bytes != null && job.bytes!.isNotEmpty);
    if (!hasSource) {
      job.phase = EditUploadJobPhase.failed;
      job.errorMessage =
          'Local video is missing. Choose the file again to retry.';
      await _persist();
      _notify();
      return;
    }

    job.phase = EditUploadJobPhase.uploading;
    job.progress = 0;
    await _persist();
    _notify();

    final source = job.localPath != null && job.localPath!.isNotEmpty
        ? EditUploadSource.file(job.localPath!)
        : EditUploadSource.memory(job.bytes!);

    final result = await _repository.uploadEdit(
      source: source,
      contentType: job.contentType,
      caption: job.caption,
      animeTag: job.animeTag,
      fileName: job.fileName,
      sizeBytes: job.sizeBytes,
      idempotencyKey: job.idempotencyKey,
      resumeEditId: job.editId,
      resumeVideoPath: job.videoPath,
      onStarted: (editId, path) {
        job.editId = editId;
        job.videoPath = path;
        unawaited(_persist());
        _notify();
      },
      onProgress: (value) {
        if (job.phase != EditUploadJobPhase.uploading) return;
        job.progress = value.clamp(0, 1);
        _notify();
      },
    );

    if (job.phase == EditUploadJobPhase.canceled) return;

    if (result.isSuccess) {
      final edit = result.valueOrNull!;
      job.editId = edit.id;
      _applyServerStatus(job, edit);
      await _persist();
      _notify();
      if (job.phase == EditUploadJobPhase.processing ||
          job.phase == EditUploadJobPhase.uploading) {
        job.phase = EditUploadJobPhase.processing;
        job.progress = 1;
        await _persist();
        _notify();
        _watchServer(job);
      }
    } else {
      final failure = result.failureOrNull!;
      if (failure is CancelledError ||
          (_cancelingEditId != null && _cancelingEditId == job.editId)) {
        job.phase = EditUploadJobPhase.canceled;
      } else {
        job.phase = EditUploadJobPhase.failed;
        job.errorMessage = failure.message;
      }
      await _persist();
      _notify();
    }
  }

  void _watchServer(EditUploadJob job) {
    final editId = job.editId;
    if (editId == null || editId.isEmpty) return;
    _watches[job.localId]?.cancel();
    _watches[job.localId] = _repository.watchEdit(editId).listen((result) {
      result.fold(
        onSuccess: (edit) {
          final before = job.phase;
          _applyServerStatus(job, edit);
          if (before != job.phase) {
            unawaited(_persist());
            _notify();
          }
        },
        onFailure: (_) {},
      );
    });
  }

  void _applyServerStatus(EditUploadJob job, Edit edit) {
    final before = job.phase;
    switch (edit.statusEnum) {
      case EditStatus.published:
        job.phase = EditUploadJobPhase.published;
        job.progress = 1;
        job.errorMessage = null;
        if (before != EditUploadJobPhase.published) {
          _onPublished(edit.id);
        }
      case EditStatus.needsReview:
        job.phase = EditUploadJobPhase.needsReview;
        job.progress = 1;
        job.errorMessage = edit.userFacingFailure;
        job.failureReason = edit.failureReason;
        if (before != EditUploadJobPhase.needsReview) {
          _onTerminalFailure(edit.id, edit.userFacingFailure);
        }
      case EditStatus.failed:
      case EditStatus.rejected:
        job.phase = EditUploadJobPhase.failed;
        job.errorMessage = edit.userFacingFailure;
        job.failureReason = edit.failureReason;
        if (before != EditUploadJobPhase.failed) {
          _onTerminalFailure(edit.id, edit.userFacingFailure);
        }
      case EditStatus.processing:
      case EditStatus.uploading:
        job.phase = EditUploadJobPhase.processing;
        job.progress = 1;
      case EditStatus.removed:
      case EditStatus.deleted:
        job.phase = EditUploadJobPhase.canceled;
    }
  }

  void _onPublished(String editId) {
    final force = shouldForceNavigateToPublished?.call(editId) ?? true;
    if (_foreground) {
      if (force) {
        _highlightEditId = editId;
        _softPublishedOfferId = null;
        onNavigateToPublished?.call(editId);
      } else {
        // Soft offer — keep watching current clip; highlight deferred until accept.
        _softPublishedOfferId = editId;
        onNavigateToPublished?.call(editId);
      }
    } else {
      _highlightEditId = editId;
      onPublishedWhileBackgrounded?.call(editId);
    }
    // Auto-dismiss published jobs after a short window so the bar clears.
    Future<void>.delayed(const Duration(seconds: 4), () async {
      final job = _jobs.cast<EditUploadJob?>().firstWhere(
        (item) =>
            item?.editId == editId &&
            item?.phase == EditUploadJobPhase.published,
        orElse: () => null,
      );
      if (job != null) await dismiss(job.localId);
    });
  }

  void _onTerminalFailure(String editId, String? message) {
    if (_foreground) return;
    onFailedWhileBackgrounded?.call(editId, message);
  }

  Future<void> _reconcileActiveJobs() async {
    if (_disposed) return;
    for (final job in List<EditUploadJob>.from(_jobs)) {
      if (_disposed) return;
      final editId = job.editId;
      if (editId == null || editId.isEmpty) continue;
      if (!job.isActive && !job.isFailed) continue;
      final result = await _repository.getEdit(editId);
      if (_disposed) return;
      result.fold(
        onSuccess: (edit) {
          _applyServerStatus(job, edit);
        },
        onFailure: (_) {},
      );
    }
    if (_disposed) return;
    await _persist();
    _notify();
    unawaited(_pump());
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    for (final sub in _watches.values) {
      unawaited(sub.cancel());
    }
    _watches.clear();
    super.dispose();
  }
}
