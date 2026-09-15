import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../app/app_router.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/links/pubget_links.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/errors/result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../achievements/l10n/achievement_copy.dart';
import '../../achievements/models/achievement_models.dart';
import '../../achievements/providers/achievement_provider.dart';
import '../../achievements/widgets/achievement_badge_widget.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../economy/providers/economy_provider.dart';
import '../../economy/widgets/economy_widgets.dart';
import '../../edits/models/edit_models.dart';
import '../../edits/repositories/edits_repository.dart';
import '../../fan_works/models/fan_work_lifecycle.dart';
import '../models/profile_section_privacy.dart';
import '../models/profile_social_link.dart';
import '../models/public_profile.dart';
import '../models/social_models.dart';
import '../providers/profile_provider.dart';
import '../providers/social_provider.dart';
import '../widgets/profile_chrome.dart';
import '../../private_chat/providers/private_chat_list_provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({this.userId, super.key});

  final String? userId;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _requestedLoad = false;
  int _respect = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requestedLoad) return;
    final viewerId = context.read<AuthProvider>().currentUser?.id;
    if (viewerId == null) return;
    _requestedLoad = true;
    final profileId = widget.userId ?? viewerId;
    final profileProvider = context.read<ProfileProvider>();
    final socialProvider = context.read<SocialProvider>();
    Future<void>.microtask(() async {
      await Future.wait<void>([
        profileProvider.load(viewerId: viewerId, profileId: profileId),
        socialProvider.load(viewerId),
      ]);
      if (!mounted || profileId == viewerId) return;
      final given = socialProvider.snapshot.givenRespect.where(
        (item) => item.toUserId == profileId,
      );
      if (given.isNotEmpty) setState(() => _respect = given.first.value);
      try {
        await context.read<AchievementProvider>().open(profileId);
      } on ProviderNotFoundException {
        // Achievements are optional on thin test trees.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final currentUserId = context.watch<AuthProvider>().currentUser?.id;
    final profileId = widget.userId ?? currentUserId ?? '';
    final copy = AppStrings.of(context);
    final public = profile.publicProfile;
    final viewerUsername = public?.username?.trim();
    final viewerTitle = (viewerUsername == null || viewerUsername.isEmpty)
        ? (public?.primaryName() ?? copy.profile)
        : '@$viewerUsername';
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(profile.isOwner ? copy.myProfile : viewerTitle),
        actions: <Widget>[
          if (profile.isOwner && profileId.isNotEmpty)
            PubgetIconButton(
              key: const Key('profile-manage-button'),
              icon: Icons.more_vert_rounded,
              tooltip: copy.manageProfile,
              onPressed: () => _openManageSheet(context, profileId),
            )
          else if (profileId.isNotEmpty)
            PubgetIconButton(
              key: const Key('profile-share-button'),
              icon: Icons.share_outlined,
              tooltip: copy.shareProfile,
              onPressed: () => _openShareSheet(context, profileId),
            ),
        ],
      ),
      body: PubgetAtmosphere(
        child: SafeArea(
          child: PubgetLoadingStateView(
            state: profile.state,
            onRetry: () => _reload(profileId),
            error: PubgetErrorState(
              message: profile.failure?.message ?? copy.profileFailed,
              onRetry: () => _reload(profileId),
            ),
            offline: PubgetOfflineState(onRetry: () => _reload(profileId)),
            empty: PubgetEmptyState(
              title: copy.profileUnavailable,
              message: copy.profilePrivate,
            ),
            child: _ProfileLifeReport(
              profileId: profileId,
              respect: _respect,
              onRespectChanged: (value) => setState(() => _respect = value),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _reload(String profileId) async {
    final viewerId = context.read<AuthProvider>().currentUser?.id;
    if (viewerId == null) return;
    await context.read<ProfileProvider>().load(
      viewerId: viewerId,
      profileId: profileId,
    );
  }
}

void _openManageSheet(BuildContext context, String profileId) {
  final copy = AppStrings.of(context);
  final profileName =
      context.read<ProfileProvider>().publicProfile?.primaryName() ??
      context.read<ProfileProvider>().ownProfile?.primaryName ??
      copy.profile;
  final url = PubgetLinks.profile(profileId);
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: <Widget>[
          _ManageSheetTile(
            key: const Key('profile-manage-edit'),
            icon: Icons.edit_outlined,
            label: copy.editProfile,
            onTap: () async {
              Navigator.pop(sheetContext);
              await AppNavigation.go(context, '/profile/edit');
            },
          ),
          _ManageSheetTile(
            icon: Icons.workspace_premium_outlined,
            label: copy.drawerPremium,
            onTap: () async {
              Navigator.pop(sheetContext);
              await AppNavigation.go(context, '/premium');
            },
          ),
          _ManageSheetTile(
            icon: Icons.storefront_outlined,
            label: copy.store,
            onTap: () async {
              Navigator.pop(sheetContext);
              await AppNavigation.go(context, '/store');
            },
          ),
          _ManageSheetTile(
            icon: Icons.settings_outlined,
            label: copy.settings,
            onTap: () async {
              Navigator.pop(sheetContext);
              await AppNavigation.go(context, '/settings');
            },
          ),
          _ManageSheetTile(
            key: const Key('profile-manage-copy'),
            icon: Icons.copy_outlined,
            label: copy.copyLink,
            onTap: () {
              Navigator.pop(sheetContext);
              PubgetLinks.copy(context, url, type: 'profile');
            },
          ),
          _ManageSheetTile(
            key: const Key('profile-manage-share'),
            icon: Icons.share_outlined,
            label: copy.shareProfile,
            onTap: () {
              Navigator.pop(sheetContext);
              PubgetLinks.share(
                context,
                url: url,
                title: profileName,
                type: 'profile',
              );
            },
          ),
          _ManageSheetTile(
            icon: Icons.person_add_alt_1_outlined,
            label:
                '${copy.friendRequests} (${context.read<SocialProvider>().incomingRequests.length})',
            onTap: () async {
              Navigator.pop(sheetContext);
              await AppNavigation.go(context, '/friend-requests');
            },
          ),
          _ManageSheetTile(
            icon: Icons.event_note_outlined,
            label: 'My Events',
            onTap: () async {
              Navigator.pop(sheetContext);
              await AppNavigation.go(context, '/events');
            },
          ),
        ],
      ),
    ),
  );
}

void _openShareSheet(BuildContext context, String profileId) {
  final copy = AppStrings.of(context);
  final url = PubgetLinks.profile(profileId);
  final title =
      context.read<ProfileProvider>().publicProfile?.primaryName() ??
      copy.profile;
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: <Widget>[
          _ManageSheetTile(
            key: const Key('profile-share-share'),
            icon: Icons.share_outlined,
            label: copy.shareProfile,
            onTap: () {
              Navigator.pop(sheetContext);
              PubgetLinks.share(
                context,
                url: url,
                title: title,
                type: 'profile',
              );
            },
          ),
          _ManageSheetTile(
            key: const Key('profile-share-copy'),
            icon: Icons.copy_outlined,
            label: copy.copyLink,
            onTap: () {
              Navigator.pop(sheetContext);
              PubgetLinks.copy(context, url, type: 'profile');
            },
          ),
        ],
      ),
    ),
  );
}

class _ManageSheetTile extends StatelessWidget {
  const _ManageSheetTile({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.royalPurple),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _ProfileViewData {
  const _ProfileViewData({
    required this.name,
    required this.handle,
    required this.avatarUrl,
    required this.coverUrl,
    required this.bio,
    required this.age,
    required this.country,
    required this.favoriteQuote,
    required this.animeTwin,
    required this.socialLinks,
    required this.totalRespect,
    required this.fansCount,
    required this.favoriteLabels,
    required this.privacy,
    required this.createdAt,
    required this.frameId,
    required this.badgeId,
    required this.isPremium,
  });

  final String name;
  final String? handle;
  final String? avatarUrl;
  final String? coverUrl;
  final String? bio;
  final int? age;
  final String? country;
  final String? favoriteQuote;
  final String? animeTwin;
  final List<ProfileSocialLink> socialLinks;
  final int totalRespect;
  final int fansCount;
  final List<String> favoriteLabels;
  final ProfileSectionPrivacy privacy;
  final DateTime? createdAt;
  final String? frameId;
  final String? badgeId;
  final bool isPremium;

  factory _ProfileViewData.from({
    required ProfileProvider profile,
    required SocialProvider social,
    EconomyProvider? economy,
  }) {
    final own = profile.ownProfile;
    final public = profile.publicProfile;
    if (profile.isOwner && own != null) {
      return _ProfileViewData(
        name: own.primaryName,
        handle: own.username == null || own.username!.trim().isEmpty
            ? null
            : '@${own.username}',
        avatarUrl: own.avatarUrl,
        coverUrl: own.coverUrl,
        bio: own.bio,
        age: own.age,
        country: own.country,
        favoriteQuote: own.favoriteQuote,
        animeTwin: own.animeTwin,
        socialLinks: own.socialLinks,
        totalRespect: own.totalRespect,
        fansCount: own.fansCount,
        favoriteLabels: <String>{
          ...own.favoriteAnimes,
          ...own.favoriteAnimeIds,
        }.where((item) => item.trim().isNotEmpty).toList(growable: false),
        privacy: own.sectionPrivacy,
        createdAt: own.createdAt,
        frameId: economy?.equipped.frameId,
        badgeId: economy?.equipped.badgeId,
        isPremium: economy?.isPremium == true,
      );
    }
    final pub = public ?? const PublicProfile(uid: '');
    return _ProfileViewData(
      name: pub.primaryName(),
      handle: pub.distinctHandle ??
          (pub.username == null || pub.username!.trim().isEmpty
              ? null
              : '@${pub.username}'),
      avatarUrl: pub.avatarUrl,
      coverUrl: pub.coverUrl,
      bio: pub.bio,
      age: pub.age,
      country: pub.country,
      favoriteQuote: pub.favoriteQuote,
      animeTwin: pub.animeTwin,
      socialLinks: pub.socialLinks,
      totalRespect: pub.totalRespect,
      fansCount: pub.sectionPrivacy.fans ? pub.fansCount : 0,
      favoriteLabels: pub.sectionPrivacy.favorites
          ? <String>{
              ...pub.favoriteAnimes,
              ...pub.favoriteAnimeIds,
            }.where((item) => item.trim().isNotEmpty).toList(growable: false)
          : const <String>[],
      privacy: pub.sectionPrivacy,
      createdAt: pub.createdAt,
      frameId: pub.equippedFrameId,
      badgeId: pub.equippedBadgeId,
      isPremium: false,
    );
  }
}

class _ProfileLifeReport extends StatelessWidget {
  const _ProfileLifeReport({
    required this.profileId,
    required this.respect,
    required this.onRespectChanged,
  });

  final String profileId;
  final int respect;
  final ValueChanged<int> onRespectChanged;

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final social = context.watch<SocialProvider>();
    final economy = maybeEconomy(context);
    final data = _ProfileViewData.from(
      profile: profile,
      social: social,
      economy: economy,
    );
    final copy = AppStrings.of(context);
    final fansVisible = profile.isOwner || data.privacy.fans;
    final friendsVisible = profile.isOwner && data.privacy.friends;

    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        _ProfileHero(
          data: data,
          isOwner: profile.isOwner,
          profileId: profileId,
          privacy: data.privacy,
          activityVisible: profile.isOwner || data.privacy.activity,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  ProfileStatPill(
                    label: copy.respect,
                    value: data.totalRespect,
                    icon: Icons.favorite_border_rounded,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (fansVisible)
                    ProfileStatPill(
                      label: copy.fans,
                      value: data.fansCount,
                      icon: Icons.groups_2_outlined,
                    )
                  else
                    const Spacer(),
                  if (friendsVisible) ...[
                    const SizedBox(width: AppSpacing.sm),
                    ProfileStatPill(
                      label: copy.friends,
                      value: social.friends.length,
                      icon: Icons.handshake_outlined,
                    ),
                  ],
                ],
              ),
              if (data.favoriteQuote != null &&
                  data.favoriteQuote!.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                _QuoteCard(quote: data.favoriteQuote!.trim()),
              ],
              if (data.animeTwin != null &&
                  data.animeTwin!.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Anime twin · ${data.animeTwin}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.royalPurpleDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (profile.isOwner)
                const SizedBox.shrink()
              else
                _VisitorActions(
                  profileId: profileId,
                  respect: respect,
                  onRespectChanged: onRespectChanged,
                ),
              const SizedBox(height: AppSpacing.xl),
              if (profile.isOwner || data.privacy.achievements)
                _CollapsedSectionButton(
                  key: const Key('profile-achievements-entry'),
                  icon: Icons.emoji_events_outlined,
                  title: AchievementCopy.of(context).entryLabel(
                    isOwner: profile.isOwner,
                    displayName: data.name,
                  ),
                  onTap: () => _openAchievements(
                    context,
                    profileId: profileId,
                    displayName: data.name,
                    isOwner: profile.isOwner,
                  ),
                ),
              if (profile.isOwner || data.privacy.favorites) ...[
                const SizedBox(height: AppSpacing.md),
                _CollapsedSectionButton(
                  key: const Key('profile-favorites-entry'),
                  icon: Icons.favorite_outline_rounded,
                  title: 'Favorite anime',
                  onTap: () => AppNavigation.go(
                    context,
                    profileId.isEmpty
                        ? '/anime/me'
                        : '/anime/me?uid=${Uri.encodeComponent(profileId)}',
                  ),
                ),
              ],
              if (profile.isOwner || data.privacy.works) ...[
                const SizedBox(height: AppSpacing.md),
                _CollapsedSectionButton(
                  key: const Key('profile-fan-works-entry'),
                  icon: Icons.brush_outlined,
                  title: FanWorkStrings.feedTitle,
                  onTap: () => AppNavigation.go(
                    context,
                    '/fan-works-creator?uid=${Uri.encodeComponent(profileId)}',
                  ),
                ),
              ],
              if (profile.isOwner || data.privacy.groups) ...[
                const SizedBox(height: AppSpacing.md),
                _CollapsedSectionButton(
                  key: const Key('profile-groups-entry'),
                  icon: Icons.groups_outlined,
                  title: 'Groups',
                  onTap: () => AppNavigation.go(
                    context,
                    '/profile-groups?uid=${Uri.encodeComponent(profileId)}',
                  ),
                ),
              ],
              if (profile.isOwner || data.privacy.works) ...[
                const SizedBox(height: AppSpacing.xl),
                _EditsGrid(profileId: profileId, isOwner: profile.isOwner),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.data,
    required this.isOwner,
    required this.profileId,
    required this.privacy,
    required this.activityVisible,
  });

  final _ProfileViewData data;
  final bool isOwner;
  final String profileId;
  final ProfileSectionPrivacy privacy;
  final bool activityVisible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = AppStrings.of(context);
    return Column(
      children: <Widget>[
        SizedBox(
          height: 188,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        AppColors.royalPurpleDark,
                        AppColors.royalTwilight,
                        AppColors.royalHorizon,
                      ],
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      if (data.coverUrl == null || data.coverUrl!.isEmpty)
                        CustomPaint(painter: _CoverPatternPainter())
                      else
                        AppImageLoader(
                          imageUrl: data.coverUrl!,
                          fit: BoxFit.cover,
                        ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              Colors.transparent,
                              AppColors.darkBackground,
                            ],
                            stops: <double>[0.55, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                bottom: -36,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    EquippedAvatar(
                      imageUrl: data.avatarUrl,
                      name: data.name,
                      frameId: data.frameId,
                      size: PubgetAvatarSize.large,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    data.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (data.isPremium) ...[
                                  const SizedBox(width: AppSpacing.sm),
                                  const ProfilePremiumChip(),
                                ],
                              ],
                            ),
                            if (data.handle != null)
                              Text(
                                data.handle!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.goldLight,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: 4,
                              children: <Widget>[
                                if (data.age != null)
                                  _MetaChip(
                                    key: const Key('profile-meta-age'),
                                    icon: Icons.cake_outlined,
                                    label: '${data.age}',
                                  ),
                                if (data.country != null &&
                                    data.country!.trim().isNotEmpty)
                                  _MetaChip(
                                    key: const Key('profile-meta-country'),
                                    icon: Icons.public_outlined,
                                    label: data.country!.trim(),
                                  ),
                                if (activityVisible &&
                                    data.createdAt != null)
                                  _MetaChip(
                                    key: const Key('profile-meta-member'),
                                    icon: Icons.schedule_outlined,
                                    label: _memberSince(data.createdAt!),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 44),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (data.bio != null && data.bio!.trim().isNotEmpty)
                Text(
                  data.bio!.trim(),
                  key: const Key('profile-bio'),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.darkText,
                    height: 1.35,
                  ),
                )
              else if (isOwner)
                Padding(
                  padding: EdgeInsets.zero,
                  child: PubgetSecondaryButton(
                    key: const Key('profile-bio-invite'),
                    onPressed: () => AppNavigation.go(context, '/profile/edit'),
                    semanticLabel: copy.editProfile,
                    leadingIcon: Icons.edit_outlined,
                    child: const Text('Add a bio so people can meet you'),
                  ),
                ),
              _ProfileAchievementStrip(
                profileId: profileId,
                displayName: data.name,
                isOwner: isOwner,
              ),
              if (data.socialLinks.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                ProfileSocialLinkChips(links: data.socialLinks),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _memberSince(DateTime createdAt) {
    final local = createdAt.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    return 'Since ${local.year}-$month';
  }
}

class _ProfileAchievementStrip extends StatelessWidget {
  const _ProfileAchievementStrip({
    required this.profileId,
    required this.displayName,
    required this.isOwner,
  });

  final String profileId;
  final String displayName;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    List<AchievementItem> unlocked = const <AchievementItem>[];
    try {
      unlocked = context.watch<AchievementProvider>().unlocked;
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }
    if (unlocked.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: SizedBox(
        height: kAchievementStripBadgeSize,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: unlocked.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (context, index) {
            final item = unlocked[index];
            return AchievementBadgeWidget(
              key: Key('profile-strip-badge-${item.id}'),
              item: item,
              size: kAchievementStripBadgeSize,
              animate: true,
              onTap: () => _openAchievements(
                context,
                profileId: profileId,
                displayName: displayName,
                isOwner: isOwner,
              ),
            );
          },
        ),
      ),
    );
  }
}

void _openAchievements(
  BuildContext context, {
  required String profileId,
  required String displayName,
  required bool isOwner,
}) {
  final encoded = Uri.encodeComponent(displayName);
  AppNavigation.go(
    context,
    '/achievements?userId=$profileId&name=$encoded&owner=${isOwner ? 1 : 0}',
  );
}

class _CollapsedSectionButton extends StatelessWidget {
  const _CollapsedSectionButton({
    required this.icon,
    required this.title,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.darkSurfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: AppColors.darkOutline.withValues(alpha: 0.4),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: <Widget>[
                  Icon(icon, color: AppColors.royalPurpleLight),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.darkText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.darkTextMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label, super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: AppColors.goldLight),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: AppColors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.quote});

  final String quote;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.royalPurplePale.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.royalPurpleLight.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        '“$quote”',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontStyle: FontStyle.italic,
          color: AppColors.royalPurpleDark,
        ),
      ),
    );
  }
}

class _CoverPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = -4; i < 12; i++) {
      final x = i * 48.0;
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _VisitorActions extends StatelessWidget {
  const _VisitorActions({
    required this.profileId,
    required this.respect,
    required this.onRespectChanged,
  });

  final String profileId;
  final int respect;
  final ValueChanged<int> onRespectChanged;

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Give Respect', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: List<Widget>.generate(
            8,
            (value) => PubgetSelectionChip(
              label: '$value',
              selected: respect == value,
              onSelected: social.state == LoadingState.loading
                  ? null
                  : (_) => onRespectChanged(value),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PubgetPrimaryButton(
          key: const Key('profile-give-respect'),
          onPressed: social.state == LoadingState.loading
              ? null
              : () => social.giveRespect(toUserId: profileId, value: respect),
          semanticLabel: 'Give selected Respect',
          loading: social.state == LoadingState.loading,
          child: const Text('Save Respect'),
        ),
        const SizedBox(height: AppSpacing.sm),
        _FriendAction(profileId: profileId),
        const SizedBox(height: AppSpacing.sm),
        _StartChatAction(profileId: profileId),
        const SizedBox(height: AppSpacing.sm),
        _BlockAction(profileId: profileId),
        if (social.failure != null) ...[
          const SizedBox(height: AppSpacing.md),
          PubgetErrorState(message: social.failure!.message),
        ],
      ],
    );
  }
}

class _EditsGrid extends StatefulWidget {
  const _EditsGrid({required this.profileId, required this.isOwner});

  final String profileId;
  final bool isOwner;

  @override
  State<_EditsGrid> createState() => _EditsGridState();
}

class _EditsGridState extends State<_EditsGrid> {
  Future<Result<List<Edit>>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<Result<List<Edit>>> _load() {
    try {
      return context.read<EditsRepository>().getCreatorEdits(
        widget.profileId,
      );
    } on ProviderNotFoundException {
      return Future<Result<List<Edit>>>.value(
        const Success<List<Edit>>(<Edit>[]),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Result<List<Edit>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(height: 1);
        }
        if (snapshot.hasError || snapshot.data is FailureResult) {
          return PubgetErrorState(
            message: 'Could not load edits.',
            onRetry: () => setState(() => _future = _load()),
          );
        }
        final edits = snapshot.data?.valueOrNull ?? const <Edit>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const ProfileSectionHeader(title: 'Edits'),
            if (edits.isEmpty)
              PubgetEmptyState(
                compact: true,
                icon: Icons.movie_creation_outlined,
                title: widget.isOwner
                    ? 'No edits published yet'
                    : 'No edits to show',
                message: widget.isOwner
                    ? 'Cut a scene and publish your first edit.'
                    : 'This creator has not shared edits yet.',
                action: widget.isOwner
                    ? PubgetTextButton(
                        onPressed: () => AppNavigation.go(context, '/edits'),
                        semanticLabel: 'Open edits',
                        child: const Text('Create an edit'),
                      )
                    : null,
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: edits.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: AppSpacing.xs,
                      crossAxisSpacing: AppSpacing.xs,
                      childAspectRatio: 0.7,
                    ),
                itemBuilder: (context, index) {
                  final edit = edits[index];
                  return _EditGridCell(edit: edit);
                },
              ),
          ],
        );
      },
    );
  }
}

class _EditGridCell extends StatelessWidget {
  const _EditGridCell({required this.edit});

  final Edit edit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.darkSurfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('profile-edit-cell-${edit.id}'),
        onTap: () => AppNavigation.go(
          context,
          PubgetLinks.editHighlightPath(edit.id),
        ),
        child: edit.hasPlayableVideo || edit.thumbnailUrl.isNotEmpty
            ? AppImageLoader(
                imageUrl: edit.thumbnailUrl,
                fit: BoxFit.cover,
                memCacheWidth: 320,
              )
            : const Center(
                child: Icon(
                  Icons.movie_creation_outlined,
                  color: AppColors.darkTextMuted,
                ),
              ),
      ),
    );
  }
}

class _StartChatAction extends StatelessWidget {
  const _StartChatAction({required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialProvider>();
    if (!social.canStartPrivateChatWith(profileId)) {
      return const SizedBox.shrink();
    }
    return PubgetPrimaryButton(
      key: const Key('profile-start-chat'),
      onPressed: social.state == LoadingState.loading
          ? null
          : () => _start(context),
      semanticLabel: 'Start a private chat',
      leadingIcon: Icons.chat_bubble_outline,
      child: const Text('Start chat'),
    );
  }

  Future<void> _start(BuildContext context) async {
    try {
      final list = context.read<PrivateChatListProvider>();
      final result = await list.startChat(profileId);
      if (!context.mounted) return;
      final chatId = result.valueOrNull;
      if (chatId != null) {
        await AppNavigation.go(
          context,
          '/private-chat?chatId=${Uri.encodeComponent(chatId)}',
        );
        return;
      }
      final message =
          result.failureOrNull?.message ?? 'Could not start this private chat.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on ProviderNotFoundException {
      return;
    }
  }
}

class _BlockAction extends StatelessWidget {
  const _BlockAction({required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialProvider>();
    final relation = social.snapshot.relationWith(profileId);
    final currentUserId = context.read<AuthProvider>().currentUser?.id;
    final blockedByMe =
        relation?.status == FriendshipStatus.blocked &&
        relation?.blockedBy == currentUserId;
    final blockedByOther =
        relation?.status == FriendshipStatus.blocked && !blockedByMe;

    return PubgetSecondaryButton(
      key: const Key('profile-block-user'),
      onPressed: social.state == LoadingState.loading || blockedByOther
          ? null
          : blockedByMe
          ? () => social.unblockUser(profileId)
          : () => _confirmBlock(context, social),
      semanticLabel: blockedByMe ? 'Unblock user' : 'Block user',
      leadingIcon: blockedByMe
          ? Icons.lock_open_outlined
          : Icons.block_outlined,
      child: Text(blockedByMe ? 'Unblock user' : 'Block user'),
    );
  }

  Future<void> _confirmBlock(
    BuildContext context,
    SocialProvider social,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Block this user?'),
        content: const Text(
          'They will no longer be able to interact with this relationship.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (confirmed == true) await social.blockUser(profileId);
  }
}

class _FriendAction extends StatelessWidget {
  const _FriendAction({required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialProvider>();
    final relation = social.snapshot.relationWith(profileId);
    if (relation?.status == FriendshipStatus.accepted) {
      return PubgetSecondaryButton(
        onPressed: () => social.removeFriend(profileId),
        semanticLabel: 'Remove friend',
        child: const Text('Remove friend'),
      );
    }
    if (relation?.status == FriendshipStatus.pending) {
      return PubgetSecondaryButton(
        onPressed:
            relation!.requestedBy ==
                context.read<AuthProvider>().currentUser?.id
            ? () => social.respondToFriendRequest(
                otherUserId: profileId,
                accept: false,
              )
            : () => social.respondToFriendRequest(
                otherUserId: profileId,
                accept: true,
              ),
        semanticLabel:
            relation.requestedBy == context.read<AuthProvider>().currentUser?.id
            ? 'Cancel friend request'
            : 'Accept friend request',
        child: Text(
          relation.requestedBy == context.read<AuthProvider>().currentUser?.id
              ? 'Cancel request'
              : 'Accept request',
        ),
      );
    }
    if (relation?.status == FriendshipStatus.blocked) {
      return PubgetSecondaryButton(
        onPressed:
            relation?.blockedBy ==
                context.read<AuthProvider>().currentUser?.id
            ? () => social.unblockUser(profileId)
            : null,
        semanticLabel: 'Unblock user',
        child: const Text('Unblock'),
      );
    }
    return PubgetSecondaryButton(
      key: const Key('profile-add-friend'),
      onPressed: () => social.sendFriendRequest(toUserId: profileId),
      semanticLabel: 'Send friend request',
      leadingIcon: Icons.person_add_alt_1_outlined,
      child: const Text('Add friend'),
    );
  }
}