import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/pubget_design_system.dart';
import '../../../../authentication/providers/auth_provider.dart';
import '../../../data/group_create_draft_store.dart';
import '../../../data/group_image_uploader.dart';
import '../../../l10n/group_copy.dart';
import '../../../models/group_models.dart';

class Step1Identity extends StatefulWidget {
  const Step1Identity({
    required this.nameController,
    required this.descriptionController,
    required this.imageUrlController,
    required this.coverUrlController,
    required this.onChanged,
    required this.draftStore,
    required this.type,
    super.key,
  });

  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final TextEditingController imageUrlController;
  final TextEditingController coverUrlController;
  final VoidCallback onChanged;
  final GroupCreateDraftStore draftStore;
  final GroupType? type;

  @override
  State<Step1Identity> createState() => _Step1IdentityState();
}

class _Step1IdentityState extends State<Step1Identity> {
  Uint8List? _pendingAvatarBytes;
  String _pendingAvatarType = 'image/png';
  Uint8List? _pendingCoverBytes;
  String _pendingCoverType = 'image/png';
  String? _uploadError;
  bool _lastUploadWasCover = false;
  bool _uploadingImage = false;
  bool _hydrated = false;
  late String _idempotencyKey;

  @override
  void initState() {
    super.initState();
    _idempotencyKey =
        'create-${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(this)}';
    widget.nameController.addListener(widget.onChanged);
    widget.descriptionController.addListener(widget.onChanged);
    widget.imageUrlController.addListener(widget.onChanged);
    widget.coverUrlController.addListener(widget.onChanged);
    Future<void>.microtask(_restore);
  }

  @override
  void dispose() {
    widget.nameController.removeListener(widget.onChanged);
    widget.descriptionController.removeListener(widget.onChanged);
    widget.imageUrlController.removeListener(widget.onChanged);
    widget.coverUrlController.removeListener(widget.onChanged);
    super.dispose();
  }

  Future<void> _restore() async {
    final type = widget.type;
    if (type == null) return;
    final draft = await widget.draftStore.load(type);
    if (!mounted || draft == null || _hydrated) return;
    _hydrated = true;
    widget.nameController.text = draft['name'] as String? ?? widget.nameController.text;
    widget.descriptionController.text = draft['description'] as String? ?? widget.descriptionController.text;
    widget.imageUrlController.text = draft['imageUrl'] as String? ?? widget.imageUrlController.text;
    widget.coverUrlController.text = draft['coverUrl'] as String? ?? widget.coverUrlController.text;
    if (!isRemoteHttpUrl(widget.imageUrlController.text)) widget.imageUrlController.clear();
    if (!isRemoteHttpUrl(widget.coverUrlController.text)) widget.coverUrlController.clear();
    _idempotencyKey = draft['idempotencyKey'] as String? ?? _idempotencyKey;
    setState(() {});
  }

  void _persist() {
    final type = widget.type;
    if (type == null) return;
    unawaited(
      widget.draftStore.save(
        type: type,
        draft: <String, dynamic>{
          'name': widget.nameController.text,
          'description': widget.descriptionController.text,
          'imageUrl': widget.imageUrlController.text,
          'coverUrl': widget.coverUrlController.text,
          'idempotencyKey': _idempotencyKey,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = GroupCopy.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _SectionCard(
            title: copy.livePreview,
            child: _CoverPreview(
              name: widget.nameController.text,
              imageUrl: widget.imageUrlController.text,
              coverUrl: widget.coverUrlController.text,
              pendingAvatar: _pendingAvatarBytes,
              pendingCover: _pendingCoverBytes,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SectionCard(
            title: copy.photosSection,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                PubgetSecondaryButton(
                  key: const Key('group-create-pick-avatar'),
                  onPressed: _uploadingImage
                      ? null
                      : () => _pickImage(isCover: false),
                  semanticLabel: copy.pickImage,
                  loading: _uploadingImage && !_lastUploadWasCover,
                  leadingIcon: Icons.account_circle_outlined,
                  child: Text(
                    isRemoteHttpUrl(widget.imageUrlController.text)
                        ? copy.imageReady
                        : copy.avatar,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                PubgetSecondaryButton(
                  key: const Key('group-create-pick-cover'),
                  onPressed: _uploadingImage
                      ? null
                      : () => _pickImage(isCover: true),
                  semanticLabel: copy.cover,
                  loading: _uploadingImage && _lastUploadWasCover,
                  leadingIcon: Icons.photo_outlined,
                  child: Text(
                    isRemoteHttpUrl(widget.coverUrlController.text)
                        ? copy.imageReady
                        : copy.cover,
                  ),
                ),
                if (_uploadError != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _uploadError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: PubgetPrimaryButton(
                          onPressed: _uploadingImage ? null : _retryUpload,
                          semanticLabel: copy.retryImageUpload,
                          child: Text(copy.retryImageUpload),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: PubgetSecondaryButton(
                          onPressed: _uploadingImage
                              ? null
                              : () => _pickImage(
                                    isCover: _lastUploadWasCover,
                                  ),
                          semanticLabel: copy.replaceImage,
                          child: Text(copy.replaceImage),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Text(
                  copy.pasteImageUrl,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                PubgetTextField(
                  key: const Key('group-create-image-url'),
                  controller: widget.imageUrlController,
                  label: copy.avatar,
                  onChanged: (_) => setState(_persist),
                ),
                const SizedBox(height: AppSpacing.sm),
                PubgetTextField(
                  key: const Key('group-create-cover-url'),
                  controller: widget.coverUrlController,
                  label: copy.cover,
                  onChanged: (_) => setState(_persist),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SectionCard(
            title: copy.basicsSection,
            child: Column(
              children: <Widget>[
                PubgetTextField(
                  key: const Key('group-create-name'),
                  controller: widget.nameController,
                  label: copy.name,
                  onChanged: (_) => setState(_persist),
                ),
                const SizedBox(height: AppSpacing.sm),
                PubgetTextArea(
                  key: const Key('group-create-description'),
                  controller: widget.descriptionController,
                  label: copy.description,
                  onChanged: (_) => _persist(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage({required bool isCover}) async {
    try {
      final cropped = await pickAndCropImage(
        context,
        aspect: isCover ? ImageCropAspect.cover : ImageCropAspect.avatar,
      );
      if (cropped == null || !mounted) return;
      if (isCover) {
        _pendingCoverBytes = cropped.bytes;
        _pendingCoverType = cropped.contentType;
      } else {
        _pendingAvatarBytes = cropped.bytes;
        _pendingAvatarType = cropped.contentType;
      }
      _lastUploadWasCover = isCover;
      setState(() {
        _uploadError = null;
      });
      await _uploadPending(isCover: isCover);
    } on Object catch (error, stack) {
      debugPrint('Group image pick/crop failed: $error\n$stack');
      if (mounted) {
        setState(() {
          _uploadError = error.toString();
          _lastUploadWasCover = isCover;
        });
      }
    }
  }

  Future<void> _retryUpload() => _uploadPending(isCover: _lastUploadWasCover);

  Future<void> _uploadPending({required bool isCover}) async {
    final copy = GroupCopy.of(context);
    final bytes = isCover ? _pendingCoverBytes : _pendingAvatarBytes;
    final contentType = isCover ? _pendingCoverType : _pendingAvatarType;
    final target = isCover ? widget.coverUrlController : widget.imageUrlController;
    if (bytes == null || bytes.isEmpty) {
      setState(() {
        _uploadError = copy.imageEmpty;
        _lastUploadWasCover = isCover;
      });
      return;
    }
    final uid = context.read<AuthProvider>().currentUser?.id;
    if (uid == null || uid.isEmpty) {
      setState(() => _uploadError = copy.signInToUpload);
      return;
    }
    GroupImageUploader uploader;
    try {
      uploader = context.read<GroupImageUploader>();
    } on ProviderNotFoundException {
      setState(() => _uploadError = copy.imageUploadFailed);
      return;
    }
    setState(() {
      _uploadingImage = true;
      _uploadError = null;
      _lastUploadWasCover = isCover;
    });
    try {
      final url = await uploader.uploadGroupImage(
        uid: uid,
        bytes: bytes,
        contentType: contentType,
        kind: isCover ? 'cover' : 'avatar',
      );
      if (!mounted) return;
      if (!isRemoteHttpUrl(url)) {
        setState(() {
          _uploadError = copy.uploadErrorMessage(
            const GroupImageUploadException(
              'Upload did not return a download URL.',
              code: 'missing-url',
            ),
          );
          _uploadingImage = false;
        });
        return;
      }
      setState(() {
        target.text = url;
        _uploadingImage = false;
        _uploadError = null;
      });
      _persist();
    } on GroupImageUploadException catch (error, stack) {
      debugPrint('Group image upload failed: $error\n$stack');
      if (!mounted) return;
      setState(() {
        _uploadingImage = false;
        _uploadError = copy.uploadErrorMessage(error);
      });
    } on Object catch (error, stack) {
      debugPrint('Group image upload failed: $error\n$stack');
      if (!mounted) return;
      setState(() {
        _uploadingImage = false;
        _uploadError = copy.uploadErrorMessage(error);
      });
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.royalPurple.withValues(alpha: 0.35),
            const Color(0xFF160B24),
          ],
        ),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _CoverPreview extends StatelessWidget {
  const _CoverPreview({
    required this.name,
    required this.imageUrl,
    required this.coverUrl,
    this.pendingAvatar,
    this.pendingCover,
  });

  final String name;
  final String imageUrl;
  final String coverUrl;
  final Uint8List? pendingAvatar;
  final Uint8List? pendingCover;

  @override
  Widget build(BuildContext context) {
    final copy = GroupCopy.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const ColoredBox(color: AppColors.royalDusk),
            if (pendingCover != null)
              Image.memory(pendingCover!, fit: BoxFit.cover)
            else if (coverUrl.trim().isNotEmpty)
              AppImageLoader(imageUrl: coverUrl.trim(), fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0x00140C22), Color(0xCC140C22)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  if (pendingAvatar != null)
                    CircleAvatar(
                      radius: 36,
                      backgroundImage: MemoryImage(pendingAvatar!),
                    )
                  else
                    PubgetAvatar(
                      imageUrl:
                          imageUrl.trim().isEmpty ? null : imageUrl.trim(),
                      name: name.isEmpty ? copy.avatar : name,
                      size: PubgetAvatarSize.large,
                    ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      name.isEmpty ? copy.coverPreview : name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}