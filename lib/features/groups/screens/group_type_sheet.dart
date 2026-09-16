import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../l10n/group_copy.dart';
import '../models/group_models.dart';

abstract final class GroupTypeSheet {
  static const keys = <String>[
    'create-group-type-public',
    'create-group-type-animeRoleplay',
    'create-group-type-openRoleplay',
  ];

  static Future<void> show(BuildContext host) {
    final copy = GroupCopy.of(host);
    return PubgetBottomSheet.show<void>(
      host,
      title: copy.chooseType,
      isScrollControlled: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final type in GroupType.values)
            ListTile(
              key: Key('create-group-type-${type.name}'),
              leading: Icon(_icon(type)),
              title: Text(copy.typeLabel(type)),
              subtitle: Text(copy.typeHint(type)),
              onTap: () {
                Navigator.pop(host);
                AppNavigation.go(host, '/groups/create?type=${type.name}');
              },
            ),
        ],
      ),
    );
  }

  static IconData _icon(GroupType type) => switch (type) {
    GroupType.public => Icons.public_outlined,
    GroupType.animeRoleplay => Icons.theater_comedy_outlined,
    GroupType.openRoleplay => Icons.auto_awesome_outlined,
  };
}

class GroupTypeTiles extends StatelessWidget {
  const GroupTypeTiles({required this.onSelected, super.key});

  final ValueChanged<GroupType> onSelected;

  @override
  Widget build(BuildContext context) {
    final copy = GroupCopy.of(context);
    return Column(
      children: <Widget>[
        for (final type in GroupType.values) ...<Widget>[
          ListTile(
            key: Key('create-group-type-${type.name}'),
            leading: Icon(GroupTypeSheet._icon(type)),
            title: Text(copy.typeLabel(type)),
            subtitle: Text(copy.typeHint(type)),
            onTap: () => onSelected(type),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}
