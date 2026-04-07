// lib/providers/group_provider.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/group_model.dart';
import '../models/member_model.dart';
import '../models/invite_model.dart';
import '../models/notification_model.dart'; 

import '../services/firebase/firestore_service.dart';
import '../core/constants/firestore_paths.dart';
import '../core/logic/role_assignment_logic.dart';
import '../core/logic/invite_ranking_logic.dart'; // ✅ مستخدم الآن للتحديث التلقائي
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

  /// ✅ الدالة الجديدة لإرسال طلب الانضمام (انتظار موافقة الشوغو)
  Future<void> sendJoinRequest({
    required String groupId,
    required MemberModel memberRequest,
  }) async {
    try {
      // إرسال الطلب إلى كولكشن طلبات الانضمام وليس الأعضاء مباشرة
      await _firestore.createDocument(
        path: FirestorePaths.groupJoinRequests(groupId),
        docId: memberRequest.userId,
        data: memberRequest.toMap(),
      );
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Error sending join request: $e");
      rethrow;
    }
  }

  Future<void> acceptJoinRequest({
    required String groupId,
    required String groupName, 
    required MemberModel requestMember,
  }) async {
    try {
      // التحقق من حجز الشخصية أولاً (للتقمص)
      if (requestMember.characterName != null) {
        final isTaken = await isCharacterReserved(
          groupId: groupId, 
          characterName: requestMember.characterName!
        );
        if (isTaken) {
          throw "للأسف، تم حجز هذه الشخصية من قبل عضو آخر قبل لحظات.";
        }
      }

      final firestore = FirebaseFirestore.instance;

      await _firestore.runBatch((batch) async {
        // 1. إضافة العضو الجديد للمجموعة
        final memberRef = firestore
            .collection(FirestorePaths.groupMembers(groupId))
            .doc(requestMember.userId);
        batch.set(memberRef, requestMember.toMap());

        // 2. حذف طلب الانضمام
        final requestRef = firestore
            .collection(FirestorePaths.groupJoinRequests(groupId))
            .doc(requestMember.userId);
        batch.delete(requestRef);

        // 3. تحديث عدد أعضاء المجموعة
        final groupRef = firestore
            .collection(FirestorePaths.groups)
            .doc(groupId);
        batch.update(groupRef, {'membersCount': FieldValue.increment(1)});
       
        // 4. حجز الشخصية رسمياً إذا كانت مجموعة تقمص
        if (requestMember.characterName != null) {
           final charRef = firestore
            .collection(FirestorePaths.groupCharacters(groupId))
            .doc(requestMember.characterName!.toLowerCase());
           batch.set(charRef, {
            'userId': requestMember.userId,
            'characterName': requestMember.characterName,
            'imageUrl': requestMember.characterImageUrl,
            'reservedAt': FieldValue.serverTimestamp(),
          });
        }

        // 5. إرسال إشعار القبول
        final notifId = firestore.collection(FirestorePaths.userNotifications(requestMember.userId)).doc().id;
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
            .collection(FirestorePaths.userNotifications(requestMember.userId))
            .doc(notifId);
        batch.set(notifRef, notification.toMap());
      });
      
      // ✅ الأهم: تحديث نظام الرتب التلقائي فور القبول
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
      await _firestore.runBatch((batch) async {
        final firestore = FirebaseFirestore.instance;

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
      });
      notifyListeners();
    } catch (e) {
      debugPrint("Error rejecting request: $e");
      rethrow;
    }
  }

  Stream<List<MemberModel>> streamJoinRequests({required String groupId}) {
    return _firestore
        .streamCollection(path: FirestorePaths.groupJoinRequests(groupId))
        .map((snapshot) {
      return snapshot.docs.map((doc) => MemberModel.fromMap(doc.data())).toList();
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
        
        if (!RoleAssignmentLogic.canModify(
          actorRole: adminMember.role, 
          targetRole: member.role
        )) {
          throw "لا تملك الصلاحية الكافية لتنفيذ هذا الإجراء.";
        }
      }

      await _firestore.createDocument(
        path: FirestorePaths.groupMembers(member.groupId),
        docId: member.userId,
        data: member.toMap(),
      );
      
      // ✅ تحديث الرتب عند إضافة عضو يدوياً أيضاً
      await InviteRankingLogic.refreshRanks(groupId: member.groupId);
      
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Error adding member: $e");
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

      // ✅ إعادة حساب الرتب لأن رحيل العضو قد يغير ترتيب الدعوات
      await InviteRankingLogic.refreshRanks(groupId: groupId);

      notifyListeners();
    } catch (e) {
      debugPrint("❌ Error removing member: $e");
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
      final founder = RoleAssignmentLogic.createFounder(member: founderMember);

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

  Future<void> deleteGroup({required String groupId}) async {
    await _firestore.deleteDocument(
      path: FirestorePaths.groups,
      docId: groupId,
    );
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
      await _firestore.createDocument(
        path: FirestorePaths.groupCharacters(groupId),
        docId: characterName.toLowerCase().trim(),
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
      final doc = await _firestore.getDocument(
        path: FirestorePaths.groupCharacters(groupId),
        docId: characterName.toLowerCase().trim(),
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