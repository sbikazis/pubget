import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/l10n/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/widgets/pubget_design_system.dart';
import '../features/authentication/providers/auth_provider.dart';
import '../features/authentication/providers/onboarding_provider.dart';
import '../features/economy/providers/economy_provider.dart';
import '../features/economy/widgets/economy_widgets.dart';
import '../features/notifications/providers/unread_engine.dart';
import '../features/notifications/widgets/unread_badge.dart';
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
    (
      id: 'anime',
      label: 'Anime List',
      icon: Icons.auto_awesome_mosaic_outlined,
      path: '/anime',
    ),
    (
      id: 'anime-ratings',
      label: 'Ratings',
      icon: Icons.star_outline,
      path: '/anime/ratings',
    ),
    (
      id: 'anime-characters',
      label: 'Popular Characters',
      icon: Icons.people_outline,
      path: '/anime/characters',
    ),
    (id: 'store', label: 'Dragon Store', icon: Icons.storefront_outlined, path: '/store'),
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

  static int unreadCountFor(String id, UnreadEngine unread) => switch (id) {
    'private' => unread.privateChats,
    'groups' || 'joined' => unread.groups,
    'notifications' => unread.notifications,
    _ => 0,
  };

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<UnreadEngine>();
    final copy = AppStrings.of(context);
    AuthProvider? auth;
    try {
      auth = Provider.of<AuthProvider>(context);
    } on ProviderNotFoundException {
      auth = null;
    }
    OnboardingProvider? onboarding;
    try {
      onboarding = Provider.of<OnboardingProvider>(context);
    } on ProviderNotFoundException {
      onboarding = null;
    }
    final profile = onboarding?.profile;
    final economy = maybeEconomy(context);
    final name = profile?.displayName ??
        profile?.username ??
        auth?.currentUser?.displayName ??
        auth?.currentUser?.email;
    return Drawer(
      child: PubgetAtmosphere(
        child: SafeArea(
          child: ListView(
            children: <Widget>[
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                leading: EquippedAvatar(
                  imageUrl: profile?.avatarUrl ?? auth?.currentUser?.avatarUrl,
                  name: name,
                  frameId: economy?.equipped.frameId,
                  size: PubgetAvatarSize.small,
                ),
                title: Text(
                  'Pubget',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: Text(
                  name ?? copy.brandTagline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Divider(height: 1),
              for (final item in AppShellDrawerDestinations.items)
                ListTile(
                  key: Key('drawer-${item.id}'),
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: UnreadBadge(
                    count: unreadCountFor(item.id, unread),
                    child: Icon(item.icon, color: AppColors.gold),
                  ),
                  title: Text(copy.drawerLabel(item.id)),
                  onTap: () => _open(context, item),
                ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
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
