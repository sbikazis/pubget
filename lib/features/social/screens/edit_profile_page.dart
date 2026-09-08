import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../app/app_router.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/media/image_crop_aspect.dart';
import '../../../core/media/image_pick_and_crop.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/auth_validators.dart';
import '../../authentication/providers/auth_provider.dart';
import '../models/profile_section_privacy.dart';
import '../models/profile_social_link.dart';
import '../providers/profile_provider.dart';
import '../repositories/profile_repository.dart';
import '../widgets/profile_chrome.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _username = TextEditingController();
  final _displayName = TextEditingController();
  final _bio = TextEditingController();
  final _country = TextEditingController();
  final _age = TextEditingController();
  final _favoriteQuote = TextEditingController();
  final _animeTwin = TextEditingController();
  final _favoriteAnimeIds = TextEditingController();
  final _linkUrl = TextEditingController();
  final _linkLabel = TextEditingController();
  bool _loaded = false;
  String _profileVisibility = 'public';
  String _activityVisibility = 'public';
  String _whoCanMessageMe = 'related';
  ProfileSectionPrivacy _sectionPrivacy = ProfileSectionPrivacy.public;
  final _socialLinks = <ProfileSocialLink>[];
  Uint8List? _avatarBytes;
  Uint8List? _coverBytes;
  String _avatarContentType = 'image/png';
  String _coverContentType = 'image/png';
  String? _usernameError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _username.dispose();
    _displayName.dispose();
    _bio.dispose();
    _country.dispose();
    _age.dispose();
    _favoriteQuote.dispose();
    _animeTwin.dispose();
    _favoriteAnimeIds.dispose();
    _linkUrl.dispose();
    _linkLabel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final loading = profile.state == LoadingState.loading;
    final own = profile.ownProfile;
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: const Text('Edit profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          Text('Cover', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _coverBytes != null
                  ? Image.memory(_coverBytes!, fit: BoxFit.cover)
                  : (own?.coverUrl == null || own!.coverUrl!.isEmpty)
                  ? Container(color: AppColors.royalPurplePale)
                  : AppImageLoader(imageUrl: own.coverUrl!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          PubgetSecondaryButton(
            onPressed: loading ? null : _pickCover,
            semanticLabel: 'Choose a cover photo',
            leadingIcon: Icons.wallpaper_outlined,
            child: Text(
              _coverBytes == null ? 'Change cover' : 'New cover selected',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: PubgetAvatar(
              image: _avatarBytes == null ? null : MemoryImage(_avatarBytes!),
              imageUrl: _avatarBytes == null ? own?.avatarUrl : null,
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
          PubgetTextField(
            key: const Key('edit-profile-username'),
            controller: _username,
            label: 'Username',
            enabled: !loading,
            errorText: _usernameError,
            autocorrect: false,
            enableSuggestions: false,
          ),
          const SizedBox(height: AppSpacing.md),
          PubgetTextField(
            controller: _displayName,
            label: 'Display name',
            enabled: !loading,
          ),
          const SizedBox(height: AppSpacing.md),
          PubgetTextArea(
            key: const Key('edit-profile-bio'),
            controller: _bio,
            label: 'Bio',
            hint: 'Tell the community about you.',
            enabled: !loading,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: PubgetTextField(
                  controller: _age,
                  label: 'Age (optional)',
                  enabled: !loading,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: PubgetTextField(
                  controller: _country,
                  label: 'Country (optional)',
                  enabled: !loading,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          PubgetTextField(
            controller: _favoriteQuote,
            label: 'Favorite quote (optional)',
            enabled: !loading,
          ),
          const SizedBox(height: AppSpacing.md),
          PubgetTextField(
            controller: _animeTwin,
            label: 'Anime twin (optional)',
            hint: 'A character you vibe with',
            enabled: !loading,
          ),
          const SizedBox(height: AppSpacing.md),
          PubgetTextField(
            controller: _favoriteAnimeIds,
            label: 'Favorite anime IDs',
            hint: 'one-piece, frieren',
            enabled: !loading,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Social links', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          if (_socialLinks.isNotEmpty) ...[
            ProfileSocialLinkChips(links: _socialLinks),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final link in _socialLinks)
                  InputChip(
                    label: Text(link.displayLabel),
                    onDeleted: loading
                        ? null
                        : () => setState(() => _socialLinks.remove(link)),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          PubgetTextField(
            controller: _linkUrl,
            label: 'Add link URL',
            hint: 'https://...',
            enabled: !loading,
          ),
          const SizedBox(height: AppSpacing.sm),
          PubgetTextField(
            controller: _linkLabel,
            label: 'Label (optional)',
            enabled: !loading,
          ),
          const SizedBox(height: AppSpacing.sm),
          PubgetSecondaryButton(
            onPressed: loading ? null : _addLink,
            semanticLabel: 'Add social link',
            leadingIcon: Icons.add_link,
            child: const Text('Add link'),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Privacy', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
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
          const SizedBox(height: AppSpacing.md),
          ..._sectionToggles(loading),
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

  List<Widget> _sectionToggles(bool loading) {
    Widget tile(String label, bool value, ValueChanged<bool> onChanged) {
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: value,
        onChanged: loading ? null : onChanged,
      );
    }

    return <Widget>[
      tile(
        'Show favorites',
        _sectionPrivacy.favorites,
        (value) => setState(
          () => _sectionPrivacy = _sectionPrivacy.copyWith(favorites: value),
        ),
      ),
      tile(
        'Show activity',
        _sectionPrivacy.activity,
        (value) => setState(
          () => _sectionPrivacy = _sectionPrivacy.copyWith(activity: value),
        ),
      ),
      tile(
        'Show friends',
        _sectionPrivacy.friends,
        (value) => setState(
          () => _sectionPrivacy = _sectionPrivacy.copyWith(friends: value),
        ),
      ),
      tile(
        'Show fans',
        _sectionPrivacy.fans,
        (value) => setState(
          () => _sectionPrivacy = _sectionPrivacy.copyWith(fans: value),
        ),
      ),
      tile(
        'Show works (Edits / Fan Works)',
        _sectionPrivacy.works,
        (value) => setState(
          () => _sectionPrivacy = _sectionPrivacy.copyWith(works: value),
        ),
      ),
      tile(
        'Show groups',
        _sectionPrivacy.groups,
        (value) => setState(
          () => _sectionPrivacy = _sectionPrivacy.copyWith(groups: value),
        ),
      ),
      tile(
        'Show ratings',
        _sectionPrivacy.ratings,
        (value) => setState(
          () => _sectionPrivacy = _sectionPrivacy.copyWith(ratings: value),
        ),
      ),
      tile(
        'Show achievements',
        _sectionPrivacy.achievements,
        (value) => setState(
          () =>
              _sectionPrivacy = _sectionPrivacy.copyWith(achievements: value),
        ),
      ),
    ];
  }

  Future<void> _load() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) return;
    final provider = context.read<ProfileProvider>();
    await provider.load(viewerId: userId, profileId: userId);
    if (!mounted) return;
    final profile = provider.ownProfile;
    setState(() {
      _username.text = profile?.username ?? '';
      _displayName.text = profile?.displayName ?? '';
      _bio.text = profile?.bio ?? '';
      _country.text = profile?.country ?? '';
      _age.text = profile?.age?.toString() ?? '';
      _favoriteQuote.text = profile?.favoriteQuote ?? '';
      _animeTwin.text = profile?.animeTwin ?? '';
      _favoriteAnimeIds.text = (profile?.favoriteAnimeIds ?? const <String>[])
          .join(', ');
      _profileVisibility = profile?.profileVisibility ?? 'public';
      _activityVisibility = profile?.activityVisibility ?? 'public';
      _whoCanMessageMe = profile?.whoCanMessageMe ?? 'related';
      _sectionPrivacy = profile?.sectionPrivacy ?? ProfileSectionPrivacy.public;
      _socialLinks
        ..clear()
        ..addAll(profile?.socialLinks ?? const <ProfileSocialLink>[]);
    });
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
    });
  }

  Future<void> _pickCover() async {
    final cropped = await pickAndCropImage(
      context,
      aspect: ImageCropAspect.cover,
    );
    if (cropped == null || !mounted) return;
    setState(() {
      _coverBytes = cropped.bytes;
      _coverContentType = cropped.contentType;
    });
  }

  void _addLink() {
    final url = _linkUrl.text.trim();
    if (url.isEmpty) return;
    final normalized = url.startsWith('http') ? url : 'https://$url';
    setState(() {
      _socialLinks.add(
        ProfileSocialLink(
          url: normalized,
          label: _linkLabel.text.trim().isEmpty ? null : _linkLabel.text.trim(),
        ),
      );
      _linkUrl.clear();
      _linkLabel.clear();
    });
  }

  Future<void> _save() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) return;
    final usernameError = AuthValidators.username(_username.text);
    final requiredError = _username.text.trim().isEmpty
        ? 'Username is required.'
        : usernameError;
    setState(() => _usernameError = requiredError);
    if (requiredError != null) return;

    final provider = context.read<ProfileProvider>();
    if (_avatarBytes != null) {
      final avatarResult = await provider.uploadAvatar(
        userId: userId,
        bytes: _avatarBytes!,
        contentType: _avatarContentType,
      );
      if (!avatarResult.isSuccess || !mounted) return;
    }
    String? coverUrl;
    if (_coverBytes != null) {
      final coverResult = await provider.uploadCover(
        userId: userId,
        bytes: _coverBytes!,
        contentType: _coverContentType,
      );
      if (!coverResult.isSuccess || !mounted) return;
      coverUrl = coverResult.valueOrNull;
    }
    final favorites = _favoriteAnimeIds.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .take(50)
        .toList(growable: false);
    final ageText = _age.text.trim();
    final age = ageText.isEmpty ? null : int.tryParse(ageText);
    final result = await provider.update(
      userId,
      ProfileUpdate(
        username: _username.text,
        displayName: _displayName.text,
        bio: _bio.text,
        age: age,
        clearAge: ageText.isEmpty,
        country: _country.text,
        favoriteQuote: _favoriteQuote.text,
        animeTwin: _animeTwin.text,
        socialLinks: List<ProfileSocialLink>.unmodifiable(_socialLinks),
        favoriteAnimeIds: favorites,
        profileVisibility: _profileVisibility,
        activityVisibility: _activityVisibility,
        whoCanMessageMe: _whoCanMessageMe,
        sectionPrivacy: _sectionPrivacy,
        coverUrl: coverUrl,
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
