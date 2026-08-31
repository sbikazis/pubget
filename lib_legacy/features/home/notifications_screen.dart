// lib/features/home/notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/constants/notification_channels.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state_widget.dart';

import '../../providers/notifications_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';

import '../../models/notification_model.dart';

import '../groups/group_details_screen.dart';
import '../groups/join_requests_screen.dart';
import '../groups/chat/chat_screen.dart';
import '../private_chat/private_chat_screen.dart';
import '../edits/edits_screen.dart';
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
        appBar: AppBar(title: const Text('الإشعارات')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                'يجب تسجيل الدخول لعرض الإشعارات',
                style: TextStyle(fontSize: 15, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.mark_email_read_outlined),
            tooltip: 'تمييز الكل كمقروء',
            onPressed: () =>
                notificationsProvider.markAllAsRead(userId: user.id),
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: notificationsProvider.streamNotifications(user.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingWidget(message: 'جاري تحميل الإشعارات...');
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return const EmptyStateWidget(
              title: 'لا توجد إشعارات',
              subtitle: 'عندما يحدث نشاط جديد سيظهر هنا',
              icon: Icons.notifications_off,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final n = notifications[index];
              return _NotificationTile(
                notification: n,
                userId: user.id,
                onTap: () async {
                  if (!n.isRead) {
                    await notificationsProvider.markAsRead(
                      userId: user.id,
                      notificationId: n.id,
                    );
                  }
                  if (context.mounted) {
                    _handleNotificationTap(context, notification: n);
                  }
                },
                onDelete: () => notificationsProvider.deleteNotification(
                  userId: user.id,
                  notificationId: n.id,
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _handleNotificationTap(
    BuildContext context, {
    required NotificationModel notification,
  }) {
    switch (notification.type) {
      case AppNotificationTypes.groupChat:
        if (notification.refId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(groupId: notification.refId!),
            ),
          );
        }
        break;

      case AppNotificationTypes.privateChat:
        if (notification.refId != null) {
          _navigateToPrivateChat(
            context,
            chatId: notification.refId!,
            otherUserId: notification.senderId,
          );
        }
        break;

      case NotificationTypes.requestAccepted:
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

      case NotificationTypes.requestRejected:
        break;

      case NotificationTypes.joinRequest:
        if (notification.refId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  JoinRequestsScreen(groupId: notification.refId!),
            ),
          );
        }
        break;

      case NotificationTypes.groupDisbanded:
        break;

      case NotificationTypes.comment:
        if (notification.refId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditsScreen(
                initialEditId: notification.refId!,
                initialCommentId: notification.commentId,
                autoOpenComments: true,
              ),
            ),
          );
        }
        break;

      case NotificationTypes.editLike:
        if (notification.refId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditsScreen(
                initialEditId: notification.refId!,
              ),
            ),
          );
        }
        break;

      case NotificationTypes.respectReceived:
        break;

      case 'promotion':
      case 'suggested':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SearchScreen()),
        );
        break;

      default:
        break;
    }
  }

  Future<void> _navigateToPrivateChat(
    BuildContext context, {
    required String chatId,
    required String? otherUserId,
  }) async {
    if (otherUserId == null || otherUserId.isEmpty) return;

    try {
      final userProvider = context.read<UserProvider>();
      final otherUser = await userProvider.getUserById(otherUserId);

      if (otherUser == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تعذّر فتح المحادثة — المستخدم غير موجود'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PrivateChatScreen(
              chatId: chatId,
              otherUser: otherUser,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error navigating to private chat: $e');
    }
  }
}

// ══════════════════════════════════════════════════════════════
// _NotificationTile
// ══════════════════════════════════════════════════════════════
class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final String userId;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NotificationTile({
    required this.notification,
    required this.userId,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final bool isUnread = !n.isRead;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      tileColor: isUnread
          ? AppColors.primary.withValues(alpha: 0.08)
          : null,
      leading: CircleAvatar(
        backgroundColor: isUnread
            ? AppColors.primary
            : AppColors.primary.withValues(alpha: 0.15),
        child: Icon(
          _iconForType(n.type),
          // ✅ بدل Colors.white/Colors.black54 الثابتة — تتكيف مع الثيم
          color: isUnread
              ? Colors.white
              : (isDark ? Colors.white60 : Colors.black54),
          size: 22,
        ),
      ),
      title: Text(
        n.title,
        style: textTheme.bodyLarge?.copyWith(
          fontWeight: isUnread ? FontWeight.bold : FontWeight.w500,
          // ✅ يرث لون النص من الثيم تلقائياً
          color: colorScheme.onSurface,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            n.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(
              // ✅ بدل Colors.black87/Colors.black54 الثابتة
              color: isUnread
                  ? colorScheme.onSurface
                  : colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _formatTime(n.createdAt),
            style: textTheme.bodySmall?.copyWith(
              fontSize: 11,
              // ✅ لون الوقت يتكيف مع الثيم
              color: colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
      onTap: onTap,
      trailing: IconButton(
        icon: Icon(
          Icons.delete_outline,
          size: 20,
          // ✅ لون أيقونة الحذف يتكيف مع الثيم
          color: colorScheme.onSurface.withValues(alpha: 0.4),
        ),
        onPressed: onDelete,
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case AppNotificationTypes.groupChat:
        return Icons.groups_outlined;
      case AppNotificationTypes.privateChat:
        return Icons.chat_bubble_outline;
      case NotificationTypes.requestAccepted:
        return Icons.verified_user_outlined;
      case NotificationTypes.requestRejected:
        return Icons.cancel_outlined;
      case NotificationTypes.joinRequest:
        return Icons.person_add_outlined;
      case NotificationTypes.groupDisbanded:
        return Icons.group_off_outlined;
      case NotificationTypes.comment:
        return Icons.comment_outlined;
      case NotificationTypes.editLike:
        return Icons.favorite_outline;
      case NotificationTypes.respectReceived:
        return Icons.star_outline;
      case 'promotion':
        return Icons.campaign_outlined;
      default:
        return Icons.notifications_none;
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';

    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
