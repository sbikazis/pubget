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
import '../../fan_works/l10n/fan_work_copy.dart';
import '../models/profile_section_privacy.dart';
import '../models/profile_social_link.dart';
import '../models/public_profile.dart';
import '../models/social_models.dart';
import '../providers/profile_provider.dart';
import '../providers/social_provider.dart';
import '../widgets/profile_chrome.dart';
import '../../anime/l10n/anime_copy.dart';
import '../../anime/models/anime_list_models.dart';
import '../../anime/providers/anime_library_provider.dart';
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
            label: copy.myEvents,
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
      trailing: Icon(
        Directionality.of(context) == TextDirection.rtl
            ? Icons.chevron_left
            : Icons.chevron_right,
      ),
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
      handle:
          pub.distinctHandle ??
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
                  '${copy.animeTwin} · ${data.animeTwin}',
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
                  title: copy.favoriteAnime,
                  onTap: () => AppNavigation.go(
                    context,
                    profileId.isEmpty
                        ? '/anime/me'
                        : '/anime/me?uid=${Uri.encodeComponent(profileId)}',
                  ),
                ),
              ],
              if (profile.isOwner || data.privacy.lists) ...[
                const SizedBox(height: AppSpacing.md),
                _AnimeListsSection(
                  profileId: profileId,
                  isOwner: profile.isOwner,
                  privacy: data.privacy,
                ),
              ],
              if (profile.isOwner || data.privacy.works) ...[
                const SizedBox(height: AppSpacing.md),
                _CollapsedSectionButton(
                  key: const Key('profile-fan-works-entry'),
                  icon: Icons.brush_outlined,
                  title: FanWorkCopy.of(context).feedTitle,
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
                  title: copy.homeGroups,
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
                                if (activityVisible && data.createdAt != null)
                                  _MetaChip(
                                    key: const Key('profile-meta-member'),
                                    icon: Icons.schedule_outlined,
                                    label: _memberSince(data.createdAt!, copy),
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
                    child: Text(copy.bioEmptyCta),
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

  static String _memberSince(DateTime createdAt, AppStrings copy) {
    final local = createdAt.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    return copy.memberSince('${local.year}-$month');
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
                  Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.chevron_left_rounded
                        : Icons.chevron_right_rounded,
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
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
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
    final copy = AppStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(copy.giveRespect, style: Theme.of(context).textTheme.titleMedium),
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
          semanticLabel: copy.giveRespectSemantic,
          loading: social.state == LoadingState.loading,
          child: Text(copy.saveRespect),
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
      return context.read<EditsRepository>().getCreatorEdits(widget.profileId);
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
            message: AppStrings.of(context).couldNotLoadEdits,
            onRetry: () => setState(() => _future = _load()),
          );
        }
        final edits = snapshot.data?.valueOrNull ?? const <Edit>[];
        final copy = AppStrings.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ProfileSectionHeader(title: copy.edits),
            if (edits.isEmpty)
              PubgetEmptyState(
                compact: true,
                icon: Icons.movie_creation_outlined,
                title: widget.isOwner ? copy.noEditsYet : copy.noEditsToShow,
                message: widget.isOwner
                    ? copy.cutSceneCta
                    : copy.creatorNoEdits,
                action: widget.isOwner
                    ? PubgetTextButton(
                        onPressed: () => AppNavigation.go(context, '/edits'),
                        semanticLabel: copy.openEdits,
                        child: Text(copy.createAnEdit),
                      )
                    : null,
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: edits.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
        onTap: () =>
            AppNavigation.go(context, PubgetLinks.editHighlightPath(edit.id)),
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
    final copy = AppStrings.of(context);
    if (!social.canStartPrivateChatWith(profileId)) {
      return const SizedBox.shrink();
    }
    return PubgetPrimaryButton(
      key: const Key('profile-start-chat'),
      onPressed: social.state == LoadingState.loading
          ? null
          : () => _start(context),
      semanticLabel: copy.startChatSemantic,
      leadingIcon: Icons.chat_bubble_outline,
      child: Text(copy.startChat),
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
          result.failureOrNull?.message ??
          AppStrings.of(context).couldNotStartChat;
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
    final copy = AppStrings.of(context);
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
      semanticLabel: blockedByMe ? copy.unblockUser : copy.blockUser,
      leadingIcon: blockedByMe
          ? Icons.lock_open_outlined
          : Icons.block_outlined,
      child: Text(blockedByMe ? copy.unblockUser : copy.blockUser),
    );
  }

  Future<void> _confirmBlock(
    BuildContext context,
    SocialProvider social,
  ) async {
    final copy = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(copy.blockUserConfirmTitle),
        content: Text(copy.blockUserConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(copy.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(copy.block),
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
    final copy = AppStrings.of(context);
    final me = context.read<AuthProvider>().currentUser?.id;
    final relation = social.snapshot.relationWith(profileId);
    if (relation?.status == FriendshipStatus.accepted) {
      return PubgetSecondaryButton(
        onPressed: () => social.removeFriend(profileId),
        semanticLabel: copy.removeFriend,
        child: Text(copy.removeFriend),
      );
    }
    if (relation?.status == FriendshipStatus.pending) {
      final iRequested = relation!.requestedBy == me;
      return PubgetSecondaryButton(
        onPressed: iRequested
            ? () => social.cancelFriendRequest(profileId)
            : () => social.respondToFriendRequest(
                otherUserId: profileId,
                accept: true,
              ),
        semanticLabel: iRequested
            ? copy.cancelFriendRequest
            : copy.acceptFriendRequest,
        child: Text(iRequested ? copy.cancelRequest : copy.acceptRequest),
      );
    }
    if (relation?.status == FriendshipStatus.blocked) {
      return PubgetSecondaryButton(
        onPressed: relation?.blockedBy == me
            ? () => social.unblockUser(profileId)
            : null,
        semanticLabel: copy.unblockUser,
        child: Text(copy.unblock),
      );
    }
    return PubgetSecondaryButton(
      key: const Key('profile-add-friend'),
      onPressed: () => social.sendFriendRequest(toUserId: profileId),
      semanticLabel: copy.sendFriendRequest,
      leadingIcon: Icons.person_add_alt_1_outlined,
      child: Text(copy.addFriend),
    );
  }
}

class _AnimeListsSection extends StatelessWidget {
  const _AnimeListsSection({
    required this.profileId,
    required this.isOwner,
    required this.privacy,
  });

  final String profileId;
  final bool isOwner;
  final ProfileSectionPrivacy privacy;

  @override
  Widget build(BuildContext context) {
    return Consumer<AnimeLibraryProvider>(
      builder: (context, library, _) {
        if (!isOwner && !privacy.lists) return const SizedBox.shrink();
        final entries = library.entries;
        if (entries.isEmpty && library.customLists.isEmpty) {
          return const SizedBox.shrink();
        }
        final copy = AnimeCopy.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: AppSpacing.xl),
            ProfileSectionHeader(title: copy.myLibrary),
            const SizedBox(height: AppSpacing.md),
            _StandardListsGrid(entries: entries),
            if (library.customLists.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              _CustomListsGrid(
                lists: library.customLists,
                isOwner: isOwner,
                profileId: profileId,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _StandardListsGrid extends StatelessWidget {
  const _StandardListsGrid({required this.entries});

  final List<AnimeListEntry> entries;

  @override
  Widget build(BuildContext context) {
    const statuses = AnimeListStatus.tabs;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (final status in statuses)
          _StandardListChip(
            status: status,
            count: entries.where((e) => e.status == status).length,
          ),
      ],
    );
  }
}

class _StandardListChip extends StatelessWidget {
  const _StandardListChip({required this.status, required this.count});

  final AnimeListStatus status;
  final int count;

  @override
  Widget build(BuildContext context) {
    final copy = AnimeCopy.of(context);
    return Material(
      color: AppColors.darkSurfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: () => AppNavigation.go(
          context,
          '/anime/me?status=${status.name}&uid=${Uri.encodeComponent(context.read<AuthProvider>().currentUser?.id ?? '')}',
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                _iconForStatus(status),
                size: 16,
                color: _colorForStatus(status, context),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                _labelForStatus(status, copy),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.darkText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: _colorForStatus(
                    status,
                    context,
                  ).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '$count',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: _colorForStatus(status, context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForStatus(AnimeListStatus status) {
    return switch (status) {
      AnimeListStatus.wantToWatch => Icons.bookmark_border,
      AnimeListStatus.watching => Icons.play_circle_outline,
      AnimeListStatus.completed => Icons.check_circle_outline,
      AnimeListStatus.watchLater => Icons.schedule_outlined,
      AnimeListStatus.notInterested => Icons.cancel_outlined,
    };
  }

  Color _colorForStatus(AnimeListStatus status, BuildContext context) {
    return switch (status) {
      AnimeListStatus.wantToWatch => AppColors.info,
      AnimeListStatus.watching => AppColors.royalPurple,
      AnimeListStatus.completed => AppColors.success,
      AnimeListStatus.watchLater => AppColors.warning,
      AnimeListStatus.notInterested => AppColors.error,
    };
  }

  String _labelForStatus(AnimeListStatus status, AnimeCopy copy) {
    return copy.listStatusLabel(status);
  }
}

class _CustomListsGrid extends StatelessWidget {
  const _CustomListsGrid({
    required this.lists,
    required this.isOwner,
    required this.profileId,
  });

  final List<AnimeCustomList> lists;
  final bool isOwner;
  final String profileId;

  @override
  Widget build(BuildContext context) {
    final visibleLists = lists
        .where((list) => isOwner || !list.private)
        .toList(growable: false);
    if (visibleLists.isEmpty) return const SizedBox.shrink();
    final copy = AnimeCopy.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          copy.customListsTitle,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.royalPurple,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final list in visibleLists)
              _CustomListChip(
                list: list,
                isOwner: isOwner,
                profileId: profileId,
              ),
          ],
        ),
      ],
    );
  }
}

class _CustomListChip extends StatelessWidget {
  const _CustomListChip({
    required this.list,
    required this.isOwner,
    required this.profileId,
  });

  final AnimeCustomList list;
  final bool isOwner;
  final String profileId;

  @override
  Widget build(BuildContext context) {
    final isPrivate = list.private && isOwner;
    return Container(
      decoration: BoxDecoration(
        color: isPrivate
            ? AppColors.warning.withValues(alpha: 0.15)
            : AppColors.darkSurfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isPrivate
              ? AppColors.warning.withValues(alpha: 0.5)
              : AppColors.darkOutline.withValues(alpha: 0.4),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => AppNavigation.go(
            context,
            '/anime/list/${Uri.encodeComponent(list.id)}',
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (list.private && isOwner) ...[
                  Icon(Icons.lock_outline, size: 16, color: AppColors.warning),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Text(
                  list.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.darkText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: isPrivate
                        ? AppColors.warning.withValues(alpha: 0.2)
                        : AppColors.royalPurple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '${list.itemsCount}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isPrivate
                          ? AppColors.warning
                          : AppColors.royalPurple,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
