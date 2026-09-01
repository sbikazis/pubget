import 'package:cloud_firestore/cloud_firestore.dart';

final class PrivateChatParticipant {
  const PrivateChatParticipant({
    required this.displayName,
    required this.avatarUrl,
    this.lastReadAt,
  });

  final String displayName;
  final String avatarUrl;
  final DateTime? lastReadAt;

  factory PrivateChatParticipant.fromMap(Map<String, dynamic> map) {
    return PrivateChatParticipant(
      displayName: map['displayName'] as String? ?? '',
      avatarUrl: map['avatarUrl'] as String? ?? '',
      lastReadAt: _date(map['lastReadAt']),
    );
  }
}

final class PrivateChatSummary {
  const PrivateChatSummary({
    required this.id,
    required this.participantIds,
    required this.userA,
    required this.userB,
    required this.lastMessageAt,
    required this.lastMessageText,
    required this.lastMessageSenderId,
    required this.createdAt,
    required this.participants,
    this.hiddenFor = const <String, bool>{},
  });

  final String id;
  final List<String> participantIds;
  final String userA;
  final String userB;
  final DateTime? lastMessageAt;
  final String lastMessageText;
  final String lastMessageSenderId;
  final DateTime? createdAt;
  final Map<String, PrivateChatParticipant> participants;
  final Map<String, bool> hiddenFor;

  factory PrivateChatSummary.fromMap(
    Map<String, dynamic> map, {
    required String id,
  }) {
    final participants = <String, PrivateChatParticipant>{};
    final raw = map['participants'];
    if (raw is Map) {
      for (final entry in raw.entries) {
        if (entry.key is String && entry.value is Map) {
          participants[entry.key as String] = PrivateChatParticipant.fromMap(
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      }
    }
    final hiddenFor = <String, bool>{};
    final hidden = map['hiddenFor'];
    if (hidden is Map) {
      for (final entry in hidden.entries) {
        if (entry.key is String && entry.value == true) {
          hiddenFor[entry.key as String] = true;
        }
      }
    }
    final ids =
        (map['participantIds'] as List<Object?>?)
            ?.whereType<String>()
            .toList(growable: false) ??
        <String>[
          map['userA'] as String? ?? '',
          map['userB'] as String? ?? '',
        ].where((id) => id.isNotEmpty).toList(growable: false);
    return PrivateChatSummary(
      id: id,
      participantIds: ids,
      userA: map['userA'] as String? ?? (ids.isNotEmpty ? ids.first : ''),
      userB: map['userB'] as String? ?? (ids.length > 1 ? ids[1] : ''),
      lastMessageAt: _date(map['lastMessageAt']),
      lastMessageText: map['lastMessageText'] as String? ?? '',
      lastMessageSenderId: map['lastMessageSenderId'] as String? ?? '',
      createdAt: _date(map['createdAt']),
      participants: participants,
      hiddenFor: hiddenFor,
    );
  }

  bool isHiddenFor(String userId) => hiddenFor[userId] == true;

  String otherUserId(String userId) {
    if (userA == userId) return userB;
    if (userB == userId) return userA;
    return participantIds.firstWhere(
      (id) => id != userId,
      orElse: () => userId,
    );
  }

  PrivateChatParticipant? otherParticipant(String userId) =>
      participants[otherUserId(userId)];

  String otherDisplayName(String userId) {
    final name = otherParticipant(userId)?.displayName.trim() ?? '';
    return name.isEmpty ? 'Pubget user' : name;
  }

  String otherAvatarUrl(String userId) =>
      otherParticipant(userId)?.avatarUrl ?? '';

  bool isUnreadFor(String userId) {
    if (lastMessageSenderId.isEmpty || lastMessageSenderId == userId) {
      return false;
    }
    if (lastMessageAt == null) return false;
    final readAt = participants[userId]?.lastReadAt;
    if (readAt == null) return true;
    return lastMessageAt!.isAfter(readAt);
  }
}

DateTime? _date(dynamic value) {
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  try {
    return value?.toDate() as DateTime?;
  } catch (_) {
    return null;
  }
}
