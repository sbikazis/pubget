import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../models/app_notification.dart';
import '../providers/notification_provider.dart';

class NotificationInboxPage extends StatelessWidget {
  const NotificationInboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: <Widget>[
          TextButton(
            onPressed: provider.unreadCount > 0 ? provider.markAllAsRead : null,
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: PubgetLoadingStateView(
        state: provider.state,
        onRetry: () {},
        empty: const PubgetEmptyState(
          title: 'No notifications',
          message: 'Important activity will appear here.',
        ),
        error: PubgetErrorState(
          message: provider.failure?.message ?? 'Notifications could not load.',
          onRetry: () {},
        ),
        offline: const PubgetOfflineState(),
        child: NotificationListener<ScrollNotification>(
          onNotification: (event) {
            if (event.metrics.extentAfter < 240) provider.loadMore();
            return false;
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: provider.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final item = provider.items[index];
              return _NotificationTile(
                item: item,
                onTap: () async {
                  await provider.markAsRead(item);
                  if (context.mounted) {
                    await AppNavigation.go(context, item.destination);
                  }
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await provider.enablePush();
          if (!context.mounted) return;
          final enabled = result.valueOrNull ?? false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                enabled
                    ? 'Push notifications enabled'
                    : result.failureOrNull?.message ??
                          'Notification permission was not granted',
              ),
            ),
          );
        },
        icon: const Icon(Icons.notifications_active_outlined),
        label: const Text('Enable push'),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PubgetCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Icon(
            _icon(item.type),
            color: item.isUnread
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _title(item.type),
                  style: TextStyle(
                    fontWeight: item.isUnread
                        ? FontWeight.w800
                        : FontWeight.w500,
                  ),
                ),
                Text(item.action),
              ],
            ),
          ),
          if (item.isUnread)
            const Icon(Icons.circle, size: 10, color: Colors.red),
        ],
      ),
    );
  }

  IconData _icon(String type) => switch (type) {
    'group_message' => Icons.forum_outlined,
    'join_request' => Icons.group_add_outlined,
    'friend_request' => Icons.person_add_outlined,
    'respect_received' => Icons.favorite_outline,
    _ => Icons.notifications_none,
  };

  String _title(String type) => switch (type) {
    'group_message' => 'New group message',
    'join_request' => 'Join request',
    'request_accepted' => 'Request accepted',
    'friend_request' => 'Friend request',
    'respect_received' => 'Respect received',
    _ => 'Notification',
  };
}
