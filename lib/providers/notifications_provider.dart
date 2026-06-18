// lib/providers/notifications_provider.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/notification_model.dart';
import '../services/firebase/firestore_service.dart';
import '../core/constants/firestore_paths.dart';
import '../core/constants/notification_channels.dart';
import '../core/utils/notification_service.dart';

class NotificationsProvider extends ChangeNotifier {
  final FirestoreService _firestore;

  NotificationsProvider({
    required FirestoreService firestoreService,
  }) : _firestore = firestoreService;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // ✅ لمنع تسجيل listenToTokenRefresh أكثر من مرة
  bool _tokenRefreshListening = false;

  StreamSubscription? _sub;

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  // =========================================================
  // ✅ تسجيل FCM Token — مع فحوصات صحيحة
  // =========================================================
  Future<void> registerToken(String userId) async {
    // ✅ فحص: userId يجب ألا يكون فارغاً
    if (userId.trim().isEmpty) {
      debugPrint('⚠️ registerToken called with empty userId — skipped');
      return;
    }

    try {
      // ✅ تسجيل listener لتحديث الـ token عند تجديده — مرة واحدة فقط
      if (!_tokenRefreshListening) {
        _tokenRefreshListening = true;
        NotificationService.instance.listenToTokenRefresh((newToken) async {
          try {
            await _firestore.updateDocument(
              path: FirestorePaths.users, // ✅ مسار صحيح بدل 'Users'
              docId: userId,
              data: {
                'fcmToken': newToken,
                'tokenUpdatedAt': FieldValue.serverTimestamp(),
              },
            );
            debugPrint('🔄 FCM Token refreshed for $userId');
          } catch (e) {
            debugPrint('❌ Failed to update refreshed token: $e');
          }
        });
      }

      // ✅ محاولة جلب الـ token مع retry
      String? token;
      for (int i = 0; i < 3; i++) {
        token = await NotificationService.instance.getToken();
        if (token != null) break;
        debugPrint('⏳ Waiting for FCM token... attempt ${i + 1}');
        await Future.delayed(const Duration(seconds: 2));
      }

      if (token == null) {
        debugPrint('❌ FCM token still null after retries — skipped');
        return;
      }

      // ✅ حفظ الـ token في المسار الصحيح
      await _firestore.updateDocument(
        path: FirestorePaths.users, // ✅ مسار صحيح
        docId: userId,
        data: {
          'fcmToken': token,
          'tokenUpdatedAt': FieldValue.serverTimestamp(),
        },
      );

      debugPrint('✅ FCM Token saved for $userId');
    } catch (e) {
      debugPrint('❌ Failed to register FCM token: $e');
    }
  }

  // =========================================================
  // ✅ حذف FCM Token عند تسجيل الخروج
  // =========================================================
  Future<void> unregisterToken(String userId) async {
    if (userId.trim().isEmpty) return;

    try {
      await _firestore.updateDocument(
        path: FirestorePaths.users,
        docId: userId,
        data: {
          'fcmToken': null,
          'tokenUpdatedAt': FieldValue.serverTimestamp(),
        },
      );
      _tokenRefreshListening = false;
      debugPrint('✅ FCM Token removed for $userId');
    } catch (e) {
      debugPrint('❌ Failed to unregister FCM token: $e');
    }
  }

  // =========================================================
  // Stream notifications
  // =========================================================
  Stream<List<NotificationModel>> streamNotifications(String userId) {
    if (userId.trim().isEmpty) return Stream.value([]);

    final path = FirestorePaths.userNotifications(userId);

    return _firestore.streamCollection(path: path).map((snapshot) {
      final list = snapshot.docs
          .map((doc) => NotificationModel.fromMap(doc.id, doc.data()))
          .toList();

      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // =========================================================
  // عداد الإشعارات غير المقروءة
  // =========================================================
  Stream<int> getUnreadCountStream(String userId) {
    if (userId.trim().isEmpty) return Stream.value(0);

    final path = FirestorePaths.userNotifications(userId);
    return _firestore.streamCollection(path: path).map((snapshot) {
      return snapshot.docs
          .where((doc) => (doc.data()['isRead'] ?? false) == false)
          .length;
    });
  }

  // =========================================================
  // تمييز كمقروء
  // =========================================================
  Future<void> markAsRead({
    required String userId,
    required String notificationId,
  }) async {
    _setLoading(true);
    try {
      await _firestore.updateDocument(
        path: FirestorePaths.userNotifications(userId),
        docId: notificationId,
        data: {'isRead': true},
      );
    } catch (e) {
      debugPrint('❌ markAsRead failed: $e');
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // تمييز كغير مقروء
  // =========================================================
  Future<void> markAsUnread({
    required String userId,
    required String notificationId,
  }) async {
    _setLoading(true);
    try {
      await _firestore.updateDocument(
        path: FirestorePaths.userNotifications(userId),
        docId: notificationId,
        data: {'isRead': false},
      );
    } catch (e) {
      debugPrint('❌ markAsUnread failed: $e');
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // تمييز الكل كمقروء
  // =========================================================
  Future<void> markAllAsRead({required String userId}) async {
    if (userId.trim().isEmpty) return;

    _setLoading(true);
    try {
      final snapshot = await _firestore.getCollection(
        path: FirestorePaths.userNotifications(userId),
      );

      final unreadDocs = snapshot.docs
          .where((d) => (d.data()['isRead'] ?? false) == false)
          .toList();

      if (unreadDocs.isEmpty) return;

      // ✅ batch مباشر بدون buildQuery المعقّد
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      for (final doc in unreadDocs) {
        final ref = firestore
            .collection(FirestorePaths.userNotifications(userId))
            .doc(doc.id);
        batch.update(ref, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      debugPrint('❌ markAllAsRead failed: $e');
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // حذف إشعار
  // =========================================================
  Future<void> deleteNotification({
    required String userId,
    required String notificationId,
  }) async {
    _setLoading(true);
    try {
      await _firestore.deleteDocument(
        path: FirestorePaths.userNotifications(userId),
        docId: notificationId,
      );
    } catch (e) {
      debugPrint('❌ deleteNotification failed: $e');
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // إنشاء إشعار تعليق جديد
  // =========================================================
  Future<void> createCommentNotification({
    required String toUserId,
    required String fromUserId,
    required String fromUsername,
    required String editId,
    required String commentText,
    required String commentId,
  }) async {
    if (toUserId == fromUserId) return; // ✅ لا ترسل إشعاراً لنفسك

    try {
      final notification = NotificationModel(
        id: '',
        title: 'تعليق جديد 💬',
        body: '$fromUsername: $commentText',
        type: NotificationTypes.comment,
        refId: editId,
        senderId: fromUserId,
        commentId: commentId,
        createdAt: DateTime.now(),
        isRead: false,
      );

      final path = FirestorePaths.userNotifications(toUserId);
      final docId =
          FirebaseFirestore.instance.collection(path).doc().id;

      await _firestore.createDocument(
        path: path,
        docId: docId,
        data: notification.toMap(),
      );
    } catch (e) {
      debugPrint('❌ createCommentNotification failed: $e');
    }
  }

  // =========================================================
  // ✅ إنشاء إشعار رسالة مجموعة — يُستدعى من chat_provider
  // =========================================================
  Future<void> createGroupMessageNotification({
    required String toUserId,
    required String fromUserId,
    required String fromUsername,
    required String groupId,
    required String groupName,
    required String messageText,
  }) async {
    if (toUserId == fromUserId) return;

    try {
      final notification = NotificationModel(
        id: '',
        title: groupName,
        body: '$fromUsername: $messageText',
        type: NotificationTypes.groupChat,
        refId: groupId,
        senderId: fromUserId,
        createdAt: DateTime.now(),
        isRead: false,
      );

      final path = FirestorePaths.userNotifications(toUserId);
      final docId =
          FirebaseFirestore.instance.collection(path).doc().id;

      await _firestore.createDocument(
        path: path,
        docId: docId,
        data: notification.toMap(),
      );
    } catch (e) {
      debugPrint('❌ createGroupMessageNotification failed: $e');
    }
  }

  // =========================================================
  // ✅ إنشاء إشعار رسالة خاصة — يُستدعى من private_chat_provider
  // =========================================================
  Future<void> createPrivateMessageNotification({
    required String toUserId,
    required String fromUserId,
    required String fromUsername,
    required String chatId,
    required String messageText,
  }) async {
    if (toUserId == fromUserId) return;

    try {
      final notification = NotificationModel(
        id: '',
        title: fromUsername,
        body: messageText,
        type: NotificationTypes.privateChat,
        refId: chatId,
        senderId: fromUserId,
        createdAt: DateTime.now(),
        isRead: false,
      );

      final path = FirestorePaths.userNotifications(toUserId);
      final docId =
          FirebaseFirestore.instance.collection(path).doc().id;

      await _firestore.createDocument(
        path: path,
        docId: docId,
        data: notification.toMap(),
      );
    } catch (e) {
      debugPrint('❌ createPrivateMessageNotification failed: $e');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}