import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../l10n/group_copy.dart';
import '../models/group_models.dart';
import '../providers/group_provider.dart';
import 'group_character_picker_page.dart';

Future<bool> showGroupJoinSheet(
  BuildContext context, {
  required Group group,
  required String userId,
}) async {
  final result = await PubgetBottomSheet.show<bool>(
    context,
    title: group.joinPolicy == JoinPolicy.approval
        ? GroupCopy.of(context).request
        : GroupCopy.of(context).join,
    isScrollControlled: true,
    child: _JoinForm(group: group, userId: userId),
  );
  return result == true;
}

class _JoinForm extends StatefulWidget {
  const _JoinForm({required this.group, required this.userId});

  final Group group;
  final String userId;

  @override
  State<_JoinForm> createState() => _JoinFormState();
}

class _JoinFormState extends State<_JoinForm> {
  final _invitedBy = TextEditingController();
  final _reason = TextEditingController();
  final _customImage = TextEditingController();
  RoleplayCharacter? _character;
  bool _accepted = false;
  bool _useCustomImage = false;
  bool _submitting = false;

  bool get _isRoleplay => widget.group.type != GroupType.public;

  @override
  void dispose() {
    _invitedBy.dispose();
    _reason.dispose();
    _customImage.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (!_accepted || _submitting) return false;
    if (_isRoleplay && _character == null) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final copy = GroupCopy.of(context);
    final provider = context.watch<GroupProvider>();
    final loading = provider.state == LoadingState.loading || _submitting;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (widget.group.rules.isNotEmpty) ...<Widget>[
            Text(copy.rules, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(widget.group.rules),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (_isRoleplay) ...<Widget>[
            PubgetSecondaryButton(
              key: const Key('group-join-pick-character'),
              onPressed: loading ? null : () => _pickCharacter(provider),
              semanticLabel: copy.selectCharacter,
              child: Text(
                _character?.name ?? copy.selectCharacter,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            PubgetTextArea(
              key: const Key('group-join-reason'),
              controller: _reason,
              label: copy.characterReason,
            ),
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              key: const Key('group-join-custom-image'),
              value: _useCustomImage,
              onChanged: (value) => setState(() => _useCustomImage = value),
              title: Text(
                _useCustomImage ? copy.useCustomImage : copy.useDefaultImage,
              ),
            ),
            if (_useCustomImage)
              PubgetTextField(
                key: const Key('group-join-custom-image-url'),
                controller: _customImage,
                label: copy.imageUrl,
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
          PubgetTextField(
            key: const Key('group-join-invited-by'),
            controller: _invitedBy,
            label: copy.invitedBy,
          ),
          CheckboxListTile(
            key: const Key('group-join-accept-rules'),
            value: _accepted,
            onChanged: (value) => setState(() => _accepted = value ?? false),
            title: Text(copy.acceptRules),
          ),
          const SizedBox(height: AppSpacing.md),
          PubgetPrimaryButton(
            key: const Key('group-join-confirm'),
            onPressed: _canSubmit && !loading ? _submit : null,
            semanticLabel: copy.save,
            loading: loading,
            child: Text(loading ? copy.working : copy.save),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCharacter(GroupProvider provider) async {
    final reserved = await provider.loadReserved(widget.group.id);
    if (!mounted) return;
    final selected = await Navigator.of(context).push<RoleplayCharacter>(
      MaterialPageRoute(
        builder: (context) => GroupCharacterPickerPage(
          animeId: widget.group.animeId,
          reservedKeys: reserved.map((item) => item.key).toSet(),
        ),
      ),
    );
    if (selected != null) setState(() => _character = selected);
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);
    final provider = context.read<GroupProvider>();
    final copy = GroupCopy.of(context);
    var character = _character;
    if (character != null && _useCustomImage && _customImage.text.trim().isNotEmpty) {
      character = RoleplayCharacter(
        key: character.key,
        name: character.name,
        avatarUrl: _customImage.text.trim(),
      );
    }
    final payload = GroupJoinPayload(
      invitedBy: _invitedBy.text,
      acceptedRules: _accepted,
      character: character,
      characterReason: _reason.text,
    );
    final approval = widget.group.joinPolicy == JoinPolicy.approval;
    final result = approval
        ? await provider.requestToJoin(widget.group.id, join: payload)
        : await provider.join(
            widget.group.id,
            userId: widget.userId,
            join: payload,
          );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result.isSuccess) {
      Navigator.pop(context, true);
      return;
    }
    final message = result.failureOrNull?.message ?? copy.retry;
    PubgetSnackbars.showError(context, message);
  }
}
