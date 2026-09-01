import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/errors/result.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/network/network_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
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
    return AuthPageShell(
      title: 'Make Pubget yours',
      subtitle: 'Everything here is optional. You can finish it later.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: PubgetAvatar(
              imageUrl: onboarding.profile?.avatarUrl ?? user?.avatarUrl,
              name: _displayName.text.isEmpty
                  ? user?.displayName
                  : _displayName.text,
              size: PubgetAvatarSize.large,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_avatarBytes != null)
            const PubgetBadge(
              label: 'New photo selected',
              icon: Icons.check_circle_outline,
            ),
          PubgetSecondaryButton(
            onPressed: loading ? null : _pickAvatar,
            semanticLabel: 'Choose a profile picture',
            leadingIcon: Icons.photo_library_outlined,
            child: const Text('Choose profile picture'),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (!network.isOnline)
            const PubgetOfflineState(
              title: 'You are offline',
              message: 'You can skip for now or reconnect to save.',
            )
          else if (onboarding.failure != null)
            PubgetErrorState(
              title: 'Profile not saved',
              message: onboarding.failure!.message,
            ),
          PubgetTextField(
            key: const Key('onboarding-username'),
            controller: _username,
            label: 'Username',
            hint: 'pubget_fan',
            errorText: _usernameError,
            enabled: !loading,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          PubgetTextField(
            controller: _displayName,
            label: 'Display name',
            enabled: !loading,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          PubgetTextArea(
            controller: _bio,
            label: 'Bio',
            hint: 'Tell the community a little about you.',
            enabled: !loading,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Anime interests',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _interestOptions
                .map(
                  (interest) => PubgetSelectionChip(
                    label: interest,
                    selected: _interests.contains(interest),
                    onSelected: loading
                        ? null
                        : (selected) => setState(
                            () => selected
                                ? _interests.add(interest)
                                : _interests.remove(interest),
                          ),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: AppSpacing.xl),
          PubgetPrimaryButton(
            key: const Key('onboarding-save'),
            onPressed: !network.isOnline || loading ? null : _save,
            semanticLabel: 'Save profile and continue',
            loading: loading,
            child: const Text('Save and continue'),
          ),
          const SizedBox(height: AppSpacing.sm),
          PubgetTextButton(
            onPressed: loading ? null : () => _skip(onboarding),
            semanticLabel: 'Skip profile setup for now',
            child: const Text('Skip for now'),
          ),
        ],
      ),
    );
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
    if (username.isNotEmpty && username.length < 3) {
      setState(() => _usernameError = 'Use at least 3 characters.');
      return;
    }
    setState(() => _usernameError = null);
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
    final result = await onboarding.skip(user);
    if (!mounted) return;
    if (result.isSuccess) await AppNavigation.go(context, '/home');
  }
}
