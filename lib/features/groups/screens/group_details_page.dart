import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) return;
    final provider = context.read<GroupProvider>();
    Future<void>.microtask(
      () => provider.load(groupId: widget.groupId, userId: userId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupProvider>();
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
      appBar: AppBar(title: const Text('Group details')),
      body: SafeArea(
        child: PubgetLoadingStateView(
          state: provider.state,
          onRetry: () => _reload(context),
          error: PubgetErrorState(
            message: provider.failure?.message ?? 'Group could not load.',
            onRetry: () => _reload(context),
          ),
          offline: PubgetOfflineState(onRetry: () => _reload(context)),
          empty: const PubgetEmptyState(title: 'Group unavailable'),
          child: group == null
              ? const SizedBox.shrink()
              : _Details(group: group),
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
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        PubgetCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                group.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(group.description),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                children: <Widget>[
                  PubgetBadge(label: group.type.name),
                  PubgetBadge(label: '${group.membersCount} members'),
                  PubgetBadge(label: group.joinPolicy.name),
                ],
              ),
              if (group.rules.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text('Rules', style: Theme.of(context).textTheme.titleMedium),
                Text(group.rules),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (!provider.isMember) _JoinAction(group: group),
        if (provider.isFounder) ...[
          PubgetPrimaryButton(
            onPressed: () =>
                AppNavigation.go(context, '/group-members?groupId=${group.id}'),
            semanticLabel: 'Manage group members',
            child: const Text('Manage members'),
          ),
          const SizedBox(height: AppSpacing.sm),
          PubgetSecondaryButton(
            onPressed: () => AppNavigation.go(
              context,
              '/group-requests?groupId=${group.id}',
            ),
            semanticLabel: 'Open join requests',
            child: const Text('Join requests'),
          ),
          if (group.type != GroupType.public) ...[
            const SizedBox(height: AppSpacing.sm),
            PubgetSecondaryButton(
              onPressed: () => AppNavigation.go(
                context,
                '/group-roleplay?groupId=${group.id}',
              ),
              semanticLabel: 'Choose roleplay character',
              child: const Text('Roleplay characters'),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          PubgetTextButton(
            onPressed: () => _disband(context, provider),
            semanticLabel: 'Disband group',
            child: const Text('Disband group'),
          ),
        ],
      ],
    );
  }

  Future<void> _disband(BuildContext context, GroupProvider provider) async {
    final first = await PubgetConfirmationDialog.show(
      context,
      title: 'Disband ${group.name}?',
      message: 'This removes the group and cannot be undone.',
      confirmLabel: 'Continue',
      cancelLabel: 'Cancel',
    );
    if (first != true || !context.mounted) return;
    final second = await PubgetConfirmationDialog.show(
      context,
      title: 'Final confirmation',
      message: 'All members will be notified. Disband this group now?',
      confirmLabel: 'Disband',
      cancelLabel: 'Keep group',
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
    if (group.isFull) {
      return const PubgetEmptyState(
        title: 'Group is full',
        message: 'Try again when a place becomes available.',
      );
    }
    if (group.joinPolicy == JoinPolicy.inviteOnly) {
      return const PubgetEmptyState(
        title: 'Invitation required',
        message: 'Use a valid group invitation to join.',
      );
    }
    final approval = group.joinPolicy == JoinPolicy.approval;
    return PubgetPrimaryButton(
      onPressed: provider.state == LoadingState.loading
          ? null
          : () => approval
                ? provider.requestToJoin(group.id)
                : provider.join(group.id),
      semanticLabel: approval ? 'Request to join group' : 'Join group',
      child: Text(approval ? 'Request to join' : 'Join group'),
    );
  }
}
