import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/l10n/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/pubget_design_system.dart';
import '../features/edits/screens/edit_feed_page.dart';
import '../features/groups/screens/groups_home_page.dart';
import '../features/groups/screens/joined_groups_page.dart';
import '../features/home/screens/home_page.dart';
import '../features/notifications/providers/unread_engine.dart';
import '../features/notifications/widgets/unread_badge.dart';
import '../features/private_chat/screens/private_chats_list_screen.dart';
import 'app_route.dart';
import 'app_router.dart';
import 'app_shell_create_sheet.dart';
import 'app_shell_drawer.dart';
import 'app_shell_scope.dart';
import 'app_shell_tab.dart';

/// Persistent shell. Bottom destinations are Explore / Groups / + / Private /
/// Clips. Joined stays reachable from the drawer and keeps its stack slot.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.pages});

  /// Production pages when null. Tests may inject five lightweight children.
  final List<Widget>? pages;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  AppRouterDelegate? _delegate;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final delegate = Router.of(context).routerDelegate;
    if (delegate is! AppRouterDelegate || identical(delegate, _delegate)) {
      return;
    }
    _delegate?.removeListener(_onRouteChanged);
    _delegate = delegate;
    _delegate!.addListener(_onRouteChanged);
  }

  void _onRouteChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _delegate?.removeListener(_onRouteChanged);
    super.dispose();
  }

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
    final copy = AppStrings.of(context);
    final pages = widget.pages ??
        const <Widget>[
          HomePage(),
          GroupsHomePage(),
          JoinedGroupsPage(),
          PrivateChatsListScreen(),
          EditFeedPage(),
        ];

    return AppShellScope(
      openDrawer: () => _scaffoldKey.currentState?.openDrawer(),
      child: Scaffold(
        key: _scaffoldKey,
        drawer: const AppShellDrawer(),
        body: IndexedStack(index: tab.index, children: pages),
        bottomNavigationBar: Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 8,
          child: SafeArea(
            child: SizedBox(
              height: 72,
              child: Row(
                children: <Widget>[
                  _TabButton(
                    tabKey: const Key('shell-tab-discover'),
                    selected: tab == AppShellTab.discover,
                    icon: Icons.explore_outlined,
                    selectedIcon: Icons.explore,
                    label: copy.tabDiscover,
                    onTap: () => _go(path, AppShellTab.discover),
                  ),
                  _TabButton(
                    tabKey: const Key('shell-tab-groups'),
                    selected: tab == AppShellTab.groups,
                    icon: Icons.groups_outlined,
                    selectedIcon: Icons.groups,
                    label: copy.tabGroups,
                    badge: unread.groups,
                    onTap: () => _go(path, AppShellTab.groups),
                  ),
                  Expanded(
                    child: Center(
                      child: PubgetCenterCreateButton(
                        tooltip: copy.createNew,
                        onPressed: () => AppShellCreateSheet.show(context),
                      ),
                    ),
                  ),
                  _TabButton(
                    tabKey: const Key('shell-tab-private'),
                    selected: tab == AppShellTab.private,
                    icon: Icons.forum_outlined,
                    selectedIcon: Icons.forum,
                    label: copy.tabPrivate,
                    badge: unread.privateChats,
                    onTap: () => _go(path, AppShellTab.private),
                  ),
                  _TabButton(
                    tabKey: const Key('shell-tab-edits'),
                    selected: tab == AppShellTab.edits,
                    icon: Icons.movie_filter_outlined,
                    selectedIcon: Icons.movie_filter,
                    label: copy.tabEdits,
                    onTap: () => _go(path, AppShellTab.edits),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _go(String path, AppShellTab next) {
    if (next.path == path) return;
    AppNavigation.go(context, next.path);
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tabKey,
    required this.selected,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
    this.badge = 0,
  });

  final Key tabKey;
  final bool selected;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppColors.gold
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
    return Expanded(
      child: InkWell(
        key: tabKey,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            UnreadBadge(
              count: badge,
              child: Icon(selected ? selectedIcon : icon, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
