enum FriendshipStatus { pending, accepted, blocked }

final class RespectRelation {
  const RespectRelation({
    required this.fromUserId,
    required this.toUserId,
    required this.value,
  });

  final String fromUserId;
  final String toUserId;
  final int value;

  factory RespectRelation.fromMap(Map<String, dynamic> map) {
    return RespectRelation(
      fromUserId: map['fromUserId'] as String? ?? '',
      toUserId: map['toUserId'] as String? ?? '',
      value: (map['value'] as num?)?.toInt() ?? 0,
    );
  }
}

final class Friendship {
  const Friendship({
    required this.userA,
    required this.userB,
    required this.status,
    required this.requestedBy,
    this.blockedBy,
  });

  final String userA;
  final String userB;
  final FriendshipStatus status;
  final String requestedBy;
  final String? blockedBy;

  List<String> get userIds => <String>[userA, userB];

  String otherUserId(String userId) => userId == userA ? userB : userA;

  factory Friendship.fromMap(Map<String, dynamic> map) {
    final rawStatus = map['status'] as String? ?? 'pending';
    return Friendship(
      userA: map['userA'] as String? ?? '',
      userB: map['userB'] as String? ?? '',
      status: FriendshipStatus.values.firstWhere(
        (status) => status.name == rawStatus,
        orElse: () => FriendshipStatus.pending,
      ),
      requestedBy: map['requestedBy'] as String? ?? '',
      blockedBy: map['blockedBy'] as String?,
    );
  }
}

final class SocialSnapshot {
  const SocialSnapshot({
    this.givenRespect = const <RespectRelation>[],
    this.receivedRespect = const <RespectRelation>[],
    this.friendships = const <Friendship>[],
  });

  final List<RespectRelation> givenRespect;
  final List<RespectRelation> receivedRespect;
  final List<Friendship> friendships;

  List<Friendship> get friends => friendships
      .where((friendship) => friendship.status == FriendshipStatus.accepted)
      .toList(growable: false);

  List<Friendship> pendingFor(String userId) => friendships
      .where(
        (friendship) =>
            friendship.status == FriendshipStatus.pending &&
            friendship.requestedBy != userId,
      )
      .toList(growable: false);

  List<Friendship> outgoingFor(String userId) => friendships
      .where(
        (friendship) =>
            friendship.status == FriendshipStatus.pending &&
            friendship.requestedBy == userId,
      )
      .toList(growable: false);

  Friendship? relationWith(String userId) {
    for (final friendship in friendships) {
      if (friendship.userIds.contains(userId)) return friendship;
    }
    return null;
  }
}
