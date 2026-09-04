import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../models/group_models.dart';
import '../providers/group_provider.dart';
import '../repositories/group_repository.dart';

class CreateGroupWizardPage extends StatefulWidget {
  const CreateGroupWizardPage({super.key});

  @override
  State<CreateGroupWizardPage> createState() => _CreateGroupWizardPageState();
}

class _CreateGroupWizardPageState extends State<CreateGroupWizardPage> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _animeId = TextEditingController();
  final _rules = TextEditingController();
  int _step = 0;
  GroupType _type = GroupType.public;
  JoinPolicy _policy = JoinPolicy.open;
  bool _searchable = true;

  static const _lastStep = 4;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _animeId.dispose();
    _rules.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Create group')),
      body: Stepper(
        currentStep: _step,
        onStepTapped: (value) => setState(() => _step = value),
        onStepContinue: _step == _lastStep ? () => _create(provider) : _next,
        onStepCancel: _step == 0 ? null : () => setState(() => _step--),
        controlsBuilder: (context, details) => Padding(
          padding: const EdgeInsets.only(top: AppSpacing.lg),
          child: Row(
            children: <Widget>[
              PubgetPrimaryButton(
                onPressed: details.onStepContinue,
                semanticLabel: _step == _lastStep ? 'Create group' : 'Continue',
                loading: provider.state.name == 'loading',
                child: Text(_step == _lastStep ? 'Create group' : 'Continue'),
              ),
              if (details.onStepCancel != null) ...[
                const SizedBox(width: AppSpacing.sm),
                PubgetTextButton(
                  onPressed: details.onStepCancel,
                  semanticLabel: 'Back',
                  child: const Text('Back'),
                ),
              ],
            ],
          ),
        ),
        steps: <Step>[
          Step(
            title: const Text('Identity'),
            content: Column(
              children: <Widget>[
                PubgetTextField(controller: _name, label: 'Group name'),
                const SizedBox(height: AppSpacing.sm),
                PubgetTextArea(controller: _description, label: 'Description'),
              ],
            ),
          ),
          Step(
            title: const Text('Type'),
            content: Column(
              children: <Widget>[
                for (final type in GroupType.values)
                  RadioListTile<GroupType>(
                    value: type,
                    groupValue: _type,
                    onChanged: (value) => setState(() => _type = value!),
                    title: Text(_typeLabel(type)),
                    subtitle: Text(_typeHint(type)),
                  ),
                if (_type == GroupType.animeRoleplay)
                  PubgetTextField(
                    controller: _animeId,
                    label: 'Anime ID',
                  ),
              ],
            ),
          ),
          Step(
            title: const Text('Privacy and join'),
            content: Column(
              children: <Widget>[
                DropdownButtonFormField<JoinPolicy>(
                  value: _policy,
                  items: JoinPolicy.values
                      .map(
                        (policy) => DropdownMenuItem(
                          value: policy,
                          child: Text(_joinLabel(policy)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _policy = value!),
                  decoration: const InputDecoration(labelText: 'Join policy'),
                ),
                SwitchListTile(
                  value: _searchable,
                  onChanged: (value) => setState(() => _searchable = value),
                  title: const Text('Show in search and Discover'),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Rules'),
            content: PubgetTextArea(
              controller: _rules,
              label: 'Group rules',
              minLines: 5,
            ),
          ),
          Step(
            title: const Text('Review'),
            content: const PubgetCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Member capacity is set by your account entitlement '
                    '(100 by default, higher with a Store extension). '
                    'The server, not this screen, is the source of truth.',
                  ),
                  SizedBox(height: AppSpacing.md),
                  Text(
                    'Avatar, chat background, and welcome customization '
                    'are available from group settings after creation.',
                  ),
                  SizedBox(height: AppSpacing.md),
                  Text(
                    'Roles: Founder, Shogun, Commander, Captain, Sensei, '
                    'Senpai, and Member. Permissions stay group-scoped.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _typeLabel(GroupType type) => switch (type) {
    GroupType.public => 'Public group',
    GroupType.animeRoleplay => 'Anime roleplay',
    GroupType.openRoleplay => 'Open roleplay',
  };

  static String _typeHint(GroupType type) => switch (type) {
    GroupType.public => 'A community around shared interests.',
    GroupType.animeRoleplay => 'Roleplay with a chosen anime identity.',
    GroupType.openRoleplay => 'Roleplay without a required franchise.',
  };

  static String _joinLabel(JoinPolicy policy) => switch (policy) {
    JoinPolicy.open => 'Open join',
    JoinPolicy.approval => 'Request to join',
    JoinPolicy.inviteOnly => 'Invite only',
  };

  void _next() {
    if (_step == 0 && _name.text.trim().isEmpty) return;
    if (_step == 1 &&
        _type == GroupType.animeRoleplay &&
        _animeId.text.trim().isEmpty) {
      return;
    }
    setState(() => _step++);
  }

  Future<void> _create(GroupProvider provider) async {
    final result = await provider.create(
      GroupDraft(
        name: _name.text,
        description: _description.text,
        type: _type,
        animeId: _type == GroupType.animeRoleplay ? _animeId.text : null,
        joinPolicy: _policy,
        isSearchable: _searchable,
        rules: _rules.text,
        maxMembers: 100,
      ),
    );
    if (!mounted) return;
    if (result.isSuccess) {
      await AppNavigation.go(
        context,
        '/group?groupId=${result.valueOrNull!.id}',
      );
    }
  }
}
