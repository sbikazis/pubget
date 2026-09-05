import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/authentication/providers/auth_provider.dart';
import 'app_router.dart';

typedef AppShellDrawerItem = ({String id, String label, IconData icon, String path});

/// Spec §9 minimum Drawer entries. Every path already exists in the app.
abstract final class AppShellDrawerDestinations {
  static const items = <AppShellDrawerItem>[
    (id: 'profile', label: 'My Profile', icon: Icons.person_outline, path: '/profile'),
    (
      id: 'private',
      label: 'Private Chats',
      icon: Icons.forum_outlined,
      path: '/private',
    ),
    (id: 'groups', label: 'My Groups', icon: Icons.groups_outlined, path: '/groups'),
    (
      id: 'joined',
      label: 'Joined Groups',
      icon: Icons.group_outlined,
      path: '/joined',
    ),
    (
      id: 'suggested',
      label: 'Suggested Groups',
      icon: Icons.explore_outlined,
      path: '/home',
    ),
    (id: 'store', label: 'Store', icon: Icons.storefront_outlined, path: '/store'),
    (id: 'premium', label: 'Premium', icon: Icons.workspace_premium_outlined, path: '/premium'),
    (
      id: 'settings',
      label: 'Settings',
      icon: Icons.settings_outlined,
      path: '/settings',
    ),
    (id: 'guide', label: 'Guide', icon: Icons.menu_book_outlined, path: '/guide'),
  ];
}

class AppShellDrawer extends StatelessWidget {
  const AppShellDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('Pubget'),
              ),
            ),
            for (final item in AppShellDrawerDestinations.items)
              ListTile(
                key: Key('drawer-${item.id}'),
                leading: Icon(item.icon),
                title: Text(item.label),
                onTap: () => _open(context, item),
              ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, AppShellDrawerItem item) {
    var path = item.path;
    if (item.id == 'profile') {
      final uid = context.read<AuthProvider>().currentUser?.id;
      path = uid == null || uid.isEmpty ? '/profile' : '/profile?uid=$uid';
    }
    final delegate = Router.of(context).routerDelegate as AppRouterDelegate;
    Scaffold.maybeOf(context)?.closeDrawer();
    delegate.setNewRoutePath(AppRouter.routeFromString(path));
  }
}
