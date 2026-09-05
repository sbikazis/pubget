import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../app/app_shell_scope.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../providers/group_provider.dart';
import '../widgets/group_list_card.dart';

class JoinedGroupsPage extends StatefulWidget {
  const JoinedGroupsPage({super.key});

  @override
  State<JoinedGroupsPage> createState() => _JoinedGroupsPageState();
}

class _JoinedGroupsPageState extends State<JoinedGroupsPage> {
  @override
  void initState() {
    super.initState();
    final uid = context.read<AuthProvider>().currentUser?.id;
    if (uid == null) return;
    final provider = context.read<GroupProvider>();
    Future<void>.microtask(() => provider.loadJoined(uid));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupProvider>();
    final uid = context.watch<AuthProvider>().currentUser?.id;
    return Scaffold(
      appBar: AppBar(
        leading: const AppShellMenuButton(),
        title: const Text('Joined'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: PubgetLoadingStateView(
          state: provider.joinedState,
          onRetry: () {
            if (uid == null) return;
            provider.loadJoined(uid);
          },
          empty: PubgetEmptyState(
            title: 'No joined groups',
            message: 'Join a community from Groups or Discover.',
            icon: Icons.group_outlined,
            action: PubgetPrimaryButton(
              onPressed: () => AppNavigation.go(context, '/groups'),
              semanticLabel: 'Find groups',
              child: const Text('Find groups'),
            ),
          ),
          error: PubgetErrorState(
            message: provider.joinedFailure?.message ?? 'Joined groups could not load.',
            onRetry: () {
              if (uid == null) return;
              provider.loadJoined(uid);
            },
          ),
          offline: PubgetOfflineState(
            onRetry: () {
              if (uid == null) return;
              provider.loadJoined(uid);
            },
          ),
          child: ListView.separated(
            itemCount: provider.joinedGroups.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) =>
                GroupListCard(group: provider.joinedGroups[index]),
          ),
        ),
      ),
    );
  }
}
