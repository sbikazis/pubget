import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/network/network_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../auth_validators.dart';
import '../models/username_status.dart';
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

  static const _usernameDebounce = Duration(milliseconds: 250);

  final _username = TextEditingController();
  final _displayName = TextEditingController();
  final _bio = TextEditingController();
  final _country = TextEditingController();
  final _age = TextEditingController();
  final _interests = <String>{};
  Uint8List? _avatarBytes;
  String _avatarContentType = 'image/png';
  String? _usernameError;
  String? _displayNameError;
  String? _avatarError;
  UsernameStatus? _availability;
  Timer? _availabilityTimer;
  var _checking = false;
  var _step = 0;

  static const _totalSteps = 3;

  @override
  void dispose() {
    _availabilityTimer?.cancel();
    _username.dispose();
    _displayName.dispose();
    _bio.dispose();
    _country.dispose();
    _age.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final auth = context.watch<AuthProvider>();
    final onboarding = context.watch<OnboardingProvider>();
    final network = context.watch<NetworkService>();
    final loading = onboarding.state == LoadingState.loading;
    final user = auth.currentUser;
    final offline = network.isOffline;
    final avatarUrl =
        _avatarBytes == null
        ? (onboarding.profile?.avatarUrl ?? user?.avatarUrl)
        : null;
    return AuthPageShell(
      title: switch (_step) {
        0 => copy.onboardingTitleIdentity,
        1 => copy.onboardingTitleAbout,
        _ => copy.onboardingTitleInterests,
      },
      subtitle: switch (_step) {
        0 => copy.onboardingSubtitleIdentity,
        1 => copy.onboardingSubtitleAbout,
        _ => copy.onboardingSubtitleInterests,
      },
      compactBrand: true,
      trailing: _step == 0
          ? offline
                ? PubgetTextButton(
                    key: const Key('onboarding-skip-step'),
                    onPressed: loading ? null : _skip,
                    semanticLabel: copy.onboardingOfflineSaveSemantic,
                    child: Text(copy.onboardingOfflineSave),
                  )
                : null
          : PubgetTextButton(
              key: const Key('onboarding-skip-step'),
              onPressed: loading ? null : _skipStepOrFinish(offline),
              semanticLabel: copy.onboardingSkipStep,
              child: Text(
                offline ? copy.onboardingOfflineSave : copy.onboardingSkipStep,
              ),
            ),
      primaryAction: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_step < _totalSteps - 1)
            PubgetPrimaryButton(
              key: const Key('onboarding-continue'),
              onPressed: loading ? null : _continue,
              semanticLabel: copy.onboardingContinueSemantic,
              child: Text(copy.onboardingContinue),
            )
          else
            PubgetPrimaryButton(
              key: const Key('onboarding-save'),
              onPressed: offline || loading ? null : () => _finish(completed: true),
              semanticLabel: copy.onboardingSaveAndEnter,
              loading: loading,
              child: Text(copy.onboardingEnterPubget),
            ),
          if (_step > 0)
            PubgetTextButton(
              onPressed: loading ? null : () => setState(() => _step -= 1),
              semanticLabel: copy.onboardingBackSemantic,
              child: Text(copy.onboardingBack),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _OnboardingProgress(
            step: _step,
            total: _totalSteps,
            label: '${copy.onboardingStepOfLabel} ${_step + 1} '
                '${copy.onboardingOfLabel} $_totalSteps',
          ),
          const SizedBox(height: AppSpacing.md),
          if (offline)
            PubgetInlineBanner(
              title: copy.onboardingOfflineTitle,
              message: copy.onboardingOfflineMessage,
              icon: Icons.cloud_off_outlined,
            )
          else if (onboarding.failure != null)
            PubgetInlineBanner.error(
              title: copy.onboardingSaveFailedTitle,
              message: onboarding.failure!.message,
            ),
          if (offline || onboarding.failure != null)
            const SizedBox(height: AppSpacing.md),
          if (_step == 0)
            _IdentityStep(
              copy: copy,
              username: _username,
              displayName: _displayName,
              usernameError: _usernameError,
              displayNameError: _displayNameError,
              avatarError: _avatarError,
              checking: _checking,
              availability: _availability,
              availabilityIcon: _availabilityIcon,
              loading: loading,
              avatarBytes: _avatarBytes,
              avatarUrl: avatarUrl,
              onPickAvatar: _pickAvatar,
              onUsernameChanged: _onUsernameChanged,
              onDisplayNameChanged: _onDisplayNameChanged,
            )
          else if (_step == 1)
            _AboutStep(
              copy: copy,
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
              copy: copy,
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
              onSkipInterests: () => _finish(completed: true),
            ),
        ],
      ),
    );
  }

  bool get _isOnline => !context.read<NetworkService>().isOffline;

  _OnboardingAvailabilityIcon _availabilityIcon(AppStrings copy) {
    if (_checking) {
      return const _OnboardingAvailabilityIcon.checking();
    }
    final status = _availability;
    if (status == null || status.available) {
      return const _OnboardingAvailabilityIcon.available();
    }
    return const _OnboardingAvailabilityIcon.taken();
  }

  void _onUsernameChanged(String value) {
    _availabilityTimer?.cancel();
    final trimmed = value.trim();
    setState(() {
      _usernameError = null;
      _availability = null;
      _checking = false;
    });
    if (trimmed.isEmpty) return;
    if (AuthValidators.username(trimmed) != null) return;
    if (!_isOnline) return;
    setState(() => _checking = true);
    _availabilityTimer = Timer(_usernameDebounce, () {
      if (mounted) _runAvailabilityCheck(trimmed);
    });
  }

  Future<void> _runAvailabilityCheck(String username) async {
    final result = await context
        .read<OnboardingProvider>()
        .checkUsernameAvailable(username);
    if (!mounted) return;
    if (result is FailureResult) {
      setState(() {
        _checking = false;
        _availability = null;
      });
      return;
    }
    if (_username.text.trim() != username) return;
    setState(() {
      _checking = false;
      _availability = result.valueOrNull;
    });
  }

  Future<UsernameStatus?> _checkNow(String username) async {
    final result = await context
        .read<OnboardingProvider>()
        .checkUsernameAvailable(username);
    return result is FailureResult ? null : result.valueOrNull;
  }

  void _onDisplayNameChanged() {
    if (_displayNameError != null) {
      setState(() => _displayNameError = null);
    }
  }

  Future<void> _continue() async {
    final copy = AppStrings.of(context);
    if (_step == 0) {
      final username = _username.text.trim();
      final usernameError = username.isEmpty
          ? copy.usernameRequired
          : AuthValidators.username(username);
      final avatarMissing = _avatarBytes == null &&
          (context.read<OnboardingProvider>().profile?.avatarUrl?.isEmpty ??
              true) &&
          (context.read<AuthProvider>().currentUser?.avatarUrl?.isEmpty ?? true);
      final displayNameMissing = _displayName.text.trim().isEmpty;
      setState(() {
        _usernameError = usernameError;
        _avatarError = avatarMissing ? copy.onboardingPhotoRequired : null;
        _displayNameError = displayNameMissing
            ? copy.onboardingDisplayNameRequired
            : null;
      });
      if (usernameError != null || avatarMissing || displayNameMissing) return;
      if (_isOnline) {
        final status = await _checkNow(username);
        if (!mounted) return;
        if (status == null) {
          setState(() => _usernameError = copy.usernameCheckFailed);
          return;
        }
        if (!status.available) {
          setState(() {
            _usernameError = status.cause == UsernameStatusCause.taken
                ? copy.usernameTaken
                : copy.usernameInvalidCharacters;
          });
          return;
        }
      }
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

  VoidCallback _skipStepOrFinish(bool offline) {
    if (offline) return _skip;
    return () {
      if (_step < _totalSteps - 1) {
        setState(() => _step += 1);
      } else {
        _finish(completed: true);
      }
    };
  }

  Future<void> _finish({required bool completed}) async {
    final copy = AppStrings.of(context);
    final authUser = context.read<AuthProvider>().currentUser;
    if (authUser == null) {
      await AppNavigation.go(context, '/login');
      return;
    }
    final username = _username.text.trim();
    final error = username.isEmpty
        ? copy.usernameRequired
        : AuthValidators.username(username);
    if (completed && error != null) {
      setState(() {
        _usernameError = error;
        _step = 0;
      });
      return;
    }
    final provider = context.read<OnboardingProvider>();
    if (completed && _isOnline && username.isNotEmpty) {
      // Claim the username server-side before the direct profile write so the
      // reserved-name flow stays race-safe (spec §3.2).
      final reserve = await provider.reserveUsername(username);
      if (!mounted) return;
      if (reserve is FailureResult) {
        final reserveFailure = reserve.failureOrNull;
        if (reserveFailure is NetworkError && _isOnline) {
          setState(() => _usernameError = copy.usernameCheckFailed);
          return;
        }
        setState(() {
          _usernameError = copy.usernameTaken;
          _step = 0;
        });
        return;
      }
    }
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
        if (!mounted) return;
      }
      await AppNavigation.go(context, '/home');
    }
  }

  Future<void> _skip() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) {
      await AppNavigation.go(context, '/login');
      return;
    }
    final result = await context
        .read<OnboardingProvider>()
        .skip(
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

class _OnboardingAvailabilityIcon extends StatelessWidget {
  const _OnboardingAvailabilityIcon.available() : icon = null, checking = false;
  const _OnboardingAvailabilityIcon.taken() : icon = true, checking = false;
  const _OnboardingAvailabilityIcon.checking()
    : icon = null,
      checking = true;

  final bool? icon;
  final bool checking;

  @override
  Widget build(BuildContext context) {
    if (checking) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final theme = Theme.of(context);
    return Icon(
      icon == true ? Icons.error_outline : Icons.check_circle_outline,
      size: 18,
      color: icon == true ? theme.colorScheme.error : theme.colorScheme.secondary,
    );
  }
}

class _OnboardingProgress extends StatelessWidget {
  const _OnboardingProgress({
    required this.step,
    required this.total,
    required this.label,
  });

  final int step;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          label,
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
    required this.copy,
    required this.username,
    required this.displayName,
    required this.usernameError,
    required this.displayNameError,
    required this.avatarError,
    required this.checking,
    required this.availability,
    required this.availabilityIcon,
    required this.loading,
    required this.avatarBytes,
    required this.avatarUrl,
    required this.onPickAvatar,
    required this.onUsernameChanged,
    required this.onDisplayNameChanged,
  });

  final AppStrings copy;
  final TextEditingController username;
  final TextEditingController displayName;
  final String? usernameError;
  final String? displayNameError;
  final String? avatarError;
  final bool checking;
  final UsernameStatus? availability;
  final Widget Function(AppStrings copy) availabilityIcon;
  final bool loading;
  final Uint8List? avatarBytes;
  final String? avatarUrl;
  final VoidCallback onPickAvatar;
  final ValueChanged<String> onUsernameChanged;
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
          PubgetBadge(
            label: copy.onboardingPhotoReady,
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
          semanticLabel: copy.onboardingChoosePhotoSemantic,
          leadingIcon: Icons.photo_library_outlined,
          child: Text(copy.onboardingChoosePhoto),
        ),
        const SizedBox(height: AppSpacing.lg),
        PubgetTextField(
          key: const Key('onboarding-username'),
          controller: username,
          label: copy.username,
          hint: copy.usernameHint,
          helperText: _helperText(),
          errorText: usernameError,
          suffixIcon: availabilityIcon(copy),
          enabled: !loading,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: onUsernameChanged,
        ),
        const SizedBox(height: AppSpacing.md),
        PubgetTextField(
          controller: displayName,
          key: const Key('onboarding-displayName'),
          label: copy.onboardingDisplayName,
          helperText: copy.onboardingDisplayNameHint,
          errorText: displayNameError,
          enabled: !loading,
          textInputAction: TextInputAction.next,
          onChanged: (_) => onDisplayNameChanged(),
        ),
      ],
    );
  }

  String? _helperText() {
    if (checking) return copy.usernameChecking;
    final status = availability;
    if (status != null && status.available) return copy.usernameAvailable;
    if (usernameError != null) return null;
    return copy.usernameHelp;
  }
}

class _AboutStep extends StatelessWidget {
  const _AboutStep({
    required this.copy,
    required this.bio,
    required this.country,
    required this.age,
    required this.loading,
    required this.onSkipBio,
    required this.onSkipCountry,
    required this.onSkipAge,
  });

  final AppStrings copy;
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
          label: copy.onboardingBio,
          hint: copy.onboardingBioHint,
          enabled: !loading,
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: PubgetTextButton(
            onPressed: loading ? null : onSkipBio,
            semanticLabel: copy.onboardingSkipBioSemantic,
            child: Text(copy.onboardingSkipBio),
          ),
        ),
        PubgetTextField(
          controller: country,
          label: copy.onboardingCountry,
          enabled: !loading,
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: PubgetTextButton(
            onPressed: loading ? null : onSkipCountry,
            semanticLabel: copy.onboardingSkipCountrySemantic,
            child: Text(copy.onboardingSkipCountry),
          ),
        ),
        PubgetTextField(
          controller: age,
          label: copy.onboardingAge,
          enabled: !loading,
          keyboardType: TextInputType.number,
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: PubgetTextButton(
            onPressed: loading ? null : onSkipAge,
            semanticLabel: copy.onboardingSkipAgeSemantic,
            child: Text(copy.onboardingSkipAge),
          ),
        ),
      ],
    );
  }
}

class _InterestsStep extends StatelessWidget {
  const _InterestsStep({
    required this.copy,
    required this.interests,
    required this.options,
    required this.loading,
    required this.onToggle,
    required this.onSkipInterests,
  });

  final AppStrings copy;
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
        Text(
          copy.onboardingInterestsTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: options
              .map(
                (interest) => PubgetSelectionChip(
                  label: _interestLabel(copy, interest),
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
          semanticLabel: copy.onboardingSkipInterestsSemantic,
          child: Text(copy.onboardingSkipInterests),
        ),
      ],
    );
  }

  static String _interestLabel(AppStrings copy, String interest) =>
      switch (interest) {
        'Action' => copy.onboardingInterestAction,
        'Adventure' => copy.onboardingInterestAdventure,
        'Comedy' => copy.onboardingInterestComedy,
        'Fantasy' => copy.onboardingInterestFantasy,
        'Mystery' => copy.onboardingInterestMystery,
        _ => copy.onboardingInterestRomance,
      };
}