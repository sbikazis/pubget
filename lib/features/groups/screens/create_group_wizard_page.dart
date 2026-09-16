import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../app/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../anime/models/anime_models.dart';
import '../../authentication/providers/auth_provider.dart';
import '../data/group_create_draft_store.dart';
import '../data/group_image_uploader.dart';
import '../l10n/group_copy.dart';
import '../models/group_models.dart';
import '../providers/group_provider.dart';
import '../repositories/group_repository.dart';
import 'group_anime_picker_page.dart';
import 'group_character_picker_page.dart';
import 'group_create_success_sheet.dart';
import 'group_type_sheet.dart';

class CreateGroupWizardPage extends StatefulWidget {
  const CreateGroupWizardPage({
    this.type,
    this.draftStore,
    super.key,
  });

  final GroupType? type;
  final GroupCreateDraftStore? draftStore;

  @override
  State<CreateGroupWizardPage> createState() => _CreateGroupWizardPageState();
}

class _CreateGroupWizardPageState extends State<CreateGroupWizardPage> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _imageUrl = TextEditingController();
  final _coverUrl = TextEditingController();
  final _rules = <TextEditingController>[TextEditingController()];
  late final GroupCreateDraftStore _store;
  GroupType? _type;
  JoinPolicy _policy = JoinPolicy.approval;
  String? _animeId;
  String? _animeTitle;
  RoleplayCharacter? _character;
  String? _idempotencyKey;
  bool _hydrated = false;
  bool _submitting = false;
  bool _uploadingImage = false;

  /// Last cropped image kept for retry without re-picking.
  Uint8List? _pendingAvatarBytes;
  String _pendingAvatarType = 'image/png';
  Uint8List? _pendingCoverBytes;
  String _pendingCoverType = 'image/png';
  String? _uploadError;
  bool _lastUploadWasCover = false;

  @override
  void initState() {
    super.initState();
    _type = widget.type;
    _store = widget.draftStore ?? GroupCreateDraftStore();
    _idempotencyKey =
        'create-${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(this)}';
    _name.addListener(_persist);
    _description.addListener(_persist);
    _imageUrl.addListener(_persist);
    _coverUrl.addListener(_persist);
    Future<void>.microtask(_restore);
  }

  @override
  void dispose() {
    for (final rule in _rules) {
      rule.dispose();
    }
    _name.dispose();
    _description.dispose();
    _imageUrl.dispose();
    _coverUrl.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final type = _type;
    if (type == null) return;
    final draft = await _store.load(type);
    if (!mounted || draft == null || _hydrated) return;
    _hydrated = true;
    _name.text = draft['name'] as String? ?? _name.text;
    _description.text = draft['description'] as String? ?? _description.text;
    _imageUrl.text = draft['imageUrl'] as String? ?? _imageUrl.text;
    _coverUrl.text = draft['coverUrl'] as String? ?? _coverUrl.text;
    if (!isRemoteHttpUrl(_imageUrl.text)) _imageUrl.clear();
    if (!isRemoteHttpUrl(_coverUrl.text)) _coverUrl.clear();
    _animeId = draft['animeId'] as String? ?? _animeId;
    _animeTitle = draft['animeTitle'] as String? ?? _animeTitle;
    _idempotencyKey = draft['idempotencyKey'] as String? ?? _idempotencyKey;
    final policy = draft['joinPolicy'] as String?;
    if (policy != null) {
      _policy = JoinPolicy.values.firstWhere(
        (value) => value.name == policy,
        orElse: () => JoinPolicy.approval,
      );
    }
    final rules = draft['rules'];
    if (rules is List && rules.isNotEmpty) {
      for (final controller in _rules) {
        controller.dispose();
      }
      _rules
        ..clear()
        ..addAll(rules.map((item) => TextEditingController(text: '$item')));
    }
    final character = draft['character'];
    if (character is Map) {
      _character =
          RoleplayCharacter.fromMap(Map<String, dynamic>.from(character));
    }
    setState(() {});
  }

  void _persist() {
    final type = _type;
    if (type == null) return;
    unawaited(
      _store.save(
        type: type,
        draft: <String, dynamic>{
          'name': _name.text,
          'description': _description.text,
          'imageUrl': _imageUrl.text,
          'coverUrl': _coverUrl.text,
          'joinPolicy': _policy.name,
          'animeId': _animeId,
          'animeTitle': _animeTitle,
          'idempotencyKey': _idempotencyKey,
          'rules': _rules.map((item) => item.text).toList(growable: false),
          if (_character != null) 'character': _character!.toMap(),
        },
      ),
    );
  }

  bool get _canConfirm {
    if (_type == null || _submitting || _uploadingImage) return false;
    if (!isRemoteHttpUrl(_imageUrl.text) || _name.text.trim().isEmpty) {
      return false;
    }
    if (_type == GroupType.animeRoleplay &&
        (_animeId == null || _animeId!.isEmpty || _character == null)) {
      return false;
    }
    if (_type == GroupType.openRoleplay && _character == null) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupProvider>();
    final copy = GroupCopy.of(context);
    final type = _type;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0714),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: AppBackButton.maybeOf(context),
        title: Text(copy.createTitle),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFF1A0F2E),
              Color(0xFF0B0714),
              Color(0xFF12081F),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (type == null)
                GroupTypeTiles(
                  onSelected: (value) {
                    setState(() => _type = value);
                    _restore();
                  },
                )
              else ...<Widget>[
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: PubgetBadge(
                    label: copy.typeLabel(type),
                    backgroundColor: AppColors.gold.withValues(alpha: 0.18),
                    foregroundColor: AppColors.gold,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  copy.typeLockedHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionCard(
                  title: copy.livePreview,
                  child: _CoverPreview(
                    name: _name.text,
                    imageUrl: _imageUrl.text,
                    coverUrl: _coverUrl.text,
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
                          isRemoteHttpUrl(_imageUrl.text)
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
                          isRemoteHttpUrl(_coverUrl.text)
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
                        controller: _imageUrl,
                        label: copy.avatar,
                        onChanged: (_) => setState(_persist),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      PubgetTextField(
                        key: const Key('group-create-cover-url'),
                        controller: _coverUrl,
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
                        controller: _name,
                        label: copy.name,
                        onChanged: (_) => setState(_persist),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      PubgetTextArea(
                        key: const Key('group-create-description'),
                        controller: _description,
                        label: copy.description,
                        onChanged: (_) => _persist(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _SectionCard(
                  title: copy.rulesSection,
                  child: Column(
                    children: <Widget>[
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _rules.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            final index =
                                newIndex > oldIndex ? newIndex - 1 : newIndex;
                            final item = _rules.removeAt(oldIndex);
                            _rules.insert(index, item);
                          });
                          _persist();
                        },
                        itemBuilder: (context, index) => Padding(
                          key: ValueKey(_rules[index]),
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: PubgetTextField(
                                  key: Key('group-create-rule-$index'),
                                  controller: _rules[index],
                                  label: '${copy.rules} ${index + 1}',
                                  onChanged: (_) => _persist(),
                                ),
                              ),
                              PubgetIconButton(
                                icon: Icons.delete_outline,
                                tooltip: copy.removeRule,
                                onPressed: _rules.length == 1
                                    ? null
                                    : () {
                                        setState(() {
                                          _rules.removeAt(index).dispose();
                                        });
                                        _persist();
                                      },
                              ),
                            ],
                          ),
                        ),
                      ),
                      PubgetTextButton(
                        key: const Key('group-create-add-rule'),
                        onPressed: () {
                          setState(() => _rules.add(TextEditingController()));
                          _persist();
                        },
                        semanticLabel: copy.addRule,
                        child: Text(copy.addRule),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _SectionCard(
                  title: copy.privacySection,
                  child: SwitchListTile(
                    key: const Key('group-create-join-policy'),
                    contentPadding: EdgeInsets.zero,
                    value: _policy == JoinPolicy.open,
                    activeColor: AppColors.gold,
                    onChanged: (value) {
                      setState(
                        () => _policy =
                            value ? JoinPolicy.open : JoinPolicy.approval,
                      );
                      _persist();
                    },
                    title: Text(
                      _policy == JoinPolicy.open
                          ? copy.joinOpen
                          : copy.joinClosed,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                if (type == GroupType.animeRoleplay) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  PubgetSecondaryButton(
                    key: const Key('group-create-pick-anime'),
                    onPressed: _pickAnime,
                    semanticLabel: copy.selectAnime,
                    child: Text(_animeTitle ?? copy.selectAnime),
                  ),
                ],
                if (type != GroupType.public &&
                    (type == GroupType.openRoleplay ||
                        (_animeId != null && _animeId!.isNotEmpty))) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  PubgetSecondaryButton(
                    key: const Key('group-create-pick-character'),
                    onPressed: _pickCharacter,
                    semanticLabel: copy.selectCharacter,
                    child: Text(_character?.name ?? copy.selectCharacter),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                PubgetPrimaryButton(
                  key: const Key('group-create-confirm'),
                  onPressed: _canConfirm && !provider.creating
                      ? () => _create(provider)
                      : null,
                  semanticLabel: copy.confirm,
                  loading: _submitting || provider.creating,
                  child: Text(_submitting ? copy.publishing : copy.confirm),
                ),
              ],
            ],
          ),
        ),
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
    final target = isCover ? _coverUrl : _imageUrl;
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

  Future<void> _pickAnime() async {
    final anime = await Navigator.of(context).push<Anime>(
      MaterialPageRoute(builder: (_) => const GroupAnimePickerPage()),
    );
    if (anime == null) return;
    setState(() {
      _animeId = anime.id;
      _animeTitle = anime.title;
      _character = null;
    });
    _persist();
  }

  Future<void> _pickCharacter() async {
    final character = await Navigator.of(context).push<RoleplayCharacter>(
      MaterialPageRoute(
        builder: (_) => GroupCharacterPickerPage(animeId: _animeId),
      ),
    );
    if (character == null) return;
    setState(() => _character = character);
    _persist();
  }

  Future<void> _create(GroupProvider provider) async {
    final type = _type;
    if (type == null || !_canConfirm || _submitting || provider.creating) {
      return;
    }
    setState(() => _submitting = true);
    final result = await provider.create(
      GroupDraft(
        name: _name.text,
        description: _description.text,
        type: type,
        animeId: type == GroupType.animeRoleplay ? _animeId : null,
        joinPolicy: _policy,
        isSearchable: true,
        rules: _rules
            .map((item) => item.text.trim())
            .where((item) => item.isNotEmpty)
            .join('\n'),
        maxMembers: 100,
        imageUrl: isRemoteHttpUrl(_imageUrl.text) ? _imageUrl.text.trim() : '',
        coverUrl:
            isRemoteHttpUrl(_coverUrl.text) ? _coverUrl.text.trim() : null,
        character: type == GroupType.public ? null : _character,
        idempotencyKey: _idempotencyKey,
      ),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!result.isSuccess) {
      PubgetSnackbars.showError(
        context,
        result.failureOrNull?.message ?? GroupCopy.of(context).retry,
      );
      return;
    }
    final group = result.valueOrNull!;
    await _store.clear(type);
    if (!mounted) return;
    await GroupCreateSuccessSheet.show(
      context,
      groupId: group.id,
      groupName: group.name,
    );
    if (!mounted) return;
    await AppNavigation.go(context, '/group?groupId=${group.id}');
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
      // Matches ImageCropAspect.cover (16:9) so crops aren't stretched.
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
