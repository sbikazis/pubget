// lib/core/logic/invite_ranking_logic.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/member_model.dart';
import '../constants/roles.dart';
import '../constants/firestore_paths.dart';

class InviteRankingLogic {
  InviteRankingLogic._();

  /// الدالة الرئيسية: تحديث الرتب بناءً على نظام الدعوات
  static Future<void> refreshRanks({required String groupId}) async {
    final firestore = FirebaseFirestore.instance;

    final membersSnapshot = await firestore
        .collection(FirestorePaths.groupMembers(groupId))
        .get();

    final allMembers = membersSnapshot.docs
        .map((doc) => MemberModel.fromMap(doc.data()))
        .toList();

    // حساب عدد المدعوين لكل عضو
    final Map<String, int> inviteCounts = {};
    for (var m in allMembers) {
      final inviter = m.invitedByUserId;
      if (inviter != null && inviter.isNotEmpty && inviter != m.userId) {
        inviteCounts.update(inviter, (v) => v + 1, ifAbsent: () => 1);
      }
    }

    // المرشحون: كل من ليس مؤسس وليس يدوياً
    final candidates = allMembers.where((m) =>
      !m.isManualRole && m.role != Roles.founder
    ).toList();

    // ترتيب المرشحين حسب عدد المدعوين (الأكثر أولاً)
    candidates.sort((a, b) {
      final countA = inviteCounts[a.userId] ?? 0;
      final countB = inviteCounts[b.userId] ?? 0;
      return countB.compareTo(countA);
    });

    // المقاعد التلقائية المتاحة
    int availableSensei = Roles.sensei.autoMaxCount ?? 0; // 1
    int availableHakusho = Roles.hakusho.autoMaxCount ?? 0; // 1
    int availableSenpai = Roles.senpai.autoMaxCount ?? 0; // 2

    final Map<String, Roles> newRoles = {};
    int index = 0;

    for (var candidate in candidates) {
      if (index == 0 && availableSensei > 0) {
        newRoles[candidate.userId] = Roles.sensei;
        availableSensei--;
      } else if (index == 1 && availableHakusho > 0) {
        newRoles[candidate.userId] = Roles.hakusho;
        availableHakusho--;
      } else if ((index == 2 || index == 3) && availableSenpai > 0) {
        newRoles[candidate.userId] = Roles.senpai;
        availableSenpai--;
      } else {
        newRoles[candidate.userId] = Roles.member;
      }
      index++;
    }

    // تحديث Firestore فقط إذا تغيّرت الرتبة
    final batch = firestore.batch();
    bool changed = false;

    for (var member in candidates) {
      final newRole = newRoles[member.userId] ?? Roles.member;
      if (member.role != newRole) {
        final ref = firestore
            .collection(FirestorePaths.groupMembers(groupId))
            .doc(member.userId);
        batch.update(ref, {
          'role': newRole.name,
          'isManualRole': false,
        });
        changed = true;
      }
    }

    if (changed) await batch.commit();
  }

  /// دالة مساعدة لحساب عدد الدعوات لعضو معين
  static int getUserInviteCount(String userId, List<MemberModel> allMembers) {
    return allMembers.where((m) => m.invitedByUserId == userId).length;
  }
}