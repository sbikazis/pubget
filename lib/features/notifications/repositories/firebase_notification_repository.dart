import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../models/app_notification.dart';
import '../models/unread_counts.dart';
import 'notification_repository.dart';

final class FirebaseNotificationRepository implements NotificationRepository {
  FirebaseNotificationRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
    required FirebaseMessaging messaging,
  }) : _firestore = firestore,
       _functions = functions,
       _messaging = messaging;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseMessaging _messaging;
  String? _registeredToken;
  StreamSubscription<String>? _tokenRefreshSubscription;

  CollectionReference<Map<String, dynamic>> _notifications(String uid) =>
      _firestore.collection('users').doc(uid).collection('notifications');

  @override
  Stream<Result<List<AppNotification>>> getNotifications(
    String uid, {
    int limit = 30,
  }) => _notifications(uid)
      .orderBy('createdAt', descending: true)
      .orderBy(FieldPath.documentId, descending: true)
      .limit(limit)
      .snapshots()
      .map<Result<List<AppNotification>>>(
        (snapshot) => Success(
          snapshot.docs
              .map((doc) => AppNotification.fromMap(doc.data(), id: doc.id))
              .toList(growable: false),
        ),
      )
      .handleError(
        (Object error) => FailureResult<List<AppNotification>>(_failure(error)),
      );

  @override
  Future<Result<List<AppNotification>>> getOlderNotifications({
    required String uid,
    required AppNotification before,
    int limit = 30,
  }) => _guard(() async {
    final createdAt = before.createdAt;
    if (createdAt == null) return const <AppNotification>[];
    final snapshot = await _notifications(uid)
        .orderBy('createdAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true)
        .startAfter(<Object>[Timestamp.fromDate(createdAt), before.id])
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => AppNotification.fromMap(doc.data(), id: doc.id))
        .toList(growable: false);
  });

  @override
  Stream<Result<UnreadCounts>> watchUnreadCounts(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .snapshots()
      .map<Result<UnreadCounts>>(
        (snapshot) => Success(
          UnreadCounts(
            notifications: _count(snapshot, 'unreadNotificationsCount'),
            groups: _count(snapshot, 'unreadGroupsCount'),
            privateChats: _count(snapshot, 'unreadPrivateMessagesCount'),
            mentions: _count(snapshot, 'unreadMentionsCount'),
          ),
        ),
      )
      .handleError(
        (Object error) => FailureResult<UnreadCounts>(_failure(error)),
      );

  @override
  Future<Result<void>> markAsRead(String notificationId) =>
      _call('markNotificationRead', {'notificationId': notificationId});

  @override
  Future<Result<void>> markAllAsRead() =>
      _call('markAllNotificationsRead', const <String, dynamic>{});

  @override
  Future<Result<bool>> registerDeviceToken() => _guard(() async {
    final permission = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (permission.authorizationStatus == AuthorizationStatus.denied) {
      return false;
    }
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return false;
    await _functions.httpsCallable('registerFcmToken').call({
      'token': token,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
    });
    _registeredToken = token;
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((
      refreshedToken,
    ) async {
      await _functions.httpsCallable('registerFcmToken').call({
        'token': refreshedToken,
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      });
      _registeredToken = refreshedToken;
    });
    return true;
  });

  @override
  Future<Result<void>> unregisterDeviceToken() async {
    final token = _registeredToken ?? await _messaging.getToken();
    if (token == null || token.isEmpty) return const Success(null);
    final result = await _call('unregisterFcmToken', {'token': token});
    if (result.isSuccess) {
      _registeredToken = null;
      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = null;
    }
    return result;
  }

  Future<Result<void>> _call(String name, Map<String, dynamic> data) =>
      _guard(() async {
        await _functions.httpsCallable(name).call(data);
      });

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Success(await action());
    } on Object catch (error) {
      return FailureResult(_failure(error));
    }
  }
}

int _count(DocumentSnapshot<Map<String, dynamic>> snapshot, String field) =>
    ((snapshot.data()?[field] as num?)?.toInt() ?? 0).clamp(0, 9999);

Failure _failure(Object error) {
  if (error is FirebaseException &&
      (error.code == 'unavailable' || error.code == 'deadline-exceeded')) {
    return const NetworkError('Check your connection and try again.');
  }
  if (error is FirebaseFunctionsException) {
    return switch (error.code) {
      'permission-denied' || 'unauthenticated' => PermissionError(
        error.message ?? 'This notification action is not allowed.',
      ),
      _ => ValidationError(error.message ?? 'Notification action failed.'),
    };
  }
  return UnknownError(error.toString());
}
