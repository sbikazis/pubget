import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/errors/result.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/media/image_crop_aspect.dart';
import '../../../core/media/image_pick_and_crop.dart';
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
  final _country = TextEditingController();
  final _age = TextEditingController();
  final _interests = <String>{};
  Uint8List? _avatarBytes;
  String _avatarContentType = 'image/png';
  String? _usernameError;
  String? _avatarError;
  var _step = 0;

  static const _totalSteps = 3;

  @override
  void dispose() {
    _username.dispose();
    _displayName.dispose();
    _bio.dispose();
    _country.dispose();
    _age.dispose();
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
      title: switch (_step) {
        0 => 'Your face & name',
        1 => 'A little about you',
        _ => 'What do you love?',
      },
      subtitle: switch (_step) {
        0 => 'Username and photo are required. Everything else can wait.',
        1 => 'Optional details. Skip any field you want to fill later.',
        _ => 'Pick anime moods to feed recommendations. Skip anytime.',
      },
      compactBrand: true,
      trailing: PubgetTextButton(
        key: const Key('onboarding-skip-step'),
        onPressed: loading
            ? null
            : () {
                if (_step == 0) {
                  _skip(onboarding);
                } else if (_step < _totalSteps - 1) {
                  setState(() => _step += 1);
                } else {
                  _finish(completed: _canCompleteMinimum);
                }
              },
        semanticLabel: _step == 0
            ? 'Skip profile setup for now'
            : 'Skip this step',
        child: Text(_step == 0 ? 'Skip for now' : 'Skip'),
      ),
      primaryAction: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_step < _totalSteps - 1)
            PubgetPrimaryButton(
              key: const Key('onboarding-continue'),
              onPressed: loading ? null : _continue,
              semanticLabel: 'Continue profile setup',
              child: const Text('Continue'),
            )
          else
            PubgetPrimaryButton(
              key: const Key('onboarding-save'),
              onPressed: offline || loading
                  ? null
                  : () => _finish(completed: _canCompleteMinimum),
              semanticLabel: 'Save profile and continue',
              loading: loading,
              child: const Text('Enter Pubget'),
            ),
          if (_step > 0)
            PubgetTextButton(
              onPressed: loading ? null : () => setState(() => _step -= 1),
              semanticLabel: 'Back to previous step',
              child: const Text('Back'),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _OnboardingProgress(step: _step, total: _totalSteps),
          const SizedBox(height: AppSpacing.md),
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
              avatarError: _avatarError,
              loading: loading,
              avatarBytes: _avatarBytes,
              avatarUrl: onboarding.profile?.avatarUrl ?? user?.avatarUrl,
              onPickAvatar: _pickAvatar,
              onDisplayNameChanged: () => setState(() {}),
            )
          else if (_step == 1)
            _AboutStep(
              bio: _bio,
              country: _country,
              age: _age,
              loading: loading,
              onSkipBio: () {
                _bio.clear();
                setState(() => _step = 2);
              },
              onSkipCountry: () {
                _country.clear();
                setState(() {});
              },
              onSkipAge: () {
                _age.clear();
                setState(() {});
              },
            )
          else
            _InterestsStep(
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
              onSkipInterests: () {
                _interests.clear();
                _finish(completed: _canCompleteMinimum);
              },
            ),
        ],
      ),
    );
  }

  bool get _canCompleteMinimum =>
      _username.text.trim().length >= 3 &&
      (_avatarBytes != null ||
          (context.read<OnboardingProvider>().profile?.avatarUrl?.isNotEmpty ==
              true) ||
          (context.read<AuthProvider>().currentUser?.avatarUrl?.isNotEmpty ==
              true));

  void _continue() {
    if (_step == 0) {
      final username = _username.text.trim();
      final usernameError = username.isEmpty
          ? 'Username is required.'
          : AuthValidators.username(username);
      final avatarMissing = _avatarBytes == null &&
          (context.read<OnboardingProvider>().profile?.avatarUrl?.isEmpty ??
              true) &&
          (context.read<AuthProvider>().currentUser?.avatarUrl?.isEmpty ?? true);
      setState(() {
        _usernameError = usernameError;
        _avatarError = avatarMissing ? 'Profile photo is required.' : null;
      });
      if (usernameError != null || avatarMissing) return;
      setState(() => _step = 1);
      return;
    }
    setState(() => _step += 1);
  }

  Future<void> _pickAvatar() async {
    final cropped = await pickAndCropImage(
      context,
      aspect: ImageCropAspect.avatar,
    );
    if (cropped == null || !mounted) return;
    setState(() {
      _avatarBytes = cropped.bytes;
      _avatarContentType = cropped.contentType;
      _avatarError = null;
    });
  }

  Future<void> _finish({required bool completed}) async {
    final authUser = context.read<AuthProvider>().currentUser;
    if (authUser == null) {
      await AppNavigation.go(context, '/login');
      return;
    }
    final username = _username.text.trim();
    if (completed) {
      final error = username.isEmpty
          ? 'Username is required.'
          : AuthValidators.username(username);
      if (error != null) {
        setState(() {
          _usernameError = error;
          _step = 0;
        });
        return;
      }
    }
    final provider = context.read<OnboardingProvider>();
    final age = int.tryParse(_age.text.trim());
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
    if (result is Success) {
      // Persist optional extras via a second soft update when completed.
      if (completed &&
          (_country.text.trim().isNotEmpty ||
              age != null ||
              _bio.text.trim().isNotEmpty)) {
        await provider.saveProfile(
          authUser: authUser,
          username: username,
          displayName: _displayName.text,
          bio: _bio.text,
          favoriteAnimes: _interests.toList(growable: false),
          isProfileCompleted: true,
        );
      }
      await AppNavigation.go(context, '/home');
    }
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
    required this.avatarError,
    required this.loading,
    required this.avatarBytes,
    required this.avatarUrl,
    required this.onPickAvatar,
    required this.onDisplayNameChanged,
  });

  final TextEditingController username;
  final TextEditingController displayName;
  final String? usernameError;
  final String? avatarError;
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
            label: 'Photo ready',
            icon: Icons.check_circle_outline,
            compact: true,
          ),
        if (avatarError != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            avatarError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
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
          helperText: 'Required. At least 3 characters.',
          errorText: usernameError,
          enabled: !loading,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          enableSuggestions: false,
        ),
        const SizedBox(height: AppSpacing.md),
        PubgetTextField(
          controller: displayName,
          label: 'Display name (optional)',
          helperText: 'How you appear to other members.',
          enabled: !loading,
          textInputAction: TextInputAction.next,
          onChanged: (_) => onDisplayNameChanged(),
        ),
      ],
    );
  }
}

class _AboutStep extends StatelessWidget {
  const _AboutStep({
    required this.bio,
    required this.country,
    required this.age,
    required this.loading,
    required this.onSkipBio,
    required this.onSkipCountry,
    required this.onSkipAge,
  });

  final TextEditingController bio;
  final TextEditingController country;
  final TextEditingController age;
  final bool loading;
  final VoidCallback onSkipBio;
  final VoidCallback onSkipCountry;
  final VoidCallback onSkipAge;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PubgetTextArea(
          controller: bio,
          label: 'Bio',
          hint: 'A short vibe check for your page.',
          enabled: !loading,
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: PubgetTextButton(
            onPressed: loading ? null : onSkipBio,
            semanticLabel: 'Skip bio',
            child: const Text('Skip bio'),
          ),
        ),
        PubgetTextField(
          controller: country,
          label: 'Country',
          enabled: !loading,
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: PubgetTextButton(
            onPressed: loading ? null : onSkipCountry,
            semanticLabel: 'Skip country',
            child: const Text('Skip country'),
          ),
        ),
        PubgetTextField(
          controller: age,
          label: 'Age',
          enabled: !loading,
          keyboardType: TextInputType.number,
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: PubgetTextButton(
            onPressed: loading ? null : onSkipAge,
            semanticLabel: 'Skip age',
            child: const Text('Skip age'),
          ),
        ),
      ],
    );
  }
}

class _InterestsStep extends StatelessWidget {
  const _InterestsStep({
    required this.interests,
    required this.options,
    required this.loading,
    required this.onToggle,
    required this.onSkipInterests,
  });

  final Set<String> interests;
  final List<String> options;
  final bool loading;
  final void Function(String interest, bool selected) onToggle;
  final VoidCallback onSkipInterests;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
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
        const SizedBox(height: AppSpacing.md),
        PubgetTextButton(
          onPressed: loading ? null : onSkipInterests,
          semanticLabel: 'Skip anime interests',
          child: const Text('Skip interests'),
        ),
      ],
    );
  }
}
