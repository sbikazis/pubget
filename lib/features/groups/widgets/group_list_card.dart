import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../models/group_models.dart';

class GroupListCard extends StatelessWidget {
  const GroupListCard({required this.group, super.key});

  final Group group;

  @override
  Widget build(BuildContext context) {
    return PubgetCard(
      onTap: () => AppNavigation.go(context, '/group?groupId=${group.id}'),
      child: Row(
        children: <Widget>[
          const Icon(Icons.groups_outlined, size: 36),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(group.name, style: Theme.of(context).textTheme.titleMedium),
                Text('${group.membersCount}/${group.maxMembers} members'),
              ],
            ),
          ),
          Text(group.type.name),
        ],
      ),
    );
  }
}
