import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../app/app_shell_scope.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../models/group_models.dart';
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
    final copy = AppStrings.of(context);
    final groups = uid == null
        ? const <Group>[]
        : provider.memberGroups(uid);
    final listState = provider.joinedState == LoadingState.loaded &&
            groups.isEmpty
        ? LoadingState.empty
        : provider.joinedState;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const AppShellMenuButton(),
        title: Text(copy.joinedTitle),
      ),
      body: PubgetAtmosphere(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: PubgetLoadingStateView(
            state: listState,
            onRetry: () {
              if (uid == null) return;
              provider.loadJoined(uid);
            },
            empty: PubgetEmptyState(
              title: copy.noJoinedGroups,
              message: copy.noJoinedMessage,
              icon: Icons.group_outlined,
              action: PubgetPrimaryButton(
                onPressed: () => AppNavigation.go(context, '/groups'),
                semanticLabel: copy.findGroups,
                child: Text(copy.findGroups),
              ),
            ),
            error: PubgetErrorState(
              message: provider.joinedFailure?.message ?? copy.joinedFailed,
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
              itemCount: groups.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) =>
                  GroupListCard(group: groups[index]),
            ),
          ),
        ),
      ),
    );
  }
}
