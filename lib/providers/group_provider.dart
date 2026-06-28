// lib/providers/group_provider.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:rxdart/rxdart.dart';

import '../models/group_model.dart';
import '../models/member_model.dart';
import '../models/invite_model.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';

import '../services/firebase/firestore_service.dart';
import '../core/constants/firestore_paths.dart';
import '../core/logic/role_assignment_logic.dart';
import '../core/logic/invite_ranking_logic.dart';
import '../core/logic/system_message_builder.dart';
import 'package:pubget/services/monetization/promotion_service.dart';
import 'package:pubget/core/constants/roles.dart';
import 'package:pubget/providers/store_provider.dart';
import 'package:pubget/providers/chat_provider.dart';

class GroupProvider extends ChangeNotifier {
  final FirestoreService _firestore;

  GroupProvider({
    required FirestoreService firestoreService,
  }) : _firestore = firestoreService;

  // =========================================================
  static String _normalizeCharacterKey(String characterName) {
    final words = characterName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .trim()
        .split(RegExp(r'\s+'));
    words.sort();
    return words.join('');
  }

  // =========================================================
  Future<void> promoteGroup({
    required String groupId,
    required String userId,
    required StoreProvider storeProvider,
  }) async {
    final purchased = await storeProvider.purchaseGroupPromotion();
    if (!purchased) {
      throw "رصيدك غير كافٍ. تحتاج إلى 150 عملة لترويج المجموعة.";
    }
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
  Future<void> sendJoinRequest({
    required String groupId,
    required String groupName,
    required String founderId,
    required MemberModel memberRequest,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;

      final memberCheck = await firestore
          .collection(FirestorePaths.groupMembers(groupId))
          .doc(memberRequest.userId)
          .get();
      if (memberCheck.exists) return;
      if (memberRequest.userId == founderId) return;

      final batch = firestore.batch();

      final requestRef = firestore
          .collection(FirestorePaths.groupJoinRequests(groupId))
          .doc(memberRequest.userId);
      batch.set(requestRef, memberRequest.toMap());

      final notifId = firestore
          .collection(FirestorePaths.userNotifications(founderId))
          .doc()
          .id;
      final notification = NotificationModel(
        id: notifId,
        title: 'طلب انضمام جديد 📥',
        body:
            'قدم ${memberRequest.realUserName} طلباً للانضمام إلى مجموعة "$groupName"',
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

  // =========================================================
  // ✅ تعديل: تمرير country للبطاقة الترحيبية الفاخرة
  // =========================================================
  Future<void> acceptJoinRequest({
    required String groupId,
    required String groupName,
    required MemberModel requestMember,
    ChatProvider? chatProvider,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;

      final userDoc = await firestore
          .collection('users')
          .doc(requestMember.userId)
          .get();
      bool currentPremiumStatus = false;
      String? freshAvatar;
      String? freshUsername;
      String? freshCountry;

      if (userDoc.exists) {
        final userData = userDoc.data();
        final user = UserModel.fromMap(userData!, userDoc.id);
        currentPremiumStatus = user.isPremium;
        freshAvatar = user.avatarUrl;
        freshUsername = user.username;
        freshCountry = user.country;
      }

      if (requestMember.characterName != null) {
        final isTaken = await isCharacterReserved(
            groupId: groupId,
            characterName: requestMember.characterName!);
        if (isTaken) {
          throw "للأسف، تم حجز هذه الشخصية من قبل عضو آخر قبل لحظات.";
        }
      }

      String? validatedInviterId = requestMember.invitedByUserId;
      if (validatedInviterId == requestMember.userId) {
        validatedInviterId = null;
      }

      final existingMemberDoc = await firestore
          .collection(FirestorePaths.groupMembers(groupId))
          .doc(requestMember.userId)
          .get();

      String finalRole = requestMember.role.name;
      bool finalIsManual = false;

      if (existingMemberDoc.exists) {
        final data = existingMemberDoc.data()!;
        finalRole = data['role'] ?? 'member';
        finalIsManual = data['isManualRole'] ?? false;
        if (finalRole == 'founder' || finalRole == 'shogun') {
          final requestRef = firestore
              .collection(FirestorePaths.groupJoinRequests(groupId))
              .doc(requestMember.userId);
          await requestRef.delete();
          return;
        }
      }

      final groupDoc = await firestore
          .collection(FirestorePaths.groups)
          .doc(groupId)
          .get();
      final groupData = groupDoc.data();
      final bool isRoleplay = groupData?['isRoleplay'] ?? false;
      final String groupType = groupData?['groupType'] ?? 'general';

      final batch = firestore.batch();

      final newMember = requestMember.copyWith(
        role: Roles.fromString(finalRole),
        isManualRole: finalIsManual,
        isPremium: currentPremiumStatus,
        realUserName: freshUsername,
        realUserImageUrl: freshAvatar,
        invitedByUserId: validatedInviterId,
      );

      final memberRef = firestore
          .collection(FirestorePaths.groupMembers(groupId))
          .doc(newMember.userId);
      batch.set(memberRef, newMember.toMap());

      final requestRef = firestore
          .collection(FirestorePaths.groupJoinRequests(groupId))
          .doc(newMember.userId);
      batch.delete(requestRef);

      final groupRef =
          firestore.collection(FirestorePaths.groups).doc(groupId);
      if (!existingMemberDoc.exists) {
        batch.update(groupRef, {'membersCount': FieldValue.increment(1)});
      }

      if (newMember.characterName != null) {
        final charKey = _normalizeCharacterKey(newMember.characterName!);
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

      final notifId = firestore
          .collection(FirestorePaths.userNotifications(newMember.userId))
          .doc()
          .id;
      final notification = NotificationModel(
        id: notifId,
        title: 'تم قبولك! 🎉',
        body:
            'وافق الشوغو على طلب انضمامك لمجموعة "$groupName". يمكنك الدردشة الآن!',
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

      if (chatProvider != null) {
        final welcomeText = SystemMessageBuilder.buildText(
          eventType: 'join',
          memberName: freshUsername ?? newMember.effectiveName,
          characterName: newMember.characterName,
          roleName: finalRole,
          country: freshCountry,
          isRoleplay: isRoleplay,
          groupType: groupType,
        );
        await chatProvider.sendSystemMessage(
          groupId: groupId,
          systemEventType: 'join',
          text: welcomeText,
        );
      }

      await Future.delayed(const Duration(milliseconds: 500));
      await InviteRankingLogic.refreshRanks(groupId: groupId);

      notifyListeners();
    } catch (e) {
      debugPrint("Error accepting request: $e");
      rethrow;
    }
  }

  // =========================================================
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

      final notifId = firestore
          .collection(FirestorePaths.userNotifications(userId))
          .doc()
          .id;
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
        try {
          final userData = await FirebaseFirestore.instance
              .collection('users')
              .doc(member.userId.trim())
              .get();
          if (userData.exists && userData.data() != null) {
            final user = UserModel.fromMap(userData.data()!, userData.id);
            member = member.copyWith(
              realUserName: user.username,
              realUserImageUrl: user.avatarUrl,
              isPremium: user.isPremium,
            );
          }
        } catch (e) {
          debugPrint(
              "Error fetching real user data for request ${member.userId}: $e");
        }
        members.add(member);
      }
      members.sort((a, b) {
        if (a.isPremium && !b.isPremium) return -1;
        if (!a.isPremium && b.isPremium) return 1;
        return b.joinedAt.compareTo(a.joinedAt);
      });
      return members;
    });
  }

  // =========================================================
  Future<void> addMember({
    required MemberModel member,
    String? adminId,
    ChatProvider? chatProvider,
  }) async {
    try {
      Roles? oldRoleEnum;

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
          oldRoleEnum = currentTargetMember.role;

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

      final bool shouldBeManual = member.role != Roles.member;
      final updatedMember = member.copyWith(isManualRole: shouldBeManual);

      await _firestore.createDocument(
        path: FirestorePaths.groupMembers(updatedMember.groupId),
        docId: updatedMember.userId,
        data: updatedMember.toMap(),
      );

      if (chatProvider != null &&
          oldRoleEnum != null &&
          oldRoleEnum != member.role) {
        final groupDoc = await FirebaseFirestore.instance
            .collection(FirestorePaths.groups)
            .doc(updatedMember.groupId)
            .get();
        final groupData = groupDoc.data();
        final bool isRoleplay = groupData?['isRoleplay'] ?? false;
        final String groupType = groupData?['groupType'] ?? 'general';

        final roleText = SystemMessageBuilder.buildText(
          eventType: 'roleAssign',
          memberName: updatedMember.effectiveName,
          characterName: updatedMember.characterName,
          roleName: member.role.name,
          oldRoleLevel: oldRoleEnum.rankLevel,
          newRoleLevel: member.role.rankLevel,
          isRoleplay: isRoleplay,
          groupType: groupType,
        );
        await chatProvider.sendSystemMessage(
          groupId: updatedMember.groupId,
          systemEventType: 'roleAssign',
          text: roleText,
        );
      }

      await InviteRankingLogic.refreshRanks(groupId: updatedMember.groupId);
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Error adding/updating member: $e");
      rethrow;
    }
  }

  // =========================================================
  // ✅✅✅ تعديل جوهري: حل مشكلة "الشخصية تبقى مقفولة للأبد بعد الطرد"
  //
  // السبب الجذري السابق (خطآن مجتمعان):
  //  1. كانت تستخدم characterNameToRelease كـ docId مباشرة بدون أي تطبيع،
  //     بينما الوثيقة الفعلية محفوظة بمفتاح مُطبَّع عبر _normalizeCharacterKey
  //     (الكلمات أبجدياً، بدون رموز/مسافات) — فالمسار كان خاطئاً تماماً
  //     ولم يكن يصل أبداً للوثيقة الصحيحة.
  //  2. كانت تستخدم .update({'takenBy': null}) بينما حقل الحجز الحقيقي
  //     اسمه 'userId' (راجع reserveCharacter / acceptJoinRequest) — فالوثيقة
  //     كانت تبقى موجودة بالكامل، و isCharacterReserved تفحص فقط "هل الوثيقة
  //     موجودة؟" فتستمر بإرجاع true للأبد.
  //
  // الحل: استخدام نفس منطق leaveGroup بالضبط — حساب المفتاح المُطبَّع،
  // وحذف الوثيقة بالكامل (delete) بدل تحديث حقل غير موجود.
  // =========================================================
  Future<void> removeMember({
    required String groupId,
    required String userId,
    String? adminId,
    ChatProvider? chatProvider,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      String? characterNameToRelease;
      String? kickedMemberName;

      final memberRef = firestore
          .collection(FirestorePaths.groupMembers(groupId))
          .doc(userId);

      final targetData = await memberRef.get();

      if (targetData.exists && targetData.data() != null) {
        final targetMember = MemberModel.fromMap(targetData.data()!);
        characterNameToRelease = targetMember.characterName;
        kickedMemberName = targetMember.effectiveName;
      }

      await memberRef.delete();

      // ✅✅✅ التصحيح الجوهري هنا
      if (characterNameToRelease != null &&
          characterNameToRelease.isNotEmpty) {
        final charKey = _normalizeCharacterKey(characterNameToRelease);
        final charRef = firestore
            .collection(FirestorePaths.groupCharacters(groupId))
            .doc(charKey);
        await charRef.delete();
        debugPrint(
            "♻️ Released character via Kick (fixed): $characterNameToRelease");
      }

      if (chatProvider != null && kickedMemberName != null) {
        final groupDoc = await firestore
            .collection(FirestorePaths.groups)
            .doc(groupId)
            .get();
        final groupData = groupDoc.data();
        final bool isRoleplay = groupData?['isRoleplay'] ?? false;
        final String groupType = groupData?['groupType'] ?? 'general';

        final kickText = SystemMessageBuilder.buildText(
          eventType: 'kick',
          memberName: kickedMemberName,
          characterName: characterNameToRelease,
          roleName: null,
          isRoleplay: isRoleplay,
          groupType: groupType,
        );

        await chatProvider.sendSystemMessage(
          groupId: groupId,
          systemEventType: 'kick',
          text: kickText,
        );
      }

      await InviteRankingLogic.refreshRanks(groupId: groupId);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error removing member: $e');
      rethrow;
    }
  }

  // =========================================================
  Future<void> leaveGroup({
    required String groupId,
    required String userId,
    String? characterName,
    String? memberName,
    ChatProvider? chatProvider,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      String? finalCharacterName = characterName;
      String? finalMemberName = memberName;

      if (finalCharacterName == null ||
          finalCharacterName.isEmpty ||
          finalMemberName == null) {
        final memberDoc = await firestore
            .collection(FirestorePaths.groupMembers(groupId))
            .doc(userId)
            .get();
        if (memberDoc.exists && memberDoc.data() != null) {
          final member = MemberModel.fromMap(memberDoc.data()!);
          finalCharacterName ??= member.characterName;
          finalMemberName ??= member.effectiveName;
        }
      }

      final batch = firestore.batch();

      final memberRef = firestore
          .collection(FirestorePaths.groupMembers(groupId))
          .doc(userId);
      batch.delete(memberRef);

      final groupRef =
          firestore.collection(FirestorePaths.groups).doc(groupId);
      batch.update(groupRef, {'membersCount': FieldValue.increment(-1)});

      if (finalCharacterName != null && finalCharacterName.isNotEmpty) {
        final charKey = _normalizeCharacterKey(finalCharacterName);
        final charRef = firestore
            .collection(FirestorePaths.groupCharacters(groupId))
            .doc(charKey);
        batch.delete(charRef);
        debugPrint("♻️ Released character via Leave: $finalCharacterName");
      }

      await batch.commit();

      if (chatProvider != null) {
        final groupDoc = await firestore
            .collection(FirestorePaths.groups)
            .doc(groupId)
            .get();
        final groupData = groupDoc.data();
        final bool isRoleplay = groupData?['isRoleplay'] ?? false;
        final String groupType = groupData?['groupType'] ?? 'general';

        final leaveText = SystemMessageBuilder.buildText(
          eventType: 'leave',
          memberName: finalMemberName ?? 'عضو',
          characterName: finalCharacterName,
          roleName: null,
          isRoleplay: isRoleplay,
          groupType: groupType,
        );
        await chatProvider.sendSystemMessage(
          groupId: groupId,
          systemEventType: 'leave',
          text: leaveText,
        );
      }

      await InviteRankingLogic.refreshRanks(groupId: groupId);
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Error leaving group: $e");
      rethrow;
    }
  }

  Future<List<MemberModel>> getMembers({required String groupId}) async {
    final snapshot = await _firestore.getCollection(
        path: FirestorePaths.groupMembers(groupId));
    return snapshot.docs
        .map((doc) => MemberModel.fromMap(doc.data()))
        .toList();
  }

  // =========================================================
  Future<void> createGroup({
    required GroupModel group,
    required MemberModel founderMember,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      final founder =
          RoleAssignmentLogic.createFounder(member: founderMember)
              .copyWith(isManualRole: true);

      final groupRef =
          firestore.collection(FirestorePaths.groups).doc(group.id);

      final groupWithTimestamp = group.copyWith(
        lastMessageAt: group.createdAt,
        lastMessageText: group.description.isNotEmpty
            ? group.description
            : 'تم إنشاء المجموعة',
      );

      batch.set(groupRef, groupWithTimestamp.toMap());

      final memberRef = firestore
          .collection(FirestorePaths.groupMembers(group.id))
          .doc(founder.userId);
      batch.set(memberRef, founder.toMap());

      if (founder.characterName != null) {
        final charKey = _normalizeCharacterKey(founder.characterName!);
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

  // =========================================================
  Future<void> updateGroup({
    required String groupId,
    required Map<String, dynamic> data,
    ChatProvider? chatProvider,
    String? editorName,
    Map<String, dynamic>? changedFields,
  }) async {
    await _firestore.updateDocument(
      path: FirestorePaths.groups,
      docId: groupId,
      data: data,
    );

    if (chatProvider != null &&
        changedFields != null &&
        changedFields.isNotEmpty) {
      for (final entry in changedFields.entries) {
        final editText = SystemMessageBuilder.buildText(
          eventType: 'edit',
          memberName: '',
          editorName: editorName ?? 'المؤسس',
          fieldName: entry.key,
          newValue: entry.value?.toString(),
          isRoleplay: false,
          groupType: 'general',
        );
        await chatProvider.sendSystemMessage(
          groupId: groupId,
          systemEventType: 'edit',
          text: editText,
        );
      }
    }

    notifyListeners();
  }

  Future<void> disbandGroup({
    required String groupId,
    required String groupName,
    String? farewellMessage,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;

      final membersSnapshot = await firestore
          .collection(FirestorePaths.groupMembers(groupId))
          .get();

      final batch = firestore.batch();

      for (var doc in membersSnapshot.docs) {
        final memberId = doc.id;
        final notifId = firestore
            .collection(FirestorePaths.userNotifications(memberId))
            .doc()
            .id;

        final notification = NotificationModel(
          id: notifId,
          title: 'تم تفكيك مجموعة "$groupName" 🚩',
          body: farewellMessage != null && farewellMessage.isNotEmpty
              ? 'رسالة المؤسس: $farewellMessage'
              : 'قام المؤسس بحذف المجموعة نهائياً.',
          type: NotificationTypes.groupDisbanded,
          refId: null,
          createdAt: DateTime.now(),
          isRead: false,
        );

        final notifRef = firestore
            .collection(FirestorePaths.userNotifications(memberId))
            .doc(notifId);
        batch.set(notifRef, notification.toMap());
        batch.delete(doc.reference);
      }

      final groupRef =
          firestore.collection(FirestorePaths.groups).doc(groupId);
      batch.delete(groupRef);

      await batch.commit();
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Error disbanding group: $e");
      rethrow;
    }
  }

  Future<void> deleteGroup({required String groupId}) async {
    final group = await getGroup(groupId: groupId);
    if (group != null) {
      await disbandGroup(groupId: groupId, groupName: group.name);
    }
  }

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
        .switchMap((snapshot) {
      if (snapshot.docs.isEmpty) return Stream.value(<MemberModel>[]);

      final memberStreams = snapshot.docs.map((doc) {
        final member = MemberModel.fromMap(doc.data());

        return FirebaseFirestore.instance
            .collection('users')
            .doc(member.userId.trim())
            .snapshots()
            .map((userDoc) {
          if (userDoc.exists && userDoc.data() != null) {
            final user = UserModel.fromMap(userDoc.data()!, userDoc.id);
            return member.copyWith(
              realUserName: user.username,
              realUserImageUrl: user.avatarUrl,
              isPremium: user.isPremium,
            );
          }
          return member;
        });
      }).toList();

      return Rx.combineLatestList(memberStreams);
    });
  }

  // =========================================================
  Future<void> createInvite({required InviteModel invite}) async {
    await _firestore.createDocument(
      path: FirestorePaths.groupInvites(invite.groupId),
      docId: invite.inviteId,
      data: invite.toMap(),
    );
  }

  Future<bool> isCharacterReserved({
    required String groupId,
    required String characterName,
  }) async {
    final charKey = _normalizeCharacterKey(characterName);
    final doc = await _firestore.getDocument(
      path: FirestorePaths.groupCharacters(groupId),
      docId: charKey,
    );
    return doc != null;
  }

  Future<void> reserveCharacter({
    required String groupId,
    required String characterName,
    required String imageUrl,
    required String userId,
  }) async {
    try {
      final charKey = _normalizeCharacterKey(characterName);
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
    }
  }

  // =========================================================
  Future<List<GroupModel>> getUserGroups({required String userId}) async {
    try {
      final groupsSnapshot =
          await _firestore.getCollection(path: FirestorePaths.groups);
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

  // =========================================================
  Stream<List<GroupModel>> streamUserGroups({required String userId}) {
    final foundedQuery = _firestore.buildQuery(
      path: FirestorePaths.groups,
      conditions: [QueryCondition(field: 'founderId', isEqualTo: userId)],
    );
    final foundedStream =
        _firestore.streamCollection(path: FirestorePaths.groups, query: foundedQuery);

    final memberDocsStream = _firestore.streamCollectionGroup(
      collectionId: 'members',
      field: 'userId',
      isEqualTo: userId,
    );

    final joinedGroupsStream = memberDocsStream.switchMap((memberSnap) {
      final groupIds = memberSnap.docs
          .map((doc) => doc.reference.parent.parent?.id)
          .whereType<String>()
          .toSet()
          .toList();

      if (groupIds.isEmpty) return Stream.value(<GroupModel>[]);

      final groupStreams = groupIds.map((gId) {
        return _firestore
            .streamDocument(path: FirestorePaths.groups, docId: gId)
            .map((snap) {
          if (!snap.exists || snap.data() == null) return null;
          return GroupModel.fromMap(snap.id, snap.data()!);
        });
      }).toList();

      return Rx.combineLatestList(groupStreams).map(
        (groups) => groups.whereType<GroupModel>().toList(),
      );
    });

    return Rx.combineLatest2<QuerySnapshot<Map<String, dynamic>>,
        List<GroupModel>, List<GroupModel>>(
      foundedStream,
      joinedGroupsStream,
      (foundedSnap, joinedGroups) {
        final founded = foundedSnap.docs
            .map((doc) => GroupModel.fromMap(doc.id, doc.data()))
            .toList();

        final foundedIds = founded.map((g) => g.id).toSet();
        final joined =
            joinedGroups.where((g) => !foundedIds.contains(g.id)).toList();

        final all = [...founded, ...joined];

        all.sort((a, b) {
          final aTime = a.lastMessageAt ?? a.createdAt;
          final bTime = b.lastMessageAt ?? b.createdAt;
          return bTime.compareTo(aTime);
        });

        return all;
      },
    ).handleError((error) {
      debugPrint("❌ Error in streamUserGroups: $error");
      return <GroupModel>[];
    });
  }

  List<GroupModel> filterFounded(List<GroupModel> all, String userId) =>
      all.where((g) => g.founderId == userId).toList();

  List<GroupModel> filterJoined(List<GroupModel> all, String userId) =>
      all.where((g) => g.founderId != userId).toList();
}