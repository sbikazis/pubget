// lib/core/logic/invite_ranking_logic.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/member_model.dart';
import '../constants/roles.dart';
import '../constants/firestore_paths.dart';

class InviteRankingLogic {
  InviteRankingLogic._();

  /// ✅ الدالة الرئيسية: تجلب البيانات من Firestore وتحدث الرتب تلقائياً
  static Future<void> refreshRanks({required String groupId}) async {
    final firestore = FirebaseFirestore.instance;
    
    final membersSnapshot = await firestore
        .collection(FirestorePaths.groupMembers(groupId))
        .get();
    
    final allMembers = membersSnapshot.docs
        .map((doc) => MemberModel.fromMap(doc.data()))
        .toList();

    // حساب الدعوات مع حماية من الذاتي والفارغ
    final Map<String, int> inviteCounts = {};
    for (var m in allMembers) {
      final inviter = m.invitedByUserId;
      if (inviter != null && inviter.isNotEmpty && inviter != m.userId) {
        inviteCounts.update(inviter, (v) => v + 1, ifAbsent: () => 1);
      }
    }

    // المقاعد التلقائية المتاحة (ثابتة حسب النظام)
    int availableSensei = Roles.sensei.autoMaxCount ?? 0; // =1
    int availableHakusho = Roles.hakusho.autoMaxCount ?? 0; // =1
    int availableSenpai = Roles.senpai.autoMaxCount ?? 0; // =2

    // المرشحون: كل من ليس يدوي وليس مؤسس
    // ✅ اليدوي لا يدخل هنا أبداً — هذا هو الضمان الأساسي
    final allCandidates = allMembers.where((m) =>
      !m.isManualRole && m.role != Roles.founder
    ).toList();

    allCandidates.sort((a, b) {
      final aCount = inviteCounts[a.userId] ?? 0;
      final bCount = inviteCounts[b.userId] ?? 0;
      if (aCount != bCount) return bCount.compareTo(aCount);
      return a.joinedAt.compareTo(b.joinedAt);
    });

    final WriteBatch batch = firestore.batch();
    bool changed = false;

    for (var member in allCandidates) {
      final int count = inviteCounts[member.userId] ?? 0;
      Roles newRole = Roles.member;

      // المنطق الصحيح: 0 دعوات = يبقى عضو، لا يستهلك مقعد
      if (count > 0) {
        if (availableSensei > 0) {
          newRole = Roles.sensei;
          availableSensei--;
        } else if (availableHakusho > 0) {
          newRole = Roles.hakusho;
          availableHakusho--;
        } else if (availableSenpai > 0) {
          newRole = Roles.senpai;
          availableSenpai--;
        }
      }

      // ✅ [إصلاح] الكتابة فقط إذا تغيرت الرتبة فعلاً
      // قبل: كان يكتب أيضاً إذا isManualRole == true وهذا يمسح صفة اليدوي
      // بعد: نتحقق فقط من تغيير الرتبة، واليدوي محمي لأنه لا يدخل allCandidates
      if (member.role != newRole) {
        final ref = firestore
            .collection(FirestorePaths.groupMembers(groupId))
            .doc(member.userId);
        batch.update(ref, {
          'role': newRole.name,
          'isManualRole': false, // ✅ آمن لأن اليدوي لا يصل لهنا أبداً
        });
        changed = true;
      }
    }

    if (changed) await batch.commit();
  }

  /// دالة مساعدة تطبق السلم الكامل: سينسي → هاكوشو → سنباي
  static List<MemberModel> applyInviteRanking({
    required List<MemberModel> members,
  }) {
    // 1. حساب عدد الدعوات لكل عضو
    final Map<String, int> inviteCounts = {};
    for (var m in members) {
      if (m.invitedByUserId != null &&
          m.invitedByUserId!.isNotEmpty &&
          m.invitedByUserId != m.userId) {
        inviteCounts.update(m.invitedByUserId!, (v) => v + 1, ifAbsent: () => 1);
      }
    }

    // 2. حساب المقاعد التلقائية المتبقية
    final int manualSenseiCount = members
        .where((m) => m.role == Roles.sensei && m.isManualRole == true)
        .length;
    final int manualHakushoCount = members
        .where((m) => m.role == Roles.hakusho && m.isManualRole == true)
        .length;
    final int manualSenpaiCount = members
        .where((m) => m.role == Roles.senpai && m.isManualRole == true)
        .length;

    int availableSensei = ((Roles.sensei.autoMaxCount ?? 0) -
        (manualSenseiCount - (Roles.sensei.manualMaxCount ?? 0)).clamp(0, 999)).clamp(0, 999);
    int availableHakusho = ((Roles.hakusho.autoMaxCount ?? 0) -
        (manualHakushoCount - (Roles.hakusho.manualMaxCount ?? 0)).clamp(0, 999)).clamp(0, 999);
    int availableSenpai = ((Roles.senpai.autoMaxCount ?? 0) -
        (manualSenpaiCount - (Roles.senpai.manualMaxCount ?? 0)).clamp(0, 999)).clamp(0, 999);

    // 3. المرشحون: عضو عادي + رتب تلقائية قابلة لإعادة الترتيب
    // ✅ اليدوي والمؤسس محميان تماماً ولا يدخلان هنا
    final List<MemberModel> candidates = members.where((m) =>
      !m.isManualRole && m.role != Roles.founder
    ).toList();

    // 4. ترتيب حسب الدعوات ثم تاريخ الانضمام
    candidates.sort((a, b) {
      final aInvites = inviteCounts[a.userId] ?? 0;
      final bInvites = inviteCounts[b.userId] ?? 0;
      if (aInvites != bInvites) return bInvites.compareTo(aInvites);
      return a.joinedAt.compareTo(b.joinedAt);
    });

    // 5. توزيع الرتب الجديدة
    final Map<String, Roles> newRoles = {};
    for (var member in candidates) {
      final int count = inviteCounts[member.userId] ?? 0;
      if (count == 0) {
        newRoles[member.userId] = Roles.member;
        continue;
      }
      if (availableSensei > 0) {
        newRoles[member.userId] = Roles.sensei;
        availableSensei--;
      } else if (availableHakusho > 0) {
        newRoles[member.userId] = Roles.hakusho;
        availableHakusho--;
      } else if (availableSenpai > 0) {
        newRoles[member.userId] = Roles.senpai;
        availableSenpai--;
      } else {
        newRoles[member.userId] = Roles.member;
      }
    }

    // 6. بناء القائمة النهائية
    // ✅ اليدوي والمؤسس لا يُمسان أبداً
    return members.map((member) {
      if (member.isManualRole || member.role == Roles.founder) {
        return member;
      }
      if (newRoles.containsKey(member.userId)) {
        return member.copyWith(role: newRoles[member.userId]!);
      }
      return member;
    }).toList();
  }

  static int getUserInviteCount(String userId, List<MemberModel> allMembers) {
    return allMembers.where((m) => m.invitedByUserId == userId).length;
  }
}