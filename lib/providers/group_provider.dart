import 'package:flutter/material.dart';

import '../models/group_model.dart';
import '../models/member_model.dart';
import '../models/invite_model.dart';

import '../services/firebase/firestore_service.dart';

import '../core/constants/firestore_paths.dart';

import '../core/logic/role_assignment_logic.dart';
import '../core/logic/invite_ranking_logic.dart';

class GroupProvider extends ChangeNotifier {
  final FirestoreService _firestore;

  GroupProvider({
    required FirestoreService firestoreService,
  }) : _firestore = firestoreService;

  // =========================================================
  // CREATE GROUP
  // =========================================================

  Future<void> createGroup({
    required GroupModel group,
    required MemberModel founderMember,
  }) async {
    final founder =
        RoleAssignmentLogic.createFounder(member: founderMember);

    await _firestore.createDocument(
      path: FirestorePaths.groups,
      docId: group.id,
      data: group.toMap(),
    );

    await _firestore.createDocument(
      path: FirestorePaths.groupMembers(group.id),
      docId: founder.userId,
      data: founder.toMap(),
    );
  }

  // =========================================================
  // UPDATE GROUP
  // =========================================================

  Future<void> updateGroup({
    required String groupId,
    required Map<String, dynamic> data,
  }) async {
    await _firestore.updateDocument(
      path: FirestorePaths.groups,
      docId: groupId,
      data: data,
    );
  }

  // =========================================================
  // DELETE GROUP
  // =========================================================

  Future<void> deleteGroup({
    required String groupId,
  }) async {
    await _firestore.deleteDocument(
      path: FirestorePaths.groups,
      docId: groupId,
    );
  }

  // =========================================================
  // GET GROUP
  // =========================================================

  Future<GroupModel?> getGroup({
    required String groupId,
  }) async {
    final data = await _firestore.getDocument(
      path: FirestorePaths.groups,
      docId: groupId,
    );

    if (data == null) return null;

    return GroupModel.fromMap(groupId, data);
  }

  // =========================================================
  // STREAM GROUP
  // =========================================================

  Stream<GroupModel?> streamGroup({
    required String groupId,
  }) {
    return _firestore
        .streamDocument(
          path: FirestorePaths.groups,
          docId: groupId,
        )
        .map((snapshot) {
      if (!snapshot.exists) return null;

      final data = snapshot.data();
      if (data == null) return null;

      return GroupModel.fromMap(snapshot.id, data);
    });
  }

  // =========================================================
  // STREAM GROUPS
  // =========================================================

  Stream<List<GroupModel>> streamGroups() {
    return _firestore
        .streamCollection(path: FirestorePaths.groups)
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => GroupModel.fromMap(
                doc.id,
                doc.data(),
              ))
          .toList();
    });
  }

  // =========================================================
  // ADD MEMBER
  // =========================================================

  Future<void> addMember({
    required MemberModel member,
  }) async {
    await _firestore.createDocument(
      path: FirestorePaths.groupMembers(member.groupId),
      docId: member.userId,
      data: member.toMap(),
    );
  }

  // =========================================================
  // REMOVE MEMBER
  // =========================================================

  Future<void> removeMember({
    required String groupId,
    required String userId,
  }) async {
    await _firestore.deleteDocument(
      path: FirestorePaths.groupMembers(groupId),
      docId: userId,
    );
  }

  // =========================================================
  // STREAM MEMBERS
  // =========================================================

  Stream<List<MemberModel>> streamMembers({
    required String groupId,
  }) {
    return _firestore
        .streamCollection(
          path: FirestorePaths.groupMembers(groupId),
        )
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MemberModel.fromMap(
                doc.data(),
              ))
          .toList();
    });
  }

  // =========================================================
  // GET MEMBERS ONCE
  // =========================================================

  Future<List<MemberModel>> getMembers({
    required String groupId,
  }) async {
    final snapshot = await _firestore.getCollection(
      path: FirestorePaths.groupMembers(groupId),
    );

    return snapshot.docs
        .map((doc) => MemberModel.fromMap(
              doc.data(),
            ))
        .toList();
  }

  // =========================================================
  // CREATE INVITE
  // =========================================================

  Future<void> createInvite({
    required InviteModel invite,
  }) async {
    await _firestore.createDocument(
      path: FirestorePaths.groupInvites(invite.groupId),
      docId: invite.inviteId,
      data: invite.toMap(),
    );
  }

  // =========================================================
  // STREAM INVITES
  // =========================================================

  Stream<List<InviteModel>> streamInvites({
    required String groupId,
  }) {
    return _firestore
        .streamCollection(
          path: FirestorePaths.groupInvites(groupId),
        )
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => InviteModel.fromMap(
                doc.id,
                doc.data(),
              ))
          .toList();
    });
  }

  // =========================================================
  // APPLY INVITE RANKING
  // =========================================================

  Future<List<MemberModel>> applyInviteRanking({
    required String groupId,
  }) async {
    final members = await getMembers(groupId: groupId);

    final inviteSnapshot = await _firestore.getCollection(
      path: FirestorePaths.groupInvites(groupId),
    );

    final invites = inviteSnapshot.docs
        .map((doc) => InviteModel.fromMap(
              doc.id,
              doc.data(),
            ))
        .toList();

    final updatedMembers =
        InviteRankingLogic.applyInviteRanking(
      members: members,
      invites: invites,
    );

    await _firestore.runBatch((batch) async {
      for (final member in updatedMembers) {
        final refPath =
            FirestorePaths.groupMembers(groupId);

        final docRef = _firestore
            .buildQuery(path: refPath)
            .firestore
            .collection(refPath)
            .doc(member.userId);

        batch.update(docRef, member.toMap());
      }
    });

    return updatedMembers;
  }

  // =========================================================
  // RESERVE CHARACTER (ROLEPLAY)
  // =========================================================

  Future<void> reserveCharacter({
    required String groupId,
    required String characterName,
    required String imageUrl,
    required String userId,
  }) async {
    await _firestore.createDocument(
      path: FirestorePaths.groupCharacters(groupId),
      docId: characterName,
      data: {
        'userId': userId,
        'imageUrl': imageUrl,
        'reservedAt': DateTime.now(),
      },
    );
  }

  // =========================================================
  // CHECK CHARACTER RESERVED
  // =========================================================

  Future<bool> isCharacterReserved({
    required String groupId,
    required String characterName,
  }) async {
    final doc = await _firestore.getDocument(
      path: FirestorePaths.groupCharacters(groupId),
      docId: characterName,
    );

    return doc != null;
  }
  // =========================================================
// GET USER GROUPS
// =========================================================

Future<List<GroupModel>> getUserGroups({
  required String userId,
}) async {
  final groupsSnapshot = await _firestore.getCollection(
    path: FirestorePaths.groups,
  );

  final List<GroupModel> userGroups = [];

  for (final doc in groupsSnapshot.docs) {
    final groupId = doc.id;

    final memberDoc = await _firestore.getDocument(
      path: FirestorePaths.groupMembers(groupId),
      docId: userId,
    );

    if (memberDoc != null) {
      final group = GroupModel.fromMap(
        groupId,
        doc.data(),
      );

      userGroups.add(group);
    }
  }

  return userGroups;
}
}