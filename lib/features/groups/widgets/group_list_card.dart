import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../models/group_models.dart';

class GroupListCard extends StatelessWidget {
  const GroupListCard({required this.group, this.showUnread = false, super.key});

  final Group group;
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
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            group.name,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (showUnread && group.hasUnread)
                          const Padding(
                            padding: EdgeInsetsDirectional.only(start: 8),
                            child: Icon(
                              Icons.circle,
                              size: 8,
                              color: Color(0xFF6C3FC5),
                            ),
                          ),
                      ],
                    ),
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
        ],
      ),
    );
  }
}
