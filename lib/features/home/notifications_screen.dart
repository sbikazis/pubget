// lib/features/home/notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';

import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state_widget.dart';

import '../../providers/notifications_provider.dart';
import '../../providers/auth_provider.dart';

import '../../models/notification_model.dart';

import '../groups/group_details_screen.dart';
import '../private_chat/private_chat_screen.dart';
import 'package:pubget/features/profile/profile_sceen.dart';
import 'search_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final notificationsProvider = context.read<NotificationsProvider>();

    final user = authProvider.user;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("الإشعارات"),
        ),
        body: const Center(
          child: Text("يجب تسجيل الدخول لعرض الإشعارات"),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("الإشعارات"),
        actions: [
          IconButton(
            icon: const Icon(Icons.mark_email_read_outlined),
            tooltip: "تمييز الكل كمقروء",
            onPressed: () async {
              await notificationsProvider.markAllAsRead(
                userId: user.id,
              );
            },
          ),
        ],
      ),

      /// ===============================
      /// STREAM
      /// ===============================
      body: StreamBuilder<List<NotificationModel>>(
        stream: notificationsProvider.streamNotifications(user.id),

        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingWidget(
              message: "جاري تحميل الإشعارات...",
            );
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return const EmptyStateWidget(
              title: "لا توجد إشعارات",
              subtitle: "عندما يحدث نشاط جديد سيظهر هنا",
              icon: Icons.notifications_off,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),

            itemCount: notifications.length,

            separatorBuilder: (_, __) =>
                const Divider(height: 1),

            itemBuilder: (context, index) {

              final n = notifications[index];

              return ListTile(

                tileColor: n.isRead
                    ? null
                    : AppColors.primaryLight.withOpacity(0.06),

                leading: CircleAvatar(
                  backgroundColor: n.isRead
                      ? AppColors.lightCard
                      : AppColors.primary,
                  child: Icon(
                    _iconForType(n.type),
                    color: n.isRead
                        ? Colors.black54
                        : Colors.white,
                  ),
                ),

                title: Text(
                  n.title,
                  style: TextStyle(
                    fontWeight: n.isRead
                        ? FontWeight.w500
                        : FontWeight.bold,
                  ),
                ),

                subtitle: Text(
                  n.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                onTap: () async {

                  if (!n.isRead) {
                    await notificationsProvider.markAsRead(
                      userId: user.id,
                      notificationId: n.id,
                    );
                  }

                  _handleNotificationTap(
                    context,
                    notification: n,
                    currentUser: user,
                  );
                },

                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await notificationsProvider.deleteNotification(
                      userId: user.id,
                      notificationId: n.id,
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// ===============================
  /// NAVIGATION LOGIC
  /// ===============================
  void _handleNotificationTap(
    BuildContext context, {
    required NotificationModel notification,
    required dynamic currentUser,
  }) {

    switch (notification.type) {

      case "group":
        if (notification.refId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  GroupDetailsScreen(groupId: notification.refId!),
            ),
          );
        }
        break;

      case "private_message":
        if (notification.refId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PrivateChatScreen(
                chatId: notification.refId!,
                otherUser: currentUser,
              ),
            ),
          );
        }
        break;

      case "profile":
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ProfileScreen(),
          ),
        );
        break;

      case "promotion":
      case "suggested":
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SearchScreen(),
          ),
        );
        break;

      default:
        break;
    }
  }

  /// ===============================
  /// ICONS
  /// ===============================
  IconData _iconForType(String type) {

    switch (type) {

      case "group":
        return Icons.group;

      case "private_message":
        return Icons.chat_bubble;

      case "profile":
        return Icons.person;

      case "promotion":
        return Icons.campaign;

      default:
        return Icons.notifications;
    }
  }
}