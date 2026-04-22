// lib/providers/group_provider.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import '../models/group_model.dart';
import '../models/member_model.dart';
import '../models/invite_model.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';

import '../services/firebase/firestore_service.dart';
import '../core/constants/firestore_paths.dart';
import '../core/logic/role_assignment_logic.dart';
import '../core/logic/invite_ranking_logic.dart';
import 'package:pubget/services/monetization/promotion_service.dart';

class GroupProvider extends ChangeNotifier {
  final FirestoreService _firestore;

  GroupProvider({
    required FirestoreService firestoreService,
  }) : _firestore = firestoreService;

  // =========================================================
  // PROMOTION
  // =========================================================
  Future<void> promoteGroup({
    required String groupId,
    required String userId,
  }) async {
    final promotionService = PromotionService(_firestore);
    try {
      await promotionService.promoteGroup(
        groupId: groupId,
        promoterUserId: userId,
        durationInDays: 7,
      );
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Error promoting group: $e");
      rethrow;
    }
  }

  // =========================================================
  // JOIN REQUESTS LOGIC
  // =========================================================

  Future<void> sendJoinRequest({
    required String groupId,
    required String groupName,
    required String founderId,
    required MemberModel memberRequest,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      final requestRef = firestore
          .collection(FirestorePaths.groupJoinRequests(groupId))
          .doc(memberRequest.userId);
      batch.set(requestRef, memberRequest.toMap());

      final notifId = firestore.collection(FirestorePaths.userNotifications(founderId)).doc().id;
      final notification = NotificationModel(
        id: notifId,
        title: 'طلب انضمام جديد 📥',
        body: 'قدم ${memberRequest.realUserName} طلباً للانضمام إلى مجموعة "$groupName"',
        type: NotificationTypes.joinRequest,
        refId: groupId,
        createdAt: DateTime.now(),
        isRead: false,
      );

      final notifRef = firestore
          .collection(FirestorePaths.userNotifications(founderId))
          .doc(notifId);
      batch.set(notifRef, notification.toMap());

      await batch.commit();
     
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Error sending join request with notification: $e");
      rethrow;
    }
  }

  Future<void> acceptJoinRequest({
    required String groupId,
    required String groupName,
    required MemberModel requestMember,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // 🔥 التعديل الحاسم: جلب حالة البريميوم الحقيقية للمستخدم من وثيقة Users
      final userDoc = await firestore.collection('Users').doc(requestMember.userId).get();
      bool currentPremiumStatus = false;
      if (userDoc.exists) {
        final userData = userDoc.data();
        // نتحقق من نوع الاشتراك إذا كان premium
        currentPremiumStatus = (userData?['subscriptionType'] == 'premium');
      }

      if (requestMember.characterName != null) {
        final isTaken = await isCharacterReserved(
          groupId: groupId,
          characterName: requestMember.characterName!
        );
        if (isTaken) {
          throw "للأسف، تم حجز هذه الشخصية من قبل عضو آخر قبل لحظات.";
        }
      }

      final batch = firestore.batch();

      // ✅ ندمج حالة البريميوم الفعلية داخل كائن العضو الجديد
      final newMember = requestMember.copyWith(
        isManualRole: false,
        isPremium: currentPremiumStatus, // الحقن المباشر للحالة
      );

      final memberRef = firestore
          .collection(FirestorePaths.groupMembers(groupId))
          .doc(newMember.userId);
      batch.set(memberRef, newMember.toMap());

      final requestRef = firestore
          .collection(FirestorePaths.groupJoinRequests(groupId))
          .doc(newMember.userId);
      batch.delete(requestRef);

      final groupRef = firestore
          .collection(FirestorePaths.groups)
          .doc(groupId);
      batch.update(groupRef, {'membersCount': FieldValue.increment(1)});
       
      if (newMember.characterName != null) {
         final charKey = newMember.characterName!.toLowerCase().replaceAll(RegExp(r'\s+'), '');
         final charRef = firestore
          .collection(FirestorePaths.groupCharacters(groupId))
          .doc(charKey);
         batch.set(charRef, {
          'userId': newMember.userId,
          'characterName': newMember.characterName,
          'imageUrl': newMember.characterImageUrl,
          'reservedAt': FieldValue.serverTimestamp(),
        });
      }

      final notifId = firestore.collection(FirestorePaths.userNotifications(newMember.userId)).doc().id;
      final notification = NotificationModel(
        id: notifId,
        title: 'تم قبولك! 🎉',
        body: 'وافق الشوغو على طلب انضمامك لمجموعة "$groupName". يمكنك الدردشة الآن!',
        type: NotificationTypes.requestAccepted,
        refId: groupId,
        createdAt: DateTime.now(),
        isRead: false,
      );

      final notifRef = firestore
          .collection(FirestorePaths.userNotifications(newMember.userId))
          .doc(notifId);
      batch.set(notifRef, notification.toMap());

      await batch.commit();

      await Future.delayed(const Duration(milliseconds: 150));
     
      await InviteRankingLogic.refreshRanks(groupId: groupId);
      notifyListeners();
    } catch (e) {
      debugPrint("Error accepting request: $e");
      rethrow;
    }
  }

  Future<void> rejectJoinRequest({
    required String groupId,
    required String groupName,
    required String userId,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      final requestRef = firestore
          .collection(FirestorePaths.groupJoinRequests(groupId))
          .doc(userId);
      batch.delete(requestRef);

      final notifId = firestore.collection(FirestorePaths.userNotifications(userId)).doc().id;
      final notification = NotificationModel(
        id: notifId,
        title: 'طلب الانضمام',
        body: 'نعتذر، لم يتم قبول طلبك لمجموعة "$groupName" حالياً.',
        type: NotificationTypes.requestRejected,
        refId: groupId,
        createdAt: DateTime.now(),
        isRead: false,
      );

      final notifRef = firestore
          .collection(FirestorePaths.userNotifications(userId))
          .doc(notifId);
      batch.set(notifRef, notification.toMap());

      await batch.commit();

      await Future.delayed(const Duration(milliseconds: 150));

      notifyListeners();
    } catch (e) {
      debugPrint("Error rejecting request: $e");
      rethrow;
    }
  }

  Stream<List<MemberModel>> streamJoinRequests({required String groupId}) {
    return _firestore
        .streamCollection(path: FirestorePaths.groupJoinRequests(groupId))
        .asyncMap((snapshot) async {
      List<MemberModel> members = [];
      for (var doc in snapshot.docs) {
        var member = MemberModel.fromMap(doc.data());
       
        if (member.realUserName != null && member.realUserImageUrl != null) {
          members.add(member);
          continue;
        }

        try {
          final userData = await FirebaseFirestore.instance
              .collection('Users')
              .doc(member.userId.trim())
              .get();
         
          if (userData.exists && userData.data() != null) {
            final user = UserModel.fromMap(userData.data()!, userData.id);
           
            member = member.copyWith(
              realUserName: user.username,
              realUserImageUrl: user.avatarUrl,
            );
          }
        } catch (e) {
          debugPrint("Error fetching real user data for request ${member.userId}: $e");
        }
        members.add(member);
      }
      return members;
    });
  }

  // =========================================================
  // MEMBERS MANAGEMENT
  // =========================================================

  Future<void> addMember({
    required MemberModel member,
    String? adminId,
  }) async {
    try {
      if (adminId != null) {
        final adminData = await _firestore.getDocument(
          path: FirestorePaths.groupMembers(member.groupId),
          docId: adminId,
        );
       
        if (adminData == null) throw "خطأ: لم يتم العثور على بيانات المسؤول.";
        final adminMember = MemberModel.fromMap(adminData);

        final currentTargetData = await _firestore.getDocument(
          path: FirestorePaths.groupMembers(member.groupId),
          docId: member.userId,
        );

        if (currentTargetData != null) {
          final currentTargetMember = MemberModel.fromMap(currentTargetData);
         
          if (!RoleAssignmentLogic.canModify(
            actorRole: adminMember.role,
            targetRole: currentTargetMember.role,
            actorId: adminId,
            targetId: member.userId,
          )) {
            throw "لا تملك الصلاحية الكافية لتعديل رتبة هذا العضو.";
          }
        }
      }

      final updatedMember = member.copyWith(isManualRole: true);

      await _firestore.createDocument(
        path: FirestorePaths.groupMembers(updatedMember.groupId),
        docId: updatedMember.userId,
        data: updatedMember.toMap(),
      );
     
      await InviteRankingLogic.refreshRanks(groupId: updatedMember.groupId);
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Error adding/updating member: $e");
      rethrow;
    }
  }

  Future<void> removeMember({
    required String groupId,
    required String userId,
    String? adminId,
  }) async {
    try {
      if (adminId != null) {
        final targetData = await _firestore.getDocument(
          path: FirestorePaths.groupMembers(groupId),
          docId: userId,
        );
       
        if (targetData != null) {
          final targetMember = MemberModel.fromMap(targetData);
          final adminData = await _firestore.getDocument(
            path: FirestorePaths.groupMembers(groupId),
            docId: adminId,
          );
         
          if (adminData == null) throw "خطأ في الصلاحيات.";
          final adminMember = MemberModel.fromMap(adminData);

          if (!RoleAssignmentLogic.canModify(
            actorRole: adminMember.role,
            targetRole: targetMember.role
          )) {
            throw "لا تملك الصلاحية لطرد هذا العضو.";
          }
        }
      }

      await _firestore.deleteDocument(
        path: FirestorePaths.groupMembers(groupId),
        docId: userId,
      );

      await InviteRankingLogic.refreshRanks(groupId: groupId);
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Error removing member: $e");
      rethrow;
    }
  }

  // ✅ الميزة الأولى: الخروج من المجموعة للمنتسبين
  Future<void> leaveGroup({
    required String groupId,
    required String userId,
    String? characterName,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      // 1. حذف العضو من القائمة
      final memberRef = firestore
          .collection(FirestorePaths.groupMembers(groupId))
          .doc(userId);
      batch.delete(memberRef);

      // 2. تقليل عدد الأعضاء
      final groupRef = firestore.collection(FirestorePaths.groups).doc(groupId);
      batch.update(groupRef, {'membersCount': FieldValue.increment(-1)});

      // 3. حذف حجز الشخصية إن وجد
      if (characterName != null) {
        final charKey = characterName.toLowerCase().replaceAll(RegExp(r'\s+'), '');
        final charRef = firestore
            .collection(FirestorePaths.groupCharacters(groupId))
            .doc(charKey);
        batch.delete(charRef);
      }

      await batch.commit();
      
      // تحديث الرتب للبقية
      await InviteRankingLogic.refreshRanks(groupId: groupId);
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Error leaving group: $e");
      rethrow;
    }
  }

  Future<List<MemberModel>> getMembers({required String groupId}) async {
    final snapshot = await _firestore.getCollection(path: FirestorePaths.groupMembers(groupId));
    return snapshot.docs.map((doc) => MemberModel.fromMap(doc.data())).toList();
  }

  // =========================================================
  // CREATE, UPDATE, DELETE GROUP
  // =========================================================

  Future<void> createGroup({
    required GroupModel group,
    required MemberModel founderMember,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
     
      final founder = RoleAssignmentLogic.createFounder(member: founderMember).copyWith(isManualRole: true);

      final groupRef = firestore.collection(FirestorePaths.groups).doc(group.id);
      batch.set(groupRef, group.toMap());

      final memberRef = firestore
          .collection(FirestorePaths.groupMembers(group.id))
          .doc(founder.userId);
      batch.set(memberRef, founder.toMap());

      if (founder.characterName != null) {
        final charKey = founder.characterName!.toLowerCase().replaceAll(RegExp(r'\s+'), '');
        final charRef = firestore
            .collection(FirestorePaths.groupCharacters(group.id))
            .doc(charKey);
       
        batch.set(charRef, {
          'userId': founder.userId,
          'characterName': founder.characterName,
          'imageUrl': founder.characterImageUrl,
          'reservedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Error creating group: $e");
      rethrow;
    }
  }

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

  // ✅ الميزة الثانية والثالثة: تفكيك المجموعة مع رسالة وداع
  Future<void> disbandGroup({
    required String groupId,
    required String groupName,
    String? farewellMessage,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // 1. جلب جميع الأعضاء لإرسال الإشعارات لهم
      final membersSnapshot = await firestore
          .collection(FirestorePaths.groupMembers(groupId))
          .get();
      
      final batch = firestore.batch();

      // 2. إرسال إشعار تفكيك لكل عضو
      for (var doc in membersSnapshot.docs) {
        final memberId = doc.id;
        final notifId = firestore.collection(FirestorePaths.userNotifications(memberId)).doc().id;
        
        final notification = NotificationModel(
          id: notifId,
          title: 'تم تفكيك مجموعة "$groupName" 🚩',
          body: farewellMessage != null && farewellMessage.isNotEmpty 
              ? 'رسالة المؤسس: $farewellMessage'
              : 'قام المؤسس بحذف المجموعة نهائياً.',
          type: NotificationTypes.groupDisbanded,
          refId: null, // لا يوجد مرجع لأن المجموعة حذفت
          createdAt: DateTime.now(),
          isRead: false,
        );

        final notifRef = firestore
            .collection(FirestorePaths.userNotifications(memberId))
            .doc(notifId);
        batch.set(notifRef, notification.toMap());
        
        // حذف وثيقة العضو
        batch.delete(doc.reference);
      }

      // 3. حذف وثيقة المجموعة نفسها
      final groupRef = firestore.collection(FirestorePaths.groups).doc(groupId);
      batch.delete(groupRef);

      // 4. تنفيذ العمليات
      await batch.commit();
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Error disbanding group: $e");
      rethrow;
    }
  }

  // تم استبدال deleteGroup بـ disbandGroup لإدارة الحذف النظيف
  Future<void> deleteGroup({required String groupId}) async {
    final group = await getGroup(groupId: groupId);
    if (group != null) {
      await disbandGroup(groupId: groupId, groupName: group.name);
    }
  }

  // =========================================================
  // GETTERS & STREAMS
  // =========================================================

  Future<GroupModel?> getGroup({required String groupId}) async {
    final data = await _firestore.getDocument(
      path: FirestorePaths.groups,
      docId: groupId,
    );
    if (data == null) return null;
    return GroupModel.fromMap(groupId, data);
  }

  Stream<GroupModel?> streamGroup({required String groupId}) {
    if (groupId.isEmpty) return Stream.value(null);

    return _firestore
        .streamDocument(path: FirestorePaths.groups, docId: groupId)
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return GroupModel.fromMap(snapshot.id, snapshot.data()!);
    }).handleError((error) {
      debugPrint("❌ Error in streamGroup: $error");
      return null;
    });
  }

  Stream<List<MemberModel>> streamMembers({required String groupId}) {
    return _firestore
        .streamCollection(path: FirestorePaths.groupMembers(groupId))
        .map((snapshot) {
      return snapshot.docs.map((doc) => MemberModel.fromMap(doc.data())).toList();
    });
  }

  // =========================================================
  // INVITE & CHARACTER LOGIC
  // =========================================================

  Future<void> createInvite({required InviteModel invite}) async {
    await _firestore.createDocument(
      path: FirestorePaths.groupInvites(invite.groupId),
      docId: invite.inviteId,
      data: invite.toMap(),
    );
  }

  Future<void> reserveCharacter({
    required String groupId,
    required String characterName,
    required String imageUrl,
    required String userId,
  }) async {
    try {
      final charKey = characterName.toLowerCase().replaceAll(RegExp(r'\s+'), '');
      await _firestore.createDocument(
        path: FirestorePaths.groupCharacters(groupId),
        docId: charKey,
        data: {
          'userId': userId,
          'characterName': characterName.trim(),
          'imageUrl': imageUrl,
          'reservedAt': FieldValue.serverTimestamp(),
        },
      );
    } catch (e) {
      debugPrint("❌ Error reserving character: $e");
      rethrow;
    }
  }

  Future<bool> isCharacterReserved({
    required String groupId,
    required String characterName,
  }) async {
    try {
      final charKey = characterName.toLowerCase().replaceAll(RegExp(r'\s+'), '');
      final doc = await _firestore.getDocument(
        path: FirestorePaths.groupCharacters(groupId),
        docId: charKey,
      );
      return doc != null;
    } catch (e) {
      debugPrint("❌ Error checking reservation: $e");
      return false;
    }
  }

  // =========================================================
  // USER GROUPS
  // =========================================================

  Future<List<GroupModel>> getUserGroups({required String userId}) async {
    try {
      final groupsSnapshot = await _firestore.getCollection(path: FirestorePaths.groups);
      final List<GroupModel> userGroups = [];

      for (final doc in groupsSnapshot.docs) {
        final memberDoc = await _firestore.getDocument(
          path: FirestorePaths.groupMembers(doc.id),
          docId: userId,
        );

        if (memberDoc != null) {
          userGroups.add(GroupModel.fromMap(doc.id, doc.data()));
        }
      }
      return userGroups;
    } catch (e) {
      debugPrint("❌ Error fetching user groups: $e");
      return [];
    }
  }
}