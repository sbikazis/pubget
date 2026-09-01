import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../providers/group_provider.dart';

class GroupChatPlaceholderPage extends StatelessWidget {
  const GroupChatPlaceholderPage({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(provider.group?.name ?? 'Group')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: PubgetCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.forum_outlined, size: 48),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Group chat arrives in PROMPT 07',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.lg),
                PubgetSecondaryButton(
                  onPressed: () => AppNavigation.go(
                    context,
                    '/group-members?groupId=$groupId',
                  ),
                  semanticLabel: 'View group members',
                  child: const Text('Members'),
                ),
                const SizedBox(height: AppSpacing.sm),
                PubgetTextButton(
                  key: const Key('leave-group'),
                  onPressed: () {
                    provider.leaveOptimistically(groupId);
                    AppNavigation.go(context, '/groups');
                  },
                  semanticLabel: 'Leave group',
                  child: const Text('Leave group'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
