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
        onStepContinue: _step == 4 ? () => _create(provider) : _next,
        onStepCancel: _step == 0 ? null : () => setState(() => _step--),
        controlsBuilder: (context, details) => Padding(
          padding: const EdgeInsets.only(top: AppSpacing.lg),
          child: Row(
            children: <Widget>[
              PubgetPrimaryButton(
                onPressed: details.onStepContinue,
                semanticLabel: _step == 4 ? 'Create group' : 'Continue',
                loading: provider.state.name == 'loading',
                child: Text(_step == 4 ? 'Create group' : 'Continue'),
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
            title: const Text('Basic identity'),
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
                    title: Text(type.name),
                  ),
                if (_type == GroupType.animeRoleplay)
                  PubgetTextField(controller: _animeId, label: 'Anime ID'),
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
            title: const Text('Customization'),
            content: const PubgetCard(
              child: Text(
                'Group image and chat background customization will be '
                'enabled after creation. Chat itself arrives in PROMPT 07.',
              ),
            ),
          ),
          Step(
            title: const Text('Permissions defaults'),
            content: Column(
              children: <Widget>[
                DropdownButtonFormField<JoinPolicy>(
                  value: _policy,
                  items: JoinPolicy.values
                      .map(
                        (policy) => DropdownMenuItem(
                          value: policy,
                          child: Text(policy.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _policy = value!),
                  decoration: const InputDecoration(labelText: 'Join policy'),
                ),
                SwitchListTile(
                  value: _searchable,
                  onChanged: (value) => setState(() => _searchable = value),
                  title: const Text('Show in search'),
                ),
                const PubgetCard(
                  child: Text(
                    'Founder, Shogun, Commander, Captain, Sensei, Senpai and '
                    'Member roles will be created with editable permission sets.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _next() {
    if (_step == 0 && _name.text.trim().isEmpty) return;
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
