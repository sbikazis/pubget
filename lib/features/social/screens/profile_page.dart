import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../models/social_models.dart';
import '../providers/profile_provider.dart';
import '../providers/social_provider.dart';

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
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final currentUserId = context.watch<AuthProvider>().currentUser?.id;
    final profileId = widget.userId ?? currentUserId ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text(profile.isOwner ? 'My profile' : 'Profile'),
        actions: <Widget>[
          if (profile.isOwner)
            PubgetIconButton(
              icon: Icons.edit_outlined,
              tooltip: 'Edit profile',
              onPressed: () => AppNavigation.go(context, '/profile/edit'),
            ),
        ],
      ),
      body: SafeArea(
        child: PubgetLoadingStateView(
          state: profile.state,
          onRetry: () => _reload(profileId),
          error: PubgetErrorState(
            message: profile.failure?.message ?? 'The profile could not load.',
            onRetry: () => _reload(profileId),
          ),
          offline: PubgetOfflineState(onRetry: () => _reload(profileId)),
          empty: const PubgetEmptyState(
            title: 'Profile not available',
            message: 'This user may have made their profile private.',
          ),
          child: _ProfileContent(
            profileId: profileId,
            respect: _respect,
            onRespectChanged: (value) => setState(() => _respect = value),
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

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
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
    final own = profile.ownProfile;
    final public = profile.publicProfile;
    final name = profile.isOwner
        ? own?.displayName ?? own?.username
        : public?.username;
    final avatarUrl = profile.isOwner ? own?.avatarUrl : public?.avatarUrl;
    final bio = profile.isOwner ? own?.bio : public?.bio;
    final totalRespect = profile.isOwner
        ? own?.totalRespect ?? 0
        : public?.totalRespect ?? 0;
    final fansCount = profile.isOwner
        ? own?.fansCount ?? 0
        : public?.fansCount ?? 0;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        Center(
          child: PubgetAvatar(
            imageUrl: avatarUrl,
            name: name,
            size: PubgetAvatarSize.large,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          name ?? 'Pubget user',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        if (bio != null && bio.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(bio, textAlign: TextAlign.center),
        ],
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: <Widget>[
            Expanded(
              child: _Stat(label: 'Respect', value: totalRespect),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _Stat(label: 'Fans', value: fansCount),
            ),
            if (profile.isOwner) ...[
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _Stat(label: 'Friends', value: social.friends.length),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        if (profile.isOwner) ...[
          PubgetPrimaryButton(
            onPressed: () => AppNavigation.go(context, '/profile/edit'),
            semanticLabel: 'Edit my public profile',
            leadingIcon: Icons.edit_outlined,
            child: const Text('Edit profile'),
          ),
          const SizedBox(height: AppSpacing.sm),
          PubgetSecondaryButton(
            onPressed: () => AppNavigation.go(context, '/friend-requests'),
            semanticLabel: 'Open friend requests',
            leadingIcon: Icons.person_add_alt_1_outlined,
            child: Text('Friend requests (${social.incomingRequests.length})'),
          ),
        ] else ...[
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
          _BlockAction(profileId: profileId),
          if (social.failure != null) ...[
            const SizedBox(height: AppSpacing.md),
            PubgetErrorState(message: social.failure!.message),
          ],
        ],
      ],
    );
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

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return PubgetCard(
      child: Column(
        children: <Widget>[
          Text('$value', style: Theme.of(context).textTheme.titleLarge),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
