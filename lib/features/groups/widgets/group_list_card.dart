import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../models/group_models.dart';

class GroupListCard extends StatelessWidget {
  const GroupListCard({
    required this.group,
    this.showUnread = false,
    super.key,
  });

  final Group group;

  /// Joined-group lists surface the unread marker; catalog lists do not.
  final bool showUnread;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    return PubgetCard(
      onTap: () => AppNavigation.go(context, '/group?groupId=${group.id}'),
      padding: EdgeInsets.zero,
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 88,
            height: 88,
            child: group.imageUrl == null || group.imageUrl!.isEmpty
                ? const ColoredBox(
                    color: Color(0x332C1654),
                    child: Icon(Icons.groups_outlined, size: 32),
                  )
                : AppImageLoader(imageUrl: group.imageUrl!, fit: BoxFit.cover),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    group.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    copy.membersCapacity(group.membersCount, group.maxMembers),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  PubgetBadge(
                    label: copy.groupTypeLabel(group.type.name),
                    compact: true,
                  ),
                ],
              ),
            ),
          ),
          if (showUnread && group.hasUnread)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.md),
              child: Icon(
                Icons.circle,
                size: 10,
                color: Theme.of(context).colorScheme.primary,
                semanticLabel: copy.unreadLabel,
              ),
            ),
        ],
      ),
    );
  }
}
