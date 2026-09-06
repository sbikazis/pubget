import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../app/app_router.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/links/pubget_links.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../models/group_models.dart';
import '../providers/group_provider.dart';

class GroupDetailsPage extends StatefulWidget {
  const GroupDetailsPage({required this.groupId, super.key});

  final String groupId;

  @override
  State<GroupDetailsPage> createState() => _GroupDetailsPageState();
}

class _GroupDetailsPageState extends State<GroupDetailsPage> {
  bool _redirected = false;
  bool _requestedLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requestedLoad) return;
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) return;
    _requestedLoad = true;
    final provider = context.read<GroupProvider>();
    Future<void>.microtask(
      () => provider.load(groupId: widget.groupId, userId: userId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupProvider>();
    final copy = AppStrings.of(context);
    final group = provider.group;
    if (!_redirected &&
        provider.state == LoadingState.loaded &&
        provider.isMember &&
        !provider.isFounder) {
      _redirected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          AppNavigation.go(context, '/group-chat?groupId=${widget.groupId}');
        }
      });
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(copy.groupDetails),
        actions: <Widget>[
          PubgetIconButton(
            icon: Icons.share_outlined,
            tooltip: copy.shareGroup,
            onPressed: () => PubgetLinks.share(
              context,
              url: PubgetLinks.group(widget.groupId),
              title: group?.name,
              type: 'group',
            ),
          ),
          PubgetIconButton(
            icon: Icons.copy_outlined,
            tooltip: copy.copyLink,
            onPressed: () => PubgetLinks.copy(
              context,
              PubgetLinks.group(widget.groupId),
              type: 'group',
            ),
          ),
        ],
      ),
      body: PubgetAtmosphere(
        child: SafeArea(
          child: PubgetLoadingStateView(
            state: provider.state,
            onRetry: () => _reload(context),
            error: PubgetErrorState(
              message: provider.failure?.message ?? copy.groupFailed,
              onRetry: () => _reload(context),
            ),
            offline: PubgetOfflineState(onRetry: () => _reload(context)),
            empty: PubgetEmptyState(title: copy.groupUnavailable),
            child: group == null
                ? const SizedBox.shrink()
                : _Details(group: group),
          ),
        ),
      ),
    );
  }

  Future<void> _reload(BuildContext context) async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) return;
    await context.read<GroupProvider>().load(
      groupId: widget.groupId,
      userId: userId,
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupProvider>();
    final copy = AppStrings.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
        PubgetHeroBanner(
          key: const Key('group-details-hero'),
          title: group.name,
          subtitle: group.description.isEmpty
              ? copy.communityFallback
              : group.description,
          leading: PubgetAvatar(
            imageUrl: group.imageUrl,
            name: group.name,
            size: PubgetAvatarSize.large,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            PubgetBadge(
              label: copy.groupTypeLabel(group.type.name),
              compact: true,
            ),
            PubgetBadge(
              label: copy.membersCount(group.membersCount),
              compact: true,
            ),
            PubgetBadge(
              label: copy.joinPolicyLabel(group.joinPolicy.name),
              compact: true,
            ),
          ],
        ),
        if (group.rules.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          PubgetCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(copy.rules, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(group.rules),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (provider.isMember) ...[
          PubgetPrimaryButton(
            onPressed: () => AppNavigation.go(
              context,
              '/group-chat?groupId=${group.id}',
            ),
            semanticLabel: copy.openChat,
            leadingIcon: Icons.forum_outlined,
            child: Text(copy.openChat),
          ),
          const SizedBox(height: AppSpacing.sm),
          PubgetSecondaryButton(
            onPressed: () => AppNavigation.go(
              context,
              '/events?groupId=${Uri.encodeComponent(group.id)}',
            ),
            semanticLabel: copy.groupEvents,
            child: Text(copy.groupEvents),
          ),
          if (provider.canManageEvents) ...[
            const SizedBox(height: AppSpacing.sm),
            PubgetSecondaryButton(
              onPressed: () => AppNavigation.go(
                context,
                '/events/create?groupId=${Uri.encodeComponent(group.id)}',
              ),
              semanticLabel: copy.createEvent,
              child: Text(copy.createEvent),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          PubgetSecondaryButton(
            onPressed: () => AppNavigation.go(
              context,
              '/games?groupId=${Uri.encodeComponent(group.id)}',
            ),
            semanticLabel: copy.groupGames,
            child: Text(copy.groupGames),
          ),
          if (provider.membership?.canManageGames == true) ...[
            const SizedBox(height: AppSpacing.sm),
            PubgetSecondaryButton(
              onPressed: () => AppNavigation.go(
                context,
                '/games/create?groupId=${Uri.encodeComponent(group.id)}',
              ),
              semanticLabel: copy.createGame,
              child: Text(copy.createGame),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
        ],
        if (provider.canManageSettings) ...[
          PubgetPrimaryButton(
            onPressed: () => AppNavigation.go(
              context,
              '/group-settings?groupId=${group.id}',
            ),
            semanticLabel: copy.groupSettings,
            child: Text(copy.groupSettings),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (provider.canManageMembers) ...[
          PubgetSecondaryButton(
            onPressed: () => AppNavigation.go(
              context,
              '/group-bans?groupId=${group.id}',
            ),
            semanticLabel: copy.bannedUsers,
            child: Text(copy.bannedUsers),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (!provider.isMember) _JoinAction(group: group),
        if (provider.isFounder) ...[
          PubgetPrimaryButton(
            onPressed: () =>
                AppNavigation.go(context, '/group-members?groupId=${group.id}'),
            semanticLabel: copy.manageMembers,
            child: Text(copy.manageMembers),
          ),
          const SizedBox(height: AppSpacing.sm),
          PubgetSecondaryButton(
            onPressed: () => AppNavigation.go(
              context,
              '/group-requests?groupId=${group.id}',
            ),
            semanticLabel: copy.joinRequests,
            child: Text(copy.joinRequests),
          ),
          if (group.type != GroupType.public) ...[
            const SizedBox(height: AppSpacing.sm),
            PubgetSecondaryButton(
              onPressed: () => AppNavigation.go(
                context,
                '/group-roleplay?groupId=${group.id}',
              ),
              semanticLabel: copy.roleplayCharacters,
              child: Text(copy.roleplayCharacters),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          PubgetTextButton(
            key: const Key('group-details-disband'),
            onPressed: () => _disband(context, provider),
            semanticLabel: copy.disbandGroup,
            child: Text(copy.disbandGroup),
          ),
        ],
        ],
      ),
    );
  }

  Future<void> _disband(BuildContext context, GroupProvider provider) async {
    final copy = AppStrings.of(context);
    final first = await PubgetConfirmationDialog.show(
      context,
      title: copy.disbandTitle(group.name),
      message: copy.disbandMessage,
      confirmLabel: copy.continueLabel,
      cancelLabel: copy.cancel,
    );
    if (first != true || !context.mounted) return;
    final second = await PubgetConfirmationDialog.show(
      context,
      title: copy.finalConfirmation,
      message: copy.disbandFinalMessage,
      confirmLabel: copy.disband,
      cancelLabel: copy.keepGroup,
    );
    if (second == true) await provider.disband(group.id);
  }
}

class _JoinAction extends StatelessWidget {
  const _JoinAction({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupProvider>();
    final copy = AppStrings.of(context);
    if (group.isFull) {
      return PubgetEmptyState(
        title: copy.groupIsFull,
        message: copy.groupFullMessage,
      );
    }
    if (group.joinPolicy == JoinPolicy.inviteOnly) {
      return PubgetEmptyState(
        title: copy.invitationRequired,
        message: copy.invitationRequiredMessage,
      );
    }
    final approval = group.joinPolicy == JoinPolicy.approval;
    final userId = context.read<AuthProvider>().currentUser?.id;
    return PubgetPrimaryButton(
      onPressed: provider.state == LoadingState.loading || userId == null
          ? null
          : () => approval
                ? provider.requestToJoin(group.id)
                : provider.join(group.id, userId: userId),
      semanticLabel: approval ? copy.requestToJoin : copy.joinGroup,
      child: Text(approval ? copy.requestToJoin : copy.joinGroup),
    );
  }
}
