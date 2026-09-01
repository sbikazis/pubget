import 'package:cloud_firestore/cloud_firestore.dart';

final class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.actorId,
    required this.targetId,
    required this.action,
    required this.destination,
    required this.metadata,
    required this.createdAt,
    required this.readAt,
    required this.groupKey,
  });

  final String id;
  final String type;
  final String? actorId;
  final String targetId;
  final String action;
  final String destination;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;
  final DateTime? readAt;
  final String? groupKey;

  bool get isUnread => readAt == null;

  factory AppNotification.fromMap(
    Map<String, dynamic> map, {
    required String id,
  }) => AppNotification(
    id: id,
    type: map['type'] as String? ?? 'unknown',
    actorId: map['actorId'] as String?,
    targetId: map['targetId'] as String? ?? '',
    action: map['action'] as String? ?? '',
    destination: map['destination'] as String? ?? '/home',
    metadata: map['metadata'] is Map
        ? Map<String, dynamic>.from(map['metadata'] as Map)
        : const <String, dynamic>{},
    createdAt: _date(map['createdAt']),
    readAt: _date(map['readAt']),
    groupKey: map['groupKey'] as String?,
  );
}

DateTime? _date(Object? value) {
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  return null;
}
