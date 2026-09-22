import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../app/app_router.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/loading/loading_state.dart';
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
    final copy = AppStrings.of(context);
    final profile = context.watch<ProfileProvider>();
    final loading = profile.state == LoadingState.loading;
    final own = profile.ownProfile;
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(copy.editProfile),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          Text(copy.cover, style: Theme.of(context).textTheme.titleMedium),
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
            semanticLabel: copy.chooseCoverSemantic,
            leadingIcon: Icons.wallpaper_outlined,
            child: Text(
              _coverBytes == null ? copy.coverChange : copy.coverSelected,
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
            semanticLabel: copy.chooseAvatarSemantic,
            leadingIcon: Icons.photo_library_outlined,
            child: Text(
              _avatarBytes == null ? copy.avatarChange : copy.avatarSelected,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PubgetTextField(
            key: const Key('edit-profile-username'),
            controller: _username,
            label: copy.username,
            helperText: copy.usernameHelp,
            enabled: !loading,
            errorText: _usernameError,
            autocorrect: false,
            enableSuggestions: false,
          ),
          const SizedBox(height: AppSpacing.md),
          PubgetTextField(
            controller: _displayName,
            label: copy.displayName,
            enabled: !loading,
          ),
          const SizedBox(height: AppSpacing.md),
          PubgetTextArea(
            key: const Key('edit-profile-bio'),
            controller: _bio,
            label: copy.bio,
            hint: copy.editBioHint,
            enabled: !loading,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: PubgetTextField(
                  controller: _age,
                  label: copy.ageOptional,
                  enabled: !loading,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: PubgetTextField(
                  controller: _country,
                  label: copy.countryOptional,
                  enabled: !loading,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          PubgetTextField(
            controller: _favoriteQuote,
            label: copy.favoriteQuoteOptional,
            enabled: !loading,
          ),
          const SizedBox(height: AppSpacing.md),
          PubgetTextField(
            controller: _animeTwin,
            label: copy.animeTwinOptional,
            hint: copy.animeTwinHint,
            enabled: !loading,
          ),
          const SizedBox(height: AppSpacing.md),
          PubgetTextField(
            controller: _favoriteAnimeIds,
            label: copy.favoriteAnimeIds,
            hint: 'one-piece, frieren',
            enabled: !loading,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            copy.socialLinks,
            style: Theme.of(context).textTheme.titleMedium,
          ),
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
            label: copy.addLinkUrl,
            hint: 'https://...',
            enabled: !loading,
          ),
          const SizedBox(height: AppSpacing.sm),
          PubgetTextField(
            controller: _linkLabel,
            label: copy.linkLabelOptional,
            enabled: !loading,
          ),
          const SizedBox(height: AppSpacing.sm),
          PubgetSecondaryButton(
            onPressed: loading ? null : _addLink,
            semanticLabel: copy.addSocialLinkSemantic,
            leadingIcon: Icons.add_link,
            child: Text(copy.addLink),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(copy.privacy, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          _VisibilityField(
            publicLabel: copy.public,
            privateLabel: copy.private,
            label: copy.profileVisibility,
            value: _profileVisibility,
            onChanged: loading
                ? null
                : (value) => setState(() => _profileVisibility = value),
          ),
          const SizedBox(height: AppSpacing.md),
          _VisibilityField(
            publicLabel: copy.public,
            privateLabel: copy.private,
            label: copy.activityVisibility,
            value: _activityVisibility,
            onChanged: loading
                ? null
                : (value) => setState(() => _activityVisibility = value),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            key: const Key('edit-profile-who-can-message'),
            value: _whoCanMessageMe,
            decoration: InputDecoration(labelText: copy.whoCanMessageMe),
            items: <DropdownMenuItem<String>>[
              DropdownMenuItem(
                value: 'related',
                child: Text(copy.whoCanMessageRelated),
              ),
              DropdownMenuItem(
                value: 'friends',
                child: Text(copy.whoCanMessageFriends),
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
          ..._sectionToggles(loading, copy),
          if (profile.failure != null) ...[
            const SizedBox(height: AppSpacing.md),
            PubgetErrorState(message: profile.failure!.message),
          ],
          const SizedBox(height: AppSpacing.xl),
          PubgetPrimaryButton(
            key: const Key('edit-profile-save'),
            onPressed: loading ? null : _save,
            semanticLabel: copy.saveProfileChangesSemantic,
            loading: loading,
            child: Text(copy.saveChanges),
          ),
        ],
      ),
    );
  }

  List<Widget> _sectionToggles(bool loading, AppStrings copy) {
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
        copy.showFavorites,
        _sectionPrivacy.favorites,
        (value) => setState(
          () => _sectionPrivacy = _sectionPrivacy.copyWith(favorites: value),
        ),
      ),
      tile(
        copy.showActivity,
        _sectionPrivacy.activity,
        (value) => setState(
          () => _sectionPrivacy = _sectionPrivacy.copyWith(activity: value),
        ),
      ),
      tile(
        copy.showFriends,
        _sectionPrivacy.friends,
        (value) => setState(
          () => _sectionPrivacy = _sectionPrivacy.copyWith(friends: value),
        ),
      ),
      tile(
        copy.showFans,
        _sectionPrivacy.fans,
        (value) => setState(
          () => _sectionPrivacy = _sectionPrivacy.copyWith(fans: value),
        ),
      ),
      tile(
        copy.showWorks,
        _sectionPrivacy.works,
        (value) => setState(
          () => _sectionPrivacy = _sectionPrivacy.copyWith(works: value),
        ),
      ),
      tile(
        copy.showGroups,
        _sectionPrivacy.groups,
        (value) => setState(
          () => _sectionPrivacy = _sectionPrivacy.copyWith(groups: value),
        ),
      ),
      tile(
        copy.showRatings,
        _sectionPrivacy.ratings,
        (value) => setState(
          () => _sectionPrivacy = _sectionPrivacy.copyWith(ratings: value),
        ),
      ),
      tile(
        copy.showAchievements,
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
    final copy = AppStrings.of(context);
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) return;
    final usernameError = AuthValidators.username(_username.text);
    final requiredError = _username.text.trim().isEmpty
        ? copy.usernameRequired
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
    required this.publicLabel,
    required this.privateLabel,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String publicLabel;
  final String privateLabel;
  final String label;
  final String value;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: <DropdownMenuItem<String>>[
        DropdownMenuItem(value: 'public', child: Text(publicLabel)),
        DropdownMenuItem(value: 'private', child: Text(privateLabel)),
      ],
      onChanged: onChanged == null
          ? null
          : (value) {
              if (value != null) onChanged!(value);
            },
    );
  }
}
