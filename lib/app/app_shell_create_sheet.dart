import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../core/widgets/pubget_design_system.dart';
import 'app_router.dart';

abstract final class AppShellCreateSheet {
  static Future<void> show(BuildContext host) {
    final copy = AppStrings.of(host);
    return PubgetBottomSheet.show<void>(
      host,
      title: copy.createNew,
      isScrollControlled: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            key: const Key('create-group'),
            leading: const Icon(Icons.groups_outlined),
            title: Text(copy.createGroupAction),
            onTap: () {
              Navigator.pop(host);
              AppNavigation.go(host, '/groups/create');
            },
          ),
          ListTile(
            key: const Key('create-edit'),
            leading: const Icon(Icons.movie_filter_outlined),
            title: Text(copy.uploadClip),
            onTap: () {
              Navigator.pop(host);
              AppNavigation.go(host, '/edits/upload');
            },
          ),
          ListTile(
            key: const Key('create-fan-work'),
            leading: const Icon(Icons.auto_awesome_outlined),
            title: Text(copy.createFanWork),
            onTap: () {
              Navigator.pop(host);
              AppNavigation.go(host, '/fan-works/create');
            },
          ),
          ListTile(
            key: const Key('create-events'),
            leading: const Icon(Icons.celebration_outlined),
            title: Text(copy.browseEvents),
            onTap: () {
              Navigator.pop(host);
              AppNavigation.go(host, '/events');
            },
          ),
        ],
      ),
    );
  }
}
