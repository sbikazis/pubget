import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../app/app_router.dart';
import '../../../core/theme/app_colors.dart';
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
        ..addAll(
          rules.map((item) => TextEditingController(text: '$item')),
        );
    }
    final character = draft['character'];
    if (character is Map) {
      _character = RoleplayCharacter.fromMap(Map<String, dynamic>.from(character));
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
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(copy.createTitle),
      ),
      body: SingleChildScrollView(
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
            PubgetBadge(label: copy.typeLabel(type)),
            const SizedBox(height: AppSpacing.sm),
            Text(copy.typeLockedHint, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.lg),
            _CoverPreview(
              name: _name.text,
              imageUrl: _imageUrl.text,
              coverUrl: _coverUrl.text,
            ),
            const SizedBox(height: AppSpacing.lg),
            PubgetTextField(
              key: const Key('group-create-image-url'),
              controller: _imageUrl,
              label: copy.avatar,
              hint: copy.imageUrl,
              onChanged: (_) => setState(_persist),
            ),
            const SizedBox(height: AppSpacing.sm),
            PubgetSecondaryButton(
              key: const Key('group-create-pick-avatar'),
              onPressed: _uploadingImage ? null : () => _pickImage(_imageUrl),
              semanticLabel: copy.pickImage,
              loading: _uploadingImage,
              child: Text(_uploadingImage ? copy.uploadingImage : copy.pickImage),
            ),
            const SizedBox(height: AppSpacing.md),
            PubgetTextField(
              key: const Key('group-create-cover-url'),
              controller: _coverUrl,
              label: copy.cover,
              hint: copy.imageUrl,
              onChanged: (_) => setState(_persist),
            ),
            const SizedBox(height: AppSpacing.sm),
            PubgetSecondaryButton(
              key: const Key('group-create-pick-cover'),
              onPressed: _uploadingImage ? null : () => _pickImage(_coverUrl),
              semanticLabel: copy.cover,
              child: Text(copy.cover),
            ),
            const SizedBox(height: AppSpacing.md),
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
            const SizedBox(height: AppSpacing.lg),
            Text(copy.rules, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _rules.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  final index = newIndex > oldIndex ? newIndex - 1 : newIndex;
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
            const SizedBox(height: AppSpacing.lg),
            SwitchListTile(
              key: const Key('group-create-join-policy'),
              value: _policy == JoinPolicy.open,
              onChanged: (value) {
                setState(
                  () => _policy = value ? JoinPolicy.open : JoinPolicy.approval,
                );
                _persist();
              },
              title: Text(_policy == JoinPolicy.open ? copy.joinOpen : copy.joinClosed),
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
              onPressed: _canConfirm && !provider.creating ? () => _create(provider) : null,
              semanticLabel: copy.confirm,
              loading: _submitting || provider.creating,
              child: Text(_submitting ? copy.publishing : copy.confirm),
            ),
          ],
        ],
        ),
      ),
    );
  }

  Future<void> _pickImage(TextEditingController target) async {
    final copy = GroupCopy.of(context);
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null || !mounted) return;
      final uid = context.read<AuthProvider>().currentUser?.id;
      if (uid == null || uid.isEmpty) {
        PubgetSnackbars.showError(context, copy.signInToUpload);
        return;
      }
      GroupImageUploader uploader;
      try {
        uploader = context.read<GroupImageUploader>();
      } on ProviderNotFoundException {
        PubgetSnackbars.showError(context, copy.imageUploadFailed);
        return;
      }
      setState(() => _uploadingImage = true);
      final bytes = await file.readAsBytes();
      final url = await uploader.uploadGroupImage(
        uid: uid,
        bytes: bytes,
        contentType: file.mimeType ?? 'image/jpeg',
        kind: identical(target, _coverUrl) ? 'cover' : 'avatar',
      );
      if (!mounted) return;
      if (!isRemoteHttpUrl(url)) {
        PubgetSnackbars.showError(context, copy.imageUploadFailed);
        return;
      }
      setState(() => target.text = url);
      _persist();
    } catch (_) {
      if (mounted) {
        PubgetSnackbars.showError(context, GroupCopy.of(context).imageUploadFailed);
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
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
    if (type == null || !_canConfirm || _submitting || provider.creating) return;
    setState(() => _submitting = true);
    final result = await provider.create(
      GroupDraft(
        name: _name.text,
        description: _description.text,
        type: type,
        animeId: type == GroupType.animeRoleplay ? _animeId : null,
        joinPolicy: _policy,
        isSearchable: true,
        rules: _rules.map((item) => item.text.trim()).where((item) => item.isNotEmpty).join('\n'),
        maxMembers: 100,
        imageUrl: isRemoteHttpUrl(_imageUrl.text) ? _imageUrl.text.trim() : '',
        coverUrl: isRemoteHttpUrl(_coverUrl.text) ? _coverUrl.text.trim() : null,
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

class _CoverPreview extends StatelessWidget {
  const _CoverPreview({
    required this.name,
    required this.imageUrl,
    required this.coverUrl,
  });

  final String name;
  final String imageUrl;
  final String coverUrl;

  @override
  Widget build(BuildContext context) {
    final copy = GroupCopy.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 168,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ColoredBox(color: AppColors.royalDusk),
            if (coverUrl.trim().isNotEmpty)
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
                  PubgetAvatar(
                    imageUrl: imageUrl.trim().isEmpty ? null : imageUrl.trim(),
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
