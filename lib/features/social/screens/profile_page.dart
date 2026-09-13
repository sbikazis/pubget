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
import '../../fan_works/models/fan_work_models.dart';
import '../../fan_works/repositories/fan_work_repository.dart';
import '../../fan_works/widgets/fan_work_widgets.dart';
import '../../groups/models/group_models.dart';
import '../../groups/repositories/group_repository.dart';
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(profile.isOwner ? copy.myProfile : copy.profile),
        actions: <Widget>[
          if (profileId.isNotEmpty) ...<Widget>[
            PubgetIconButton(
              icon: Icons.share_outlined,
              tooltip: copy.shareProfile,
              onPressed: () => PubgetLinks.share(
                context,
                url: PubgetLinks.profile(profileId),
                title:
                    profile.publicProfile?.primaryName() ??
                    profile.ownProfile?.primaryName ??
                    copy.profile,
                type: 'profile',
              ),
            ),
            PubgetIconButton(
              icon: Icons.copy_outlined,
              tooltip: copy.copyLink,
              onPressed: () => PubgetLinks.copy(
                context,
                PubgetLinks.profile(profileId),
                type: 'profile',
              ),
            ),
          ],
          if (profile.isOwner)
            PubgetIconButton(
              icon: Icons.edit_outlined,
              tooltip: copy.editProfile,
              onPressed: () => AppNavigation.go(context, '/profile/edit'),
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
              const SizedBox(height: AppSpacing.xl),
              _AchievementsEntryButton(
                isOwner: profile.isOwner,
                displayName: data.name,
                profileId: profileId,
              ),
              const SizedBox(height: AppSpacing.md),
              if (profile.isOwner)
                _OwnerQuickActions(social: social, economy: economy)
              else
                _VisitorActions(
                  profileId: profileId,
                  respect: respect,
                  onRespectChanged: onRespectChanged,
                ),
              const SizedBox(height: AppSpacing.xl),
              if (profile.isOwner || data.privacy.favorites)
                _FavoritesSection(
                  profileId: profileId,
                  isOwner: profile.isOwner,
                  labels: data.favoriteLabels,
                ),
              if (profile.isOwner || data.privacy.works) ...[
                const SizedBox(height: AppSpacing.xl),
                _CreatorEdits(profileId: profileId, isOwner: profile.isOwner),
                const SizedBox(height: AppSpacing.xl),
                _CreatorFanWorks(
                  profileId: profileId,
                  isOwner: profile.isOwner,
                ),
              ],
              if (profile.isOwner || data.privacy.groups) ...[
                const SizedBox(height: AppSpacing.xl),
                _GroupsSection(profileId: profileId, isOwner: profile.isOwner),
              ],
              if (profile.isOwner || data.privacy.achievements) ...[
                const SizedBox(height: AppSpacing.xl),
                _AchievementsSection(
                  isOwner: profile.isOwner,
                  profileId: profileId,
                  displayName: data.name,
                ),
              ],
              if ((profile.isOwner || data.privacy.activity) &&
                  data.createdAt != null) ...[
                const SizedBox(height: AppSpacing.xl),
                _ActivitySection(createdAt: data.createdAt!),
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
  });

  final _ProfileViewData data;
  final bool isOwner;
  final String profileId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                  child: data.coverUrl == null || data.coverUrl!.isEmpty
                      ? CustomPaint(painter: _CoverPatternPainter())
                      : AppImageLoader(
                          imageUrl: data.coverUrl!,
                          fit: BoxFit.cover,
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
                                    icon: Icons.cake_outlined,
                                    label: '${data.age}',
                                  ),
                                if (data.country != null &&
                                    data.country!.trim().isNotEmpty)
                                  _MetaChip(
                                    icon: Icons.public_outlined,
                                    label: data.country!.trim(),
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
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.lightText,
                    height: 1.35,
                  ),
                )
              else if (isOwner)
                Text(
                  'Add a short bio so people can meet the real you.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.lightTextMuted,
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

class _AchievementsEntryButton extends StatelessWidget {
  const _AchievementsEntryButton({
    required this.isOwner,
    required this.displayName,
    required this.profileId,
  });

  final bool isOwner;
  final String displayName;
  final String profileId;

  @override
  Widget build(BuildContext context) {
    final copy = AchievementCopy.of(context);
    final label = copy.entryLabel(isOwner: isOwner, displayName: displayName);
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          gradient: LinearGradient(
            colors: <Color>[
              AppColors.royalPurple.withValues(alpha: 0.9),
              AppColors.royalPurpleDark,
            ],
          ),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.55)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('profile-achievements-entry'),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            onTap: () => _openAchievements(
              context,
              profileId: profileId,
              displayName: displayName,
              isOwner: isOwner,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.emoji_events, color: AppColors.gold),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.gold),
                ],
              ),
            ),
          ),
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

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
        border: Border.all(color: AppColors.royalPurpleLight.withValues(alpha: 0.35)),
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

class _OwnerQuickActions extends StatelessWidget {
  const _OwnerQuickActions({required this.social, required this.economy});

  final SocialProvider social;
  final EconomyProvider? economy;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        _ActionChipButton(
          key: const Key('profile-edit-chip'),
          icon: Icons.edit_outlined,
          label: copy.editProfile,
          onTap: () => AppNavigation.go(context, '/profile/edit'),
        ),
        _ActionChipButton(
          icon: Icons.person_add_alt_1_outlined,
          label: '${copy.friendRequests} (${social.incomingRequests.length})',
          onTap: () => AppNavigation.go(context, '/friend-requests'),
        ),
        if (economy != null) ...[
          _ActionChipButton(
            icon: Icons.storefront_outlined,
            label: copy.store,
            onTap: () => AppNavigation.go(context, '/store'),
          ),
          _ActionChipButton(
            icon: Icons.workspace_premium_outlined,
            label: copy.drawerPremium,
            onTap: () => AppNavigation.go(context, '/premium'),
          ),
        ],
      ],
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  const _ActionChipButton({
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
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onPressed: onTap,
    );
  }
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

class _FavoritesSection extends StatelessWidget {
  const _FavoritesSection({
    required this.profileId,
    required this.isOwner,
    required this.labels,
  });

  final String profileId;
  final bool isOwner;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ProfileSectionHeader(
          title: 'Favorite anime',
          onViewAll: () => AppNavigation.go(
            context,
            profileId.isEmpty
                ? '/anime/me'
                : '/anime/me?uid=${Uri.encodeComponent(profileId)}',
          ),
        ),
        if (labels.isEmpty)
          PubgetEmptyState(
            compact: true,
            icon: Icons.movie_outlined,
            title: isOwner
                ? 'No favorite anime yet'
                : 'No favorites to show',
            message: isOwner
                ? 'Discover anime and pin what you love.'
                : 'This collector is still exploring.',
            action: isOwner
                ? PubgetTextButton(
                    onPressed: () => AppNavigation.go(context, '/anime'),
                    semanticLabel: 'Discover anime',
                    child: const Text('Discover anime'),
                  )
                : null,
          )
        else
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: labels.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) =>
                  PubgetBadge(label: labels[index]),
            ),
          ),
      ],
    );
  }
}

class _CreatorEdits extends StatefulWidget {
  const _CreatorEdits({required this.profileId, required this.isOwner});
  final String profileId;
  final bool isOwner;

  @override
  State<_CreatorEdits> createState() => _CreatorEditsState();
}

class _CreatorEditsState extends State<_CreatorEdits> {
  late final Future<Result<List<Edit>>> _future;

  @override
  void initState() {
    super.initState();
    try {
      _future = context.read<EditsRepository>().getCreatorEdits(
        widget.profileId,
      );
    } on ProviderNotFoundException {
      _future = Future<Result<List<Edit>>>.value(
        const Success<List<Edit>>(<Edit>[]),
      );
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Result<List<Edit>>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const SizedBox(height: 1);
      }
      if (snapshot.hasError || snapshot.data is FailureResult) {
        return PubgetErrorState(
          message: 'Could not load edits.',
          onRetry: () => setState(() {}),
        );
      }
      final edits = snapshot.data?.valueOrNull ?? const <Edit>[];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ProfileSectionHeader(
            title: 'Edits',
            onViewAll: () => AppNavigation.go(context, '/edits'),
          ),
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
            SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: edits.take(12).length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) => SizedBox(
                  width: 100,
                  child: PubgetCard(
                    onTap: () => AppNavigation.go(context, '/edits'),
                    child: AppImageLoader(
                      imageUrl: edits[index].thumbnailUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _CreatorFanWorks extends StatefulWidget {
  const _CreatorFanWorks({required this.profileId, required this.isOwner});
  final String profileId;
  final bool isOwner;

  @override
  State<_CreatorFanWorks> createState() => _CreatorFanWorksState();
}

class _CreatorFanWorksState extends State<_CreatorFanWorks> {
  late final Future<Result<FanWorkListPage>> _future;

  @override
  void initState() {
    super.initState();
    try {
      _future = context.read<FanWorkRepository>().getCreatorWorks(
        creatorId: widget.profileId,
        limit: 12,
      );
    } on ProviderNotFoundException {
      _future = Future<Result<FanWorkListPage>>.value(
        const Success<FanWorkListPage>(
          FanWorkListPage(items: <FanWork>[], hasMore: false),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<Result<FanWorkListPage>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(height: 1);
          }
          if (snapshot.hasError || snapshot.data is FailureResult) {
            return const PubgetErrorState(
              message: 'Could not load fan works.',
            );
          }
          final works =
              snapshot.data?.valueOrNull?.items ?? const <FanWork>[];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ProfileSectionHeader(
                title: FanWorkStrings.feedTitle,
                onViewAll: () => AppNavigation.go(context, '/fan-works'),
              ),
              if (works.isEmpty)
                PubgetEmptyState(
                  compact: true,
                  icon: Icons.brush_outlined,
                  title: widget.isOwner
                      ? 'No fan works yet'
                      : 'No fan works to show',
                  message: widget.isOwner
                      ? 'Share a drawing, manga page, or story.'
                      : 'This creator has not shared works yet.',
                )
              else
                SizedBox(
                  height: 180,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: works.take(12).length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (context, index) => SizedBox(
                      width: 120,
                      child: FanWorkPreviewCard(work: works[index]),
                    ),
                  ),
                ),
            ],
          );
        },
      );
}

class _GroupsSection extends StatefulWidget {
  const _GroupsSection({required this.profileId, required this.isOwner});

  final String profileId;
  final bool isOwner;

  @override
  State<_GroupsSection> createState() => _GroupsSectionState();
}

class _GroupsSectionState extends State<_GroupsSection> {
  Future<Result<List<Group>>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<Result<List<Group>>> _load() async {
    try {
      return context.read<GroupRepository>().listJoinedGroups(widget.profileId);
    } on ProviderNotFoundException {
      return const Success<List<Group>>(<Group>[]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Result<List<Group>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(height: 1);
        }
        final groups = snapshot.data?.valueOrNull ?? const <Group>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ProfileSectionHeader(
              title: 'Groups',
              onViewAll: () => AppNavigation.go(context, '/groups'),
            ),
            if (groups.isEmpty)
              PubgetEmptyState(
                compact: true,
                icon: Icons.groups_outlined,
                title: widget.isOwner
                    ? 'No groups yet'
                    : 'No groups to show',
                message: widget.isOwner
                    ? 'Join a community or create your own.'
                    : 'Groups stay private or empty for now.',
                action: widget.isOwner
                    ? PubgetTextButton(
                        onPressed: () => AppNavigation.go(context, '/groups'),
                        semanticLabel: 'Open groups',
                        child: const Text('Explore groups'),
                      )
                    : null,
              )
            else
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: groups.take(12).length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return SizedBox(
                      width: 160,
                      child: PubgetCard(
                        onTap: () => AppNavigation.go(
                          context,
                          '/group?groupId=${Uri.encodeComponent(group.id)}',
                        ),
                        child: Row(
                          children: <Widget>[
                            PubgetAvatar(
                              imageUrl: group.imageUrl,
                              name: group.name,
                              size: PubgetAvatarSize.small,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                group.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AchievementsSection extends StatelessWidget {
  const _AchievementsSection({
    required this.isOwner,
    required this.profileId,
    required this.displayName,
  });

  final bool isOwner;
  final String profileId;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    List<AchievementItem> items = const <AchievementItem>[];
    try {
      items = context.watch<AchievementProvider>().unlocked;
    } on ProviderNotFoundException {
      items = const <AchievementItem>[];
    }
    final copy = AchievementCopy.of(context);
    final preview = items.take(8).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ProfileSectionHeader(
          title: copy.title,
          onViewAll: () => _openAchievements(
            context,
            profileId: profileId,
            displayName: displayName,
            isOwner: isOwner,
          ),
        ),
        if (preview.isEmpty)
          PubgetEmptyState(
            compact: true,
            icon: Icons.emoji_events_outlined,
            title: copy.unlockedEmptyTitle,
            message: copy.unlockedEmptyBody,
          )
        else
          SizedBox(
            height: kAchievementStripBadgeSize + 8,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: preview.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final item = preview[index];
                return AchievementBadgeWidget(
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
      ],
    );
  }
}

class _ActivitySection extends StatelessWidget {
  const _ActivitySection({required this.createdAt});

  final DateTime createdAt;

  @override
  Widget build(BuildContext context) {
    final stamp =
        '${createdAt.toLocal().year}-${createdAt.toLocal().month.toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const ProfileSectionHeader(title: 'Activity'),
        PubgetCard(
          child: Row(
            children: <Widget>[
              const Icon(Icons.schedule_outlined, color: AppColors.royalPurple),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Member since $stamp',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
      ],
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
      final message = result.failureOrNull?.message ??
          'Could not start this private chat.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
            relation?.blockedBy == context.read<AuthProvider>().currentUser?.id
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
