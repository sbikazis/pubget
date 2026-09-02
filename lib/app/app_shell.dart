import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_motion.dart';
import '../features/edits/screens/edit_feed_page.dart';
import '../features/groups/screens/groups_home_page.dart';
import '../features/home/screens/home_page.dart';
import '../features/notifications/providers/unread_engine.dart';
import '../features/notifications/widgets/unread_badge.dart';
import '../features/private_chat/screens/private_chats_list_screen.dart';
import 'app_route.dart';
import 'app_router.dart';
import 'app_shell_tab.dart';

/// Persistent four-tab shell. Tab switches keep the [IndexedStack] alive so
/// Home / Groups / Private / Edits state is not destroyed.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  Widget build(BuildContext context) {
    final path = switch (Router.of(context).routerDelegate) {
      final AppRouterDelegate delegate => switch (delegate.currentConfiguration) {
        ParameterizedRoute(:final path) => path,
        FoundationRoute() => AppShellTab.discover.path,
      },
      _ => AppShellTab.discover.path,
    };
    final tab = AppShellTabX.fromPath(path);
    final unread = context.watch<UnreadEngine>();

    return Scaffold(
      body: IndexedStack(
        index: tab.index,
        children: const [
          HomePage(),
          GroupsHomePage(),
          PrivateChatsListScreen(),
          EditFeedPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab.index,
        animationDuration: AppMotion.medium,
        onDestinationSelected: (index) {
          final next = AppShellTab.values[index];
          if (next.path == path) return;
          AppNavigation.go(context, next.path);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: const Icon(Icons.explore),
            label: AppShellTab.discover.label,
          ),
          NavigationDestination(
            icon: UnreadBadge(
              count: unread.groups,
              child: const Icon(Icons.groups_outlined),
            ),
            selectedIcon: UnreadBadge(
              count: unread.groups,
              child: const Icon(Icons.groups),
            ),
            label: AppShellTab.groups.label,
          ),
          NavigationDestination(
            icon: UnreadBadge(
              count: unread.privateChats,
              child: const Icon(Icons.forum_outlined),
            ),
            selectedIcon: UnreadBadge(
              count: unread.privateChats,
              child: const Icon(Icons.forum),
            ),
            label: AppShellTab.private.label,
          ),
          NavigationDestination(
            icon: const Icon(Icons.movie_filter_outlined),
            selectedIcon: const Icon(Icons.movie_filter),
            label: AppShellTab.edits.label,
          ),
        ],
      ),
    );
  }
}
