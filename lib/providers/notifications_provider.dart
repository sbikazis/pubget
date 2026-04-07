// lib/providers/notifications_provider.dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../models/notification_model.dart';
import '../services/firebase/firestore_service.dart';
import '../core/constants/firestore_paths.dart';

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

  /// Stream notifications for a specific user
  Stream<List<NotificationModel>> streamNotifications(String userId) {
    final path = FirestorePaths.userNotifications(userId);

    // Use streamCollection from FirestoreService
    final stream = _firestore.streamCollection(path: path).map((snapshot) {
      final list = snapshot.docs
          .map((doc) => NotificationModel.fromMap(doc.id, doc.data()))
          .toList();

      // Sort by createdAt desc
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });

    return stream;
  }

  // 🔥 التعديل: دالة مخصصة لمراقبة عدد الإشعارات غير المقروءة فقط
  // هذا يساعد في تقليل استهلاك البيانات وتحديث الواجهة الرئيسية فوراً
  Stream<int> getUnreadCountStream(String userId) {
    final path = FirestorePaths.userNotifications(userId);
    return _firestore.streamCollection(path: path).map((snapshot) {
      return snapshot.docs
          .where((doc) => (doc.data()['isRead'] ?? false) == false)
          .length;
    });
  }

  /// Mark single notification as read
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

  /// Mark single notification as unread
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

  /// Mark all notifications as read for a user
  Future<void> markAllAsRead({required String userId}) async {
    _setLoading(true);
    try {
      final snapshot = await _firestore.getCollection(path: FirestorePaths.userNotifications(userId));
      final docs = snapshot.docs.where((d) => (d.data()['isRead'] ?? false) == false).toList();

      if (docs.isEmpty) return;

      await _firestore.runBatch((batch) async {
        for (final doc in docs) {
          final refPath = FirestorePaths.userNotifications(userId);
          final docRef = _firestore.buildQuery(path: refPath).firestore.collection(refPath).doc(doc.id);
          batch.update(docRef, {'isRead': true});
        }
      });
    } finally {
      _setLoading(false);
    }
  }

  /// Delete a notification
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