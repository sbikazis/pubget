import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../repositories/profile_repository.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _bio = TextEditingController();
  final _favoriteAnimeIds = TextEditingController();
  final _picker = ImagePicker();
  bool _loaded = false;
  String _profileVisibility = 'public';
  String _activityVisibility = 'public';
  String _whoCanMessageMe = 'related';
  Uint8List? _avatarBytes;
  String _avatarContentType = 'image/jpeg';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _bio.dispose();
    _favoriteAnimeIds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final loading = profile.state == LoadingState.loading;
    final own = profile.ownProfile;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          Center(
            child: PubgetAvatar(
              imageUrl: own?.avatarUrl,
              name: own?.displayName ?? own?.username,
              size: PubgetAvatarSize.large,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          PubgetSecondaryButton(
            onPressed: loading ? null : _pickAvatar,
            semanticLabel: 'Choose a new profile photo',
            leadingIcon: Icons.photo_library_outlined,
            child: Text(
              _avatarBytes == null ? 'Change photo' : 'New photo selected',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PubgetTextArea(
            key: const Key('edit-profile-bio'),
            controller: _bio,
            label: 'Bio',
            hint: 'Tell the community about you.',
            enabled: !loading,
          ),
          const SizedBox(height: AppSpacing.md),
          PubgetTextField(
            controller: _favoriteAnimeIds,
            label: 'Favorite anime IDs',
            hint: 'one-piece, frieren',
            enabled: !loading,
          ),
          const SizedBox(height: AppSpacing.md),
          _VisibilityField(
            label: 'Profile visibility',
            value: _profileVisibility,
            onChanged: loading
                ? null
                : (value) => setState(() => _profileVisibility = value),
          ),
          const SizedBox(height: AppSpacing.md),
          _VisibilityField(
            label: 'Activity visibility',
            value: _activityVisibility,
            onChanged: loading
                ? null
                : (value) => setState(() => _activityVisibility = value),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            key: const Key('edit-profile-who-can-message'),
            value: _whoCanMessageMe,
            decoration: const InputDecoration(labelText: 'Who can message me'),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem(
                value: 'related',
                child: Text('Fans and Friends'),
              ),
              DropdownMenuItem(
                value: 'friends',
                child: Text('Friends only'),
              ),
            ],
            onChanged: loading
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _whoCanMessageMe = value);
                    }
                  },
          ),
          if (profile.failure != null) ...[
            const SizedBox(height: AppSpacing.md),
            PubgetErrorState(message: profile.failure!.message),
          ],
          const SizedBox(height: AppSpacing.xl),
          PubgetPrimaryButton(
            key: const Key('edit-profile-save'),
            onPressed: loading ? null : _save,
            semanticLabel: 'Save profile changes',
            loading: loading,
            child: const Text('Save changes'),
          ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) return;
    final provider = context.read<ProfileProvider>();
    await provider.load(viewerId: userId, profileId: userId);
    if (!mounted) return;
    final profile = provider.ownProfile;
    setState(() {
      _bio.text = profile?.bio ?? '';
      _favoriteAnimeIds.text = (profile?.favoriteAnimeIds ?? const <String>[])
          .join(', ');
      _profileVisibility = profile?.profileVisibility ?? 'public';
      _activityVisibility = profile?.activityVisibility ?? 'public';
      _whoCanMessageMe = profile?.whoCanMessageMe ?? 'related';
    });
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
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) return;
    final provider = context.read<ProfileProvider>();
    if (_avatarBytes != null) {
      final avatarResult = await provider.uploadAvatar(
        userId: userId,
        bytes: _avatarBytes!,
        contentType: _avatarContentType,
      );
      if (!avatarResult.isSuccess || !mounted) return;
    }
    final favorites = _favoriteAnimeIds.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .take(50)
        .toList(growable: false);
    final result = await provider.update(
      userId,
      ProfileUpdate(
        bio: _bio.text,
        favoriteAnimeIds: favorites,
        profileVisibility: _profileVisibility,
        activityVisibility: _activityVisibility,
        whoCanMessageMe: _whoCanMessageMe,
      ),
    );
    if (mounted && result.isSuccess) {
      await AppNavigation.go(context, '/profile');
    }
  }
}

class _VisibilityField extends StatelessWidget {
  const _VisibilityField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: const <DropdownMenuItem<String>>[
        DropdownMenuItem(value: 'public', child: Text('Public')),
        DropdownMenuItem(value: 'private', child: Text('Private')),
      ],
      onChanged: onChanged == null
          ? null
          : (value) {
              if (value != null) onChanged!(value);
            },
    );
  }
}
