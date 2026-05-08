import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/firebase/firestore_service.dart';
import '../core/constants/firestore_paths.dart';
import '../core/utils/notification_service.dart';

class NotificationsProvider extends ChangeNotifier {
  final FirestoreService _firestore;

  NotificationsProvider({
    required FirestoreService firestoreService,
  }) : _firestore = firestoreService;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  StreamSubscription? _sub;

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  // =========================================================
  // ✅ تسجيل FCM Token - النسخة المصححة مع إعادة المحاولة
  // =========================================================
  Future<void> registerToken(String userId) async {
    try {
      // 1. فعل مراقبة التجديد دائماً أولاً
      NotificationService.instance.listenToTokenRefresh((newToken) async {
        await _firestore.updateDocument(
          path: 'Users',
          docId: userId,
          data: {
            'fcmToken': newToken,
            'tokenUpdatedAt': FieldValue.serverTimestamp(),
          },
        );
        debugPrint('🔄 FCM Token refreshed for $userId');
      });

      // 2. حاول تجيب التوكن 3 مرات مع انتظار
      String? token;
      for (int i = 0; i < 3; i++) {
        token = await NotificationService.instance.getToken();
        if (token != null) break;
        debugPrint('⏳ Waiting for FCM token... attempt ${i + 1}');
        await Future.delayed(const Duration(seconds: 2));
      }

      if (token == null) {
        debugPrint('❌ FCM token still null after retries');
        return;
      }

      await _firestore.updateDocument(
        path: 'Users',
        docId: userId,
        data: {
          'fcmToken': token,
          'tokenUpdatedAt': FieldValue.serverTimestamp(),
        },
      );
      debugPrint('✅ FCM Token saved for $userId');
    } catch (e) {
      debugPrint('Failed to register FCM token: $e');
    }
  }

  // =========================================================
  // Stream notifications for a specific user
  // =========================================================
  Stream<List<NotificationModel>> streamNotifications(String userId) {
    final path = FirestorePaths.userNotifications(userId);

    final stream = _firestore.streamCollection(path: path).map((snapshot) {
      final list = snapshot.docs
          .map((doc) => NotificationModel.fromMap(doc.id, doc.data()))
          .toList();

      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });

    return stream;
  }

  // =========================================================
  // مراقبة عدد الإشعارات غير المقروءة
  // =========================================================
  Stream<int> getUnreadCountStream(String userId) {
    final path = FirestorePaths.userNotifications(userId);
    return _firestore.streamCollection(path: path).map((snapshot) {
      return snapshot.docs
          .where((doc) => (doc.data()['isRead'] ?? false) == false)
          .length;
    });
  }

  // =========================================================
  // Mark single notification as read
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
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // Mark single notification as unread
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
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // Mark all notifications as read
  // =========================================================
  Future<void> markAllAsRead({required String userId}) async {
    _setLoading(true);
    try {
      final snapshot = await _firestore.getCollection(
          path: FirestorePaths.userNotifications(userId));
      final docs = snapshot.docs
          .where((d) => (d.data()['isRead'] ?? false) == false)
          .toList();

      if (docs.isEmpty) return;

      await _firestore.runBatch((batch) async {
        for (final doc in docs) {
          final refPath = FirestorePaths.userNotifications(userId);
          final docRef = _firestore
              .buildQuery(path: refPath)
              .firestore
              .collection(refPath)
              .doc(doc.id);
          batch.update(docRef, {'isRead': true});
        }
      });
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // Delete a notification
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
    } finally {
      _setLoading(false);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
