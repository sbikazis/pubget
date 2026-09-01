import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../providers/group_provider.dart';

class GroupInvitePage extends StatelessWidget {
  const GroupInvitePage({
    required this.groupId,
    required this.inviteId,
    super.key,
  });

  final String groupId;
  final String inviteId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Group invitation')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: PubgetCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.group_add_outlined, size: 48),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'You received a private group invitation.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                PubgetPrimaryButton(
                  onPressed: () async {
                    final result = await provider.join(
                      groupId,
                      inviteId: inviteId,
                    );
                    if (context.mounted && result.isSuccess) {
                      await AppNavigation.go(
                        context,
                        '/group-chat?groupId=$groupId',
                      );
                    }
                  },
                  semanticLabel: 'Accept group invitation',
                  child: const Text('Accept invitation'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
