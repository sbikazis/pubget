import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../models/group_authority.dart';
import '../models/group_models.dart';
import 'group_members_repository.dart';
import 'group_repository.dart';
import 'roleplay_repository.dart';

final class FirebaseGroupRepository implements GroupRepository {
  FirebaseGroupRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  @override
  Future<Result<Group>> createGroup(GroupDraft draft) =>
      _guard(() => _callGroup('createGroup', draft.toMap()));

  @override
  Future<Result<Group>> getGroup(String groupId) => _guard(() async {
    final snapshot = await _firestore.collection('groups').doc(groupId).get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError('Group not found.');
    }
    return Group.fromMap(snapshot.data()!, id: snapshot.id);
  });

  @override
  Future<Result<GroupMember?>> getMembership(String groupId, String userId) =>
      _guard(() async {
        final snapshot = await _firestore
            .collection('groups')
            .doc(groupId)
            .collection('members')
            .doc(userId)
            .get();
        if (!snapshot.exists || snapshot.data() == null) return null;
        final member = GroupMember.fromMap(snapshot.data()!, uid: userId);
        final roleSnap = await _firestore
            .collection('groups')
            .doc(groupId)
            .collection('roles')
            .doc(member.roleDocumentId)
            .get();
        if (!roleSnap.exists || roleSnap.data() == null) return member;
        final definition = GroupRoleDefinition.fromMap(
          roleSnap.data()!,
          id: roleSnap.id,
        );
        return member.withEffectivePermissions(definition.permissions);
      });

  @override
  Future<Result<List<Group>>> searchGroups(String query) => _guard(() async {
    final snapshot = await _firestore
        .collection('groups')
        .where('isSearchable', isEqualTo: true)
        .limit(50)
        .get();
    final normalized = query.trim().toLowerCase();
    return snapshot.docs
        .map((doc) => Group.fromMap(doc.data(), id: doc.id))
        .where(
          (group) =>
              normalized.isEmpty ||
              group.name.toLowerCase().contains(normalized) ||
              group.description.toLowerCase().contains(normalized),
        )
        .toList(growable: false);
  });

  @override
  Future<Result<List<Group>>> listJoinedGroups(String userId) => _guard(() async {
    final snapshot = await _firestore
        .collectionGroup('members')
        .where('uid', isEqualTo: userId)
        .limit(50)
        .get();
    return _groupsFromMemberships(snapshot);
  });

  @override
  Stream<Result<List<Group>>> watchJoinedGroups(String userId) => _firestore
      .collectionGroup('members')
      .where('uid', isEqualTo: userId)
      .limit(50)
      .snapshots()
      .asyncMap((snapshot) async {
        try {
          return Success(await _groupsFromMemberships(snapshot));
        } on Object catch (error) {
          return FailureResult<List<Group>>(_groupFailure(error));
        }
      });

  Future<List<Group>> _groupsFromMemberships(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    final lastReadByGroup = <String, DateTime?>{};
    for (final doc in snapshot.docs) {
      final groupId = doc.reference.parent.parent?.id;
      if (groupId == null) continue;
      lastReadByGroup[groupId] = _memberDate(doc.data()['lastReadAt']);
    }
    if (lastReadByGroup.isEmpty) return const <Group>[];
    final snaps = await Future.wait(
      lastReadByGroup.keys.map((id) => _firestore.collection('groups').doc(id).get()),
    );
    return snaps
        .where((snap) => snap.exists && snap.data() != null)
        .map(
          (snap) => Group.fromMap(
            snap.data()!,
            id: snap.id,
            viewerLastReadAt: lastReadByGroup[snap.id],
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<Result<void>> joinGroup({
    required String groupId,
    String? inviteId,
    GroupJoinPayload? join,
  }) => _guard(() async {
    await _callVoid('joinGroup', <String, dynamic>{
      'groupId': groupId,
      'inviteId': ?inviteId,
      ...?join?.toMap(),
    });
  });

  @override
  Future<Result<void>> requestToJoin({
    required String groupId,
    GroupJoinPayload? join,
  }) => _guard(() async {
    await _callVoid('requestToJoin', <String, dynamic>{
      'groupId': groupId,
      ...?join?.toMap(),
    });
  });

  @override
  Future<Result<bool>> isBanned({
    required String groupId,
    required String userId,
  }) => _guard(() async {
    final snapshot = await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('bans')
        .doc(userId)
        .get();
    return snapshot.exists;
  });

  @override
  Future<Result<bool>> hasPendingRequest({
    required String groupId,
    required String userId,
  }) => _guard(() async {
    final snapshot = await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('requests')
        .doc(userId)
        .get();
    return snapshot.exists && snapshot.data()?['status'] == 'pending';
  });

  @override
  Future<Result<List<RoleplayCharacter>>> reservedCharacters(String groupId) =>
      _guard(() async {
        final snapshot = await _firestore
            .collection('groups')
            .doc(groupId)
            .collection('characters')
            .get();
        return snapshot.docs
            .map(
              (doc) => RoleplayCharacter.fromMap(
                doc.data(),
                key: doc.id,
              ).asReserved(),
            )
            .toList(growable: false);
      });

  @override
  Future<Result<void>> leaveGroup(String groupId) => _guard(() async {
    await _callVoid('leaveGroup', <String, dynamic>{'groupId': groupId});
  });

  @override
  Future<Result<void>> disbandGroup(String groupId) => _guard(() async {
    await _callVoid('disbandGroup', <String, dynamic>{
      'groupId': groupId,
      'mode': 'disband',
      'farewellMessage': '',
    });
  });

  @override
  Future<Result<void>> updateGroupSettings({
    required String groupId,
    required GroupSettingsUpdate settings,
  }) => _guard(() async {
    await _callVoid('updateGroupSettings', settings.toMap(groupId: groupId));
  });

  @override
  Future<Result<void>> promoteGroup(String groupId) => _guard(() async {
    await _callVoid('promoteGroup', <String, dynamic>{'groupId': groupId});
  });

  Future<Group> _callGroup(String name, Map<String, dynamic> data) async {
    final result = await _functions.httpsCallable(name).call(data);
    final group = result.data['group'] as Map<dynamic, dynamic>;
    return Group.fromMap(
      Map<String, dynamic>.from(group),
      id: result.data['groupId'] as String,
    );
  }

  Future<void> _callVoid(String name, Map<String, dynamic> data) async {
    await _functions.httpsCallable(name).call(data);
  }

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Success<T>(await action());
    } on Object catch (error) {
      return FailureResult<T>(_groupFailure(error));
    }
  }
}

final class FirebaseGroupMembersRepository implements GroupMembersRepository {
  FirebaseGroupMembersRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  @override
  Future<Result<List<GroupMember>>> getMembers(
    String groupId, {
    int limit = 25,
    String? afterUid,
  }) => _guard(() async {
    var query = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .orderBy(FieldPath.documentId)
        .limit(limit);
    if (afterUid != null) query = query.startAfter(<dynamic>[afterUid]);
    final snapshot = await query.get();
    final members = snapshot.docs
        .map((doc) => GroupMember.fromMap(doc.data(), uid: doc.id))
        .toList(growable: false);
    return _hydrateMemberProfiles(members);
  });

  Future<List<GroupMember>> _hydrateMemberProfiles(
    List<GroupMember> members,
  ) async {
    if (members.isEmpty) return members;
    final hydrated = <GroupMember>[];
    for (var i = 0; i < members.length; i += 10) {
      final chunk = members.sublist(
        i,
        i + 10 > members.length ? members.length : i + 10,
      );
      final docs = await Future.wait(
        chunk.map(
          (member) => _firestore.collection('users').doc(member.uid).get(),
        ),
      );
      for (var j = 0; j < chunk.length; j++) {
        final data = docs[j].data();
        if (data == null) {
          hydrated.add(chunk[j]);
          continue;
        }
        hydrated.add(
          chunk[j].withProfile(
            displayName: data['displayName'] as String?,
            username: data['username'] as String?,
            avatarUrl: data['avatarUrl'] as String?,
          ),
        );
      }
    }
    return hydrated;
  }

  @override
  Future<Result<List<JoinRequest>>> getJoinRequests(String groupId) =>
      _guard(() async {
        final snapshot = await _firestore
            .collection('groups')
            .doc(groupId)
            .collection('requests')
            .where('status', isEqualTo: 'pending')
            .get();
        return snapshot.docs
            .map((doc) => JoinRequest.fromMap(doc.data(), uid: doc.id))
            .toList(growable: false);
      });

  @override
  Future<Result<List<GroupRoleDefinition>>> getRoles(String groupId) =>
      _guard(() async {
        final snapshot = await _firestore
            .collection('groups')
            .doc(groupId)
            .collection('roles')
            .orderBy('position', descending: true)
            .get();
        return snapshot.docs
            .map((doc) => GroupRoleDefinition.fromMap(doc.data(), id: doc.id))
            .toList(growable: false);
      });

  @override
  Future<Result<String>> createInvite({
    required String groupId,
    required String toUid,
  }) => _guard(() async {
    final result = await _functions.httpsCallable('createGroupInvite').call(
      <String, dynamic>{'groupId': groupId, 'toUid': toUid},
    );
    return result.data['inviteId'] as String;
  });

  @override
  Future<Result<void>> updateRolePermissions({
    required String groupId,
    required PubgetRank role,
    required Set<GroupPermission> permissions,
  }) => _guard(
    () => _call('updateRolePermissions', <String, dynamic>{
      'groupId': groupId,
      'role': pubgetRankStorageId(role),
      'permissions': permissions
          .map((permission) => permission.name)
          .toList(growable: false),
    }),
  );

  Future<void> _call(String name, Map<String, dynamic> data) async {
    await _functions.httpsCallable(name).call(data);
  }

  @override
  Future<Result<void>> changeRole({
    required String groupId,
    required String uid,
    required PubgetRank role,
  }) => _guard(
    () => _call('changeRole', {
      'groupId': groupId,
      'uid': uid,
      'role': pubgetRankStorageId(role),
    }),
  );

  @override
  Future<Result<void>> kickMember({
    required String groupId,
    required String uid,
  }) => _guard(() => _call('kickMember', {'groupId': groupId, 'uid': uid}));

  @override
  Future<Result<void>> banMember({
    required String groupId,
    required String uid,
  }) => _guard(() => _call('banMember', {'groupId': groupId, 'uid': uid}));

  @override
  Future<Result<String>> prepareOwnershipTransfer({
    required String groupId,
    required String uid,
  }) => _guard(() async {
    final result = await _functions
        .httpsCallable('prepareOwnershipTransfer')
        .call(<String, dynamic>{'groupId': groupId, 'uid': uid});
    return result.data['confirmationToken'] as String;
  });

  @override
  Future<Result<void>> transferOwnership({
    required String groupId,
    required String uid,
    required String confirmationToken,
  }) => _guard(
    () => _call('transferOwnership', {
      'groupId': groupId,
      'uid': uid,
      'confirmationToken': confirmationToken,
    }),
  );

  @override
  Future<Result<void>> acceptJoinRequest({
    required String groupId,
    required String uid,
  }) => _guard(
    () => _call('acceptJoinRequest', {'groupId': groupId, 'uid': uid}),
  );

  @override
  Future<Result<void>> rejectJoinRequest({
    required String groupId,
    required String uid,
  }) => _guard(
    () => _call('rejectJoinRequest', {'groupId': groupId, 'uid': uid}),
  );

  @override
  Future<Result<List<GroupBan>>> getBans(String groupId) => _guard(() async {
    final snapshot = await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('bans')
        .get();
    return snapshot.docs
        .map((doc) => GroupBan.fromMap(doc.data(), uid: doc.id))
        .toList(growable: false);
  });

  @override
  Future<Result<void>> unbanMember({
    required String groupId,
    required String uid,
  }) => _guard(() => _call('unbanMember', {'groupId': groupId, 'uid': uid}));

  @override
  Future<Result<void>> warnMember({
    required String groupId,
    required String uid,
    required String type,
    required String details,
  }) => _guard(
    () => _call('warnMember', {
      'groupId': groupId,
      'uid': uid,
      'type': type,
      'details': details,
    }),
  );

  @override
  Future<Result<List<RankAuditEvent>>> getRankAudit(
    String groupId, {
    String? targetUid,
    int limit = 40,
  }) => _guard(() async {
    final snapshot = await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('rankAudit')
        .orderBy('at', descending: true)
        .limit(targetUid == null ? limit : 120)
        .get();
    var events = snapshot.docs
        .map((doc) => RankAuditEvent.fromMap(doc.data(), id: doc.id))
        .toList(growable: false);
    if (targetUid != null && targetUid.trim().isNotEmpty) {
      final id = targetUid.trim();
      events = events
          .where((event) => event.targetUid == id)
          .take(limit)
          .toList(growable: false);
    }
    return events;
  });

  @override
  Future<Result<List<MemberWarningRecord>>> getWarnings(
    String groupId, {
    required String targetUid,
    int limit = 40,
  }) => _guard(() async {
    final snapshot = await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('warnings')
        .orderBy('createdAt', descending: true)
        .limit(120)
        .get();
    return snapshot.docs
        .map((doc) => MemberWarningRecord.fromMap(doc.data(), id: doc.id))
        .where((warning) => warning.targetUid == targetUid)
        .take(limit)
        .toList(growable: false);
  });

  @override
  Future<Result<List<GroupMember>>> lookupInviteCandidates({
    required String query,
    int limit = 12,
  }) => _guard(() async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const <GroupMember>[];
    final byId = await _firestore.collection('users').doc(trimmed).get();
    if (byId.exists) {
      final data = byId.data() ?? <String, dynamic>{};
      return <GroupMember>[
        GroupMember(
          uid: byId.id,
          role: PubgetRank.ronin,
          displayName: data['displayName'] as String?,
          username: data['username'] as String?,
          avatarUrl: data['avatarUrl'] as String?,
        ),
      ];
    }
    final handle = trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
    final snapshot = await _firestore
        .collection('users')
        .where('username', isEqualTo: handle)
        .limit(limit)
        .get();
    return snapshot.docs
        .map(
          (doc) => GroupMember(
            uid: doc.id,
            role: PubgetRank.ronin,
            displayName: doc.data()['displayName'] as String?,
            username: doc.data()['username'] as String?,
            avatarUrl: doc.data()['avatarUrl'] as String?,
          ),
        )
        .toList(growable: false);
  });

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Success<T>(await action());
    } on Object catch (error) {
      return FailureResult<T>(_groupFailure(error));
    }
  }
}

final class FirebaseRoleplayRepository implements RoleplayRepository {
  FirebaseRoleplayRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  @override
  Future<Result<void>> reserveCharacter({
    required String groupId,
    required String characterKey,
    required RoleplayCharacter character,
  }) => _guard(() async {
    await _functions.httpsCallable('reserveRoleplayCharacter').call({
      'groupId': groupId,
      'characterKey': characterKey,
      'character': {'name': character.name, 'avatarUrl': character.avatarUrl},
    });
  });

  @override
  Future<Result<void>> releaseCharacter({
    required String groupId,
    required String characterKey,
  }) => _guard(() async {
    await _functions.httpsCallable('releaseRoleplayCharacter').call({
      'groupId': groupId,
      'characterKey': characterKey,
    });
  });

  @override
  Future<Result<List<RoleplayCharacter>>> getAvailableCharacters(
    String groupId,
  ) => _guard(() async {
    final reserved = await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('characters')
        .get();
    final keys = reserved.docs.map((doc) => doc.id).toSet();
    return _mockCharacters
        .where((character) => !keys.contains(character.key))
        .toList(growable: false);
  });

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Success<T>(await action());
    } on Object catch (error) {
      return FailureResult<T>(_groupFailure(error));
    }
  }
}

const _mockCharacters = <RoleplayCharacter>[
  RoleplayCharacter(key: 'hero', name: 'The Hero', avatarUrl: ''),
  RoleplayCharacter(key: 'rival', name: 'The Rival', avatarUrl: ''),
  RoleplayCharacter(key: 'mentor', name: 'The Mentor', avatarUrl: ''),
  RoleplayCharacter(key: 'trickster', name: 'The Trickster', avatarUrl: ''),
];

DateTime? _memberDate(Object? value) {
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  return null;
}

Failure _groupFailure(Object error) {
  if (error is FirebaseFunctionsException) {
    return switch (error.code) {
      'unauthenticated' || 'permission-denied' => PermissionError(
        error.message ?? 'This group action is not allowed.',
      ),
      'not-found' => NotFoundError(error.message ?? 'Group not found.'),
      'unavailable' || 'resource-exhausted' => NetworkError(
        error.message ?? 'Please try again.',
      ),
      _ => ValidationError(error.message ?? 'Group action failed.'),
    };
  }
  if (error is FirebaseException &&
      (error.code == 'unavailable' || error.code == 'deadline-exceeded')) {
    return const NetworkError('Check your connection and try again.');
  }
  return UnknownError(error.toString());
}
