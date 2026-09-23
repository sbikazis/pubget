import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../app/app_back_button.dart';
import '../../../../../app/app_router.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/pubget_design_system.dart';
import '../../../data/group_create_draft_store.dart';
import '../../../data/group_image_uploader.dart';
import '../../../l10n/group_copy.dart';
import '../../../models/group_models.dart';
import '../../../providers/group_provider.dart';
import '../../../repositories/group_repository.dart';
import '../../../screens/group_anime_picker_page.dart';
import '../../../screens/group_character_picker_page.dart';
import '../../../screens/group_create_success_sheet.dart';
import '../../../../anime/models/anime_models.dart';
import 'step1_identity.dart';
import 'step2_type.dart';
import 'step3_rules.dart';
import 'step4_customization.dart';
import 'step5_permissions.dart';
import 'step6_preview.dart';
import 'step7_publish.dart';

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
  late final PageController _pageController;
  int _currentStep = 0;
  
  // Controllers
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _imageUrl = TextEditingController();
  final _coverUrl = TextEditingController();
  final _maxMembers = TextEditingController();
  final _welcomeMessage = TextEditingController();
  final _chatBackgroundUrl = TextEditingController();
  final _rules = <TextEditingController>[TextEditingController()];
  
  // State
  GroupType? _type;
  JoinPolicy _policy = JoinPolicy.inviteOnly; // Default per spec
  String? _animeId;
  String? _animeTitle;
  RoleplayCharacter? _character;
  String? _idempotencyKey;
  late final GroupCreateDraftStore _store;
  bool _submitting = false;
  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _type = widget.type;
    _store = widget.draftStore ?? GroupCreateDraftStore();
    _idempotencyKey =
        'create-${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(this)}';
    
    // Add listeners
    _name.addListener(_persist);
    _description.addListener(_persist);
    _imageUrl.addListener(_persist);
    _coverUrl.addListener(_persist);
    _maxMembers.addListener(_persist);
    _welcomeMessage.addListener(_persist);
    _chatBackgroundUrl.addListener(_persist);
    
    // Initialize max members
    _maxMembers.text = '100';
    
    Future<void>.microtask(_restore);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _name.dispose();
    _description.dispose();
    _imageUrl.dispose();
    _coverUrl.dispose();
    _maxMembers.dispose();
    _welcomeMessage.dispose();
    _chatBackgroundUrl.dispose();
    for (final controller in _rules) {
      controller.dispose();
    }
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
    _welcomeMessage.text = draft['welcomeMessage'] as String? ?? _welcomeMessage.text;
    _chatBackgroundUrl.text = draft['chatBackgroundUrl'] as String? ?? _chatBackgroundUrl.text;
    _maxMembers.text = (draft['maxMembers'] as int? ?? 100).toString();
    
    if (!isRemoteHttpUrl(_imageUrl.text)) _imageUrl.clear();
    if (!isRemoteHttpUrl(_coverUrl.text)) _coverUrl.clear();
    
    _animeId = draft['animeId'] as String? ?? _animeId;
    _animeTitle = draft['animeTitle'] as String? ?? _animeTitle;
    _idempotencyKey = draft['idempotencyKey'] as String? ?? _idempotencyKey;
    
    final policy = draft['joinPolicy'] as String?;
    if (policy != null) {
      _policy = JoinPolicy.values.firstWhere(
        (value) => value.name == policy,
        orElse: () => JoinPolicy.inviteOnly,
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
          'welcomeMessage': _welcomeMessage.text,
          'chatBackgroundUrl': _chatBackgroundUrl.text,
          'maxMembers': int.tryParse(_maxMembers.text) ?? 100,
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

  void _onInputChanged() {
    setState(() {});
    _persist();
  }

  void _nextStep() {
    if (_canProceed) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  bool get _canProceed {
    switch (_currentStep) {
      case 0: // Step 1: Identity
        return _name.text.trim().isNotEmpty && isRemoteHttpUrl(_imageUrl.text);
      case 1: // Step 2: Type
        if (_type == null) return false;
        if (_type == GroupType.animeRoleplay) {
          return _animeId != null && _animeId!.isNotEmpty && _character != null;
        }
        if (_type == GroupType.openRoleplay) return _character != null;
        return true;
      case 2: // Step 3: Rules
        final maxMembers = int.tryParse(_maxMembers.text) ?? 0;
        return maxMembers >= 2 && maxMembers <= 500;
      case 3: // Step 4: Customization
        return true; // Optional fields
      case 4: // Step 5: Permissions
        return true; // View only
      case 5: // Step 6: Preview
        return true;
      case 6: // Step 7: Publish
        return _canPublish;
      default:
        return false;
    }
  }

  bool get _canPublish {
    if (_type == null) return false;
    if (_name.text.trim().isEmpty) return false;
    if (!isRemoteHttpUrl(_imageUrl.text)) return false;
    final maxMembers = int.tryParse(_maxMembers.text) ?? 0;
    if (maxMembers < 2 || maxMembers > 500) return false;
    if (_type == GroupType.animeRoleplay &&
        (_animeId == null || _animeId!.isEmpty || _character == null)) {
      return false;
    }
    if (_type == GroupType.openRoleplay && _character == null) return false;
    return true;
  }

  Future<void> _createGroup(GroupProvider provider) async {
    if (!_canPublish || _submitting || provider.creating) return;
    setState(() => _submitting = true);
    
    final maxMembers = int.tryParse(_maxMembers.text) ?? 100;
    
    final result = await provider.create(
      GroupDraft(
        name: _name.text,
        description: _description.text,
        type: _type!,
        animeId: _type == GroupType.animeRoleplay ? _animeId : null,
        joinPolicy: _policy,
        isSearchable: true,
        rules: _rules
            .map((item) => item.text.trim())
            .where((item) => item.isNotEmpty)
            .join('\n'),
        maxMembers: maxMembers,
        imageUrl: isRemoteHttpUrl(_imageUrl.text) ? _imageUrl.text.trim() : '',
        coverUrl:
            isRemoteHttpUrl(_coverUrl.text) ? _coverUrl.text.trim() : null,
        character: _type == GroupType.public ? null : _character,
        idempotencyKey: _idempotencyKey,
        welcomeMessage: _welcomeMessage.text.trim().isEmpty ? null : _welcomeMessage.text.trim(),
        chatBackgroundUrl: _chatBackgroundUrl.text.trim().isEmpty ? null : _chatBackgroundUrl.text.trim(),
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
    await _store.clear(_type!);
    
    if (!mounted) return;
    await GroupCreateSuccessSheet.show(
      context,
      groupId: group.id,
      groupName: group.name,
    );
    
    if (!mounted) return;
    await AppNavigation.go(context, '/group?groupId=${group.id}');
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupProvider>();
    final copy = GroupCopy.of(context);
    
    final steps = <_WizardStep>[
      _WizardStep(
        title: copy.step1Title,
        child: Step1Identity(
          nameController: _name,
          descriptionController: _description,
          imageUrlController: _imageUrl,
          coverUrlController: _coverUrl,
          onChanged: _onInputChanged,
          draftStore: _store,
          type: _type,
        ),
      ),
      _WizardStep(
        title: copy.step2Title,
        child: Step2Type(
          onSelected: (type) {
            setState(() {
              _type = type;
              _character = null; // Reset character when type changes
            });
            _persist();
          },
          currentType: _type,
          animeTitle: _animeTitle,
          characterName: _character?.name,
          onPickAnime: _pickAnime,
          onPickCharacter: _pickCharacter,
        ),
      ),
      _WizardStep(
        title: copy.step3Title,
        child: Step3Rules(
          joinPolicy: _policy,
          onJoinPolicyChanged: (policy) {
            setState(() => _policy = policy);
            _persist();
          },
          maxMembersController: _maxMembers,
          rulesControllers: _rules,
          onRulesChanged: _onInputChanged,
          onAddRule: () {
            setState(() => _rules.add(TextEditingController()));
            _persist();
          },
          onRemoveRule: (index) {
            setState(() {
              _rules.removeAt(index).dispose();
            });
            _persist();
          },
          onReorderRules: (oldIndex, newIndex) {
            setState(() {
              final index = newIndex > oldIndex ? newIndex - 1 : newIndex;
              final item = _rules.removeAt(oldIndex);
              _rules.insert(index, item);
            });
            _persist();
          },
          maxMembersLimit: 500, // Will be updated from user entitlements later
        ),
      ),
      _WizardStep(
        title: copy.step4Title,
        child: Step4Customization(
          welcomeMessageController: _welcomeMessage,
          chatBackgroundController: _chatBackgroundUrl,
          onChanged: _onInputChanged,
        ),
      ),
      _WizardStep(
        title: copy.step5Title,
        child: Step5Permissions(
          groupType: _type ?? GroupType.public,
        ),
      ),
      _WizardStep(
        title: copy.step6Title,
        child: Step6Preview(
          name: _name.text,
          description: _description.text,
          type: _type,
          animeId: _animeId,
          animeTitle: _animeTitle,
          joinPolicy: _policy,
          maxMembers: int.tryParse(_maxMembers.text) ?? 100,
          rules: _rules
              .map((item) => item.text.trim())
              .where((item) => item.isNotEmpty)
              .join('\n'),
          welcomeMessage: _welcomeMessage.text,
          chatBackgroundUrl: _chatBackgroundUrl.text,
          imageUrl: _imageUrl.text,
          coverUrl: _coverUrl.text,
          character: _character,
        ),
      ),
      _WizardStep(
        title: copy.step7Title,
        child: Step7Publish(
          onPublish: () => _createGroup(provider),
          isSubmitting: _submitting || provider.creating,
          canPublish: _canPublish,
          name: _name.text,
          type: _type,
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0B0714),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: _currentStep > 0
            ? AppBackButton.maybeOf(context)
            : null,
        title: Text(copy.createTitle),
        actions: [
          if (_currentStep > 0 && _currentStep < 6)
            TextButton(
              onPressed: _previousStep,
              child: Text(copy.back, style: const TextStyle(color: AppColors.gold)),
            ),
        ],
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
        child: Column(
          children: [
            // Step indicator
            _StepIndicator(
              currentStep: _currentStep,
              steps: steps.map((s) => s.title).toList(),
            ),
            // Step content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentStep = index);
                },
                children: steps.map((step) => step.child).toList(),
              ),
            ),
            // Navigation buttons
            if (_currentStep < 6)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    if (_currentStep > 0)
                      Expanded(
                        child: PubgetSecondaryButton(
                          key: const Key('group-create-back'),
                          onPressed: _previousStep,
                          semanticLabel: copy.back,
                          child: Text(copy.back),
                        ),
                      ),
                    if (_currentStep > 0) const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: PubgetPrimaryButton(
                        key: const Key('group-create-next'),
                        onPressed: _canProceed ? _nextStep : null,
                        semanticLabel:
                            _currentStep == 5 ? copy.review : copy.next,
                        loading: _submitting && _currentStep == 6,
                        child: Text(_currentStep == 5 ? copy.review : copy.next),
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

class _WizardStep {
  const _WizardStep({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({
    required this.currentStep,
    required this.steps,
  });

  final int currentStep;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: List.generate(steps.length, (index) {
          final isActive = index <= currentStep;
          final isCurrent = index == currentStep;
          return Expanded(
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: isCurrent ? 28 : 24,
                  height: isCurrent ? 28 : 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive ? AppColors.gold : Colors.white24,
                    border: isActive && !isCurrent
                        ? Border.all(color: AppColors.gold, width: 2)
                        : null,
                  ),
                  child: isActive && !isCurrent
                      ? const Icon(Icons.check, color: Colors.black, size: 16)
                      : null,
                ),
                if (index < steps.length - 1)
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 2,
                      color: index < currentStep ? AppColors.gold : Colors.white24,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}