import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../models/group_models.dart';
import '../providers/group_provider.dart';
import '../repositories/group_repository.dart';

class GroupSettingsPage extends StatefulWidget {
  const GroupSettingsPage({required this.groupId, super.key});

  final String groupId;

  @override
  State<GroupSettingsPage> createState() => _GroupSettingsPageState();
}

class _GroupSettingsPageState extends State<GroupSettingsPage> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _rules = TextEditingController();
  JoinPolicy _joinPolicy = JoinPolicy.open;
  bool _isSearchable = true;
  var _hydratedGroupId = '';
  var _requestedLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requestedLoad) return;
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) return;
    _requestedLoad = true;
    final provider = context.read<GroupProvider>();
    Future<void>.microtask(
      () => provider.load(groupId: widget.groupId, userId: userId),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _rules.dispose();
    super.dispose();
  }

  void _hydrate(Group group) {
    if (_hydratedGroupId == group.id) return;
    _hydratedGroupId = group.id;
    _name.text = group.name;
    _description.text = group.description;
    _rules.text = group.rules;
    _joinPolicy = group.joinPolicy;
    _isSearchable = group.isSearchable;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupProvider>();
    final group = provider.group;
    if (group != null && group.id == widget.groupId) {
      _hydrate(group);
    }
    final allowed = provider.canManageSettings && group?.id == widget.groupId;
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: const Text('Group settings')),
      body: PubgetLoadingStateView(
        state: provider.state,
        onRetry: () => _reload(context),
        empty: const PubgetEmptyState(title: 'Group unavailable'),
        error: PubgetErrorState(
          message: provider.failure?.message ?? 'Settings could not load.',
          onRetry: () => _reload(context),
        ),
        offline: PubgetOfflineState(onRetry: () => _reload(context)),
        child: !allowed
            ? const PubgetEmptyState(
                title: 'You cannot manage group settings',
                message:
                    'Only MIKADO or a role with manageSettings can '
                    'edit these fields.',
                icon: Icons.lock_outline,
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: <Widget>[
                  PubgetTextField(
                    key: const Key('group-settings-name'),
                    controller: _name,
                    label: 'Group name',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PubgetTextArea(
                    key: const Key('group-settings-description'),
                    controller: _description,
                    label: 'Description',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PubgetTextArea(
                    key: const Key('group-settings-rules'),
                    controller: _rules,
                    label: 'Rules',
                    minLines: 5,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<JoinPolicy>(
                    key: const Key('group-settings-join-policy'),
                    value: _joinPolicy,
                    items: JoinPolicy.values
                        .map(
                          (policy) => DropdownMenuItem(
                            value: policy,
                            child: Text(groupJoinPolicyLabel(policy)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _joinPolicy = value);
                    },
                    decoration: const InputDecoration(labelText: 'Join policy'),
                  ),
                  SwitchListTile(
                    key: const Key('group-settings-searchable'),
                    value: _isSearchable,
                    onChanged: (value) => setState(() => _isSearchable = value),
                    title: const Text('Show in search and Discover'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PubgetPrimaryButton(
                    key: const Key('group-settings-save'),
                    onPressed: provider.state == LoadingState.refreshing
                        ? null
                        : () => _save(provider),
                    semanticLabel: 'Save group settings',
                    loading: provider.state == LoadingState.refreshing,
                    child: const Text('Save settings'),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _reload(BuildContext context) async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) return;
    await context.read<GroupProvider>().load(
      groupId: widget.groupId,
      userId: userId,
    );
  }

  Future<void> _save(GroupProvider provider) async {
    await provider.updateSettings(
      groupId: widget.groupId,
      settings: GroupSettingsUpdate(
        name: _name.text,
        description: _description.text,
        rules: _rules.text,
        joinPolicy: _joinPolicy,
        isSearchable: _isSearchable,
      ),
    );
  }
}
