import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/errors/result.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/network/network_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../auth_validators.dart';
import '../providers/auth_provider.dart';
import '../providers/onboarding_provider.dart';
import 'auth_page_shell.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const _interestOptions = <String>[
    'Action',
    'Adventure',
    'Comedy',
    'Fantasy',
    'Mystery',
    'Romance',
  ];

  final _username = TextEditingController();
  final _displayName = TextEditingController();
  final _bio = TextEditingController();
  final _picker = ImagePicker();
  final _interests = <String>{};
  Uint8List? _avatarBytes;
  String _avatarContentType = 'image/jpeg';
  String? _usernameError;
  var _step = 0;

  @override
  void dispose() {
    _username.dispose();
    _displayName.dispose();
    _bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final onboarding = context.watch<OnboardingProvider>();
    final network = context.watch<NetworkService>();
    final loading = onboarding.state == LoadingState.loading;
    final user = auth.currentUser;
    final offline = network.isOffline;
    return AuthPageShell(
      title: _step == 0 ? 'Make Pubget yours' : 'What do you love?',
      subtitle: _step == 0
          ? 'Add a face and a name. Everything here is optional.'
          : 'Pick a few anime moods. You can change this later.',
      compactBrand: true,
      trailing: PubgetTextButton(
        onPressed: loading ? null : () => _skip(onboarding),
        semanticLabel: 'Skip profile setup for now',
        child: const Text('Skip'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _OnboardingProgress(step: _step, total: 2),
          const SizedBox(height: AppSpacing.lg),
          if (offline)
            const PubgetInlineBanner(
              title: 'You are offline',
              message: 'Skip for now, or reconnect to save your profile.',
              icon: Icons.cloud_off_outlined,
            )
          else if (onboarding.failure != null)
            PubgetInlineBanner.error(
              title: 'Profile not saved',
              message: onboarding.failure!.message,
            ),
          if (offline || onboarding.failure != null)
            const SizedBox(height: AppSpacing.md),
          if (_step == 0)
            _IdentityStep(
              username: _username,
              displayName: _displayName,
              usernameError: _usernameError,
              loading: loading,
              avatarBytes: _avatarBytes,
              avatarUrl: onboarding.profile?.avatarUrl ?? user?.avatarUrl,
              onPickAvatar: _pickAvatar,
              onDisplayNameChanged: () => setState(() {}),
            )
          else
            _InterestsStep(
              bio: _bio,
              interests: _interests,
              options: _interestOptions,
              loading: loading,
              onToggle: (interest, selected) {
                setState(() {
                  if (selected) {
                    _interests.add(interest);
                  } else {
                    _interests.remove(interest);
                  }
                });
              },
            ),
          const SizedBox(height: AppSpacing.xl),
          if (_step == 0)
            PubgetPrimaryButton(
              key: const Key('onboarding-continue'),
              onPressed: loading ? null : _continueFromIdentity,
              semanticLabel: 'Continue profile setup',
              child: const Text('Continue'),
            )
          else
            PubgetPrimaryButton(
              key: const Key('onboarding-save'),
              onPressed: offline || loading ? null : _save,
              semanticLabel: 'Save profile and continue',
              loading: loading,
              child: const Text('Save and continue'),
            ),
          if (_step == 1) ...[
            const SizedBox(height: AppSpacing.sm),
            PubgetTextButton(
              onPressed: loading ? null : () => setState(() => _step = 0),
              semanticLabel: 'Back to profile details',
              child: const Text('Back'),
            ),
          ],
        ],
      ),
    );
  }

  void _continueFromIdentity() {
    final error = AuthValidators.username(_username.text);
    setState(() => _usernameError = error);
    if (error != null) return;
    setState(() => _step = 1);
  }

  Future<void> _pickAvatar() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 82,
    );
    if (image == null || !mounted) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _avatarBytes = bytes;
      _avatarContentType = image.mimeType ?? 'image/jpeg';
    });
  }

  Future<void> _save() async {
    final authUser = context.read<AuthProvider>().currentUser;
    if (authUser == null) {
      await AppNavigation.go(context, '/login');
      return;
    }
    final username = _username.text.trim();
    final error = AuthValidators.username(username);
    if (error != null) {
      setState(() {
        _usernameError = error;
        _step = 0;
      });
      return;
    }
    final provider = context.read<OnboardingProvider>();
    final completed = username.isNotEmpty;
    final Result<Object> result = _avatarBytes == null
        ? await provider.saveProfile(
            authUser: authUser,
            username: username,
            displayName: _displayName.text,
            bio: _bio.text,
            favoriteAnimes: _interests.toList(growable: false),
            isProfileCompleted: completed,
          )
        : await provider.saveProfileWithAvatar(
            authUser: authUser,
            avatarBytes: _avatarBytes!,
            contentType: _avatarContentType,
            username: username,
            displayName: _displayName.text,
            bio: _bio.text,
            favoriteAnimes: _interests.toList(growable: false),
            isProfileCompleted: completed,
          );
    if (!mounted) return;
    if (result is Success) await AppNavigation.go(context, '/home');
  }

  Future<void> _skip(OnboardingProvider onboarding) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) {
      await AppNavigation.go(context, '/login');
      return;
    }
    final result = await onboarding.skip(
      user,
      username: _username.text,
      displayName: _displayName.text,
      bio: _bio.text,
      favoriteAnimes: _interests.toList(growable: false),
    );
    if (!mounted) return;
    if (result.isSuccess) await AppNavigation.go(context, '/home');
  }
}

class _OnboardingProgress extends StatelessWidget {
  const _OnboardingProgress({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Step ${step + 1} of $total',
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppColors.royalPurpleDark,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: (step + 1) / total,
            minHeight: 4,
            color: theme.colorScheme.secondary,
            backgroundColor: AppColors.royalPurple.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }
}

class _IdentityStep extends StatelessWidget {
  const _IdentityStep({
    required this.username,
    required this.displayName,
    required this.usernameError,
    required this.loading,
    required this.avatarBytes,
    required this.avatarUrl,
    required this.onPickAvatar,
    required this.onDisplayNameChanged,
  });

  final TextEditingController username;
  final TextEditingController displayName;
  final String? usernameError;
  final bool loading;
  final Uint8List? avatarBytes;
  final String? avatarUrl;
  final VoidCallback onPickAvatar;
  final VoidCallback onDisplayNameChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        PubgetAvatar(
          image: avatarBytes == null ? null : MemoryImage(avatarBytes!),
          imageUrl: avatarBytes == null ? avatarUrl : null,
          name: displayName.text.isEmpty ? null : displayName.text,
          size: PubgetAvatarSize.large,
          onTap: loading ? null : onPickAvatar,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (avatarBytes != null)
          const PubgetBadge(
            label: 'New photo selected',
            icon: Icons.check_circle_outline,
            compact: true,
          ),
        const SizedBox(height: AppSpacing.sm),
        PubgetSecondaryButton(
          onPressed: loading ? null : onPickAvatar,
          semanticLabel: 'Choose a profile picture',
          leadingIcon: Icons.photo_library_outlined,
          child: const Text('Choose profile picture'),
        ),
        const SizedBox(height: AppSpacing.lg),
        PubgetTextField(
          key: const Key('onboarding-username'),
          controller: username,
          label: 'Username',
          hint: 'pubget_fan',
          helperText: 'Optional. At least 3 characters if you add one.',
          errorText: usernameError,
          enabled: !loading,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          enableSuggestions: false,
        ),
        const SizedBox(height: AppSpacing.md),
        PubgetTextField(
          controller: displayName,
          label: 'Display name',
          helperText: 'How you appear to other members.',
          enabled: !loading,
          textInputAction: TextInputAction.next,
          onChanged: (_) => onDisplayNameChanged(),
        ),
      ],
    );
  }
}

class _InterestsStep extends StatelessWidget {
  const _InterestsStep({
    required this.bio,
    required this.interests,
    required this.options,
    required this.loading,
    required this.onToggle,
  });

  final TextEditingController bio;
  final Set<String> interests;
  final List<String> options;
  final bool loading;
  final void Function(String interest, bool selected) onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PubgetTextArea(
          controller: bio,
          label: 'Bio',
          hint: 'Tell the community a little about you.',
          enabled: !loading,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Anime interests', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: options
              .map(
                (interest) => PubgetSelectionChip(
                  label: interest,
                  selected: interests.contains(interest),
                  onSelected: loading
                      ? null
                      : (selected) => onToggle(interest, selected),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}
