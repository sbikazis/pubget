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
    
    // 1. جلب جميع أعضاء المجموعة
    final membersSnapshot = await firestore
        .collection(FirestorePaths.groupMembers(groupId))
        .get();
    
    final allMembers = membersSnapshot.docs
        .map((doc) => MemberModel.fromMap(doc.data()))
        .toList();

    // 2. حساب عدد الدعوات لكل عضو (بناءً على حقل invitedByUserId في الأعضاء)
    final Map<String, int> inviteCounts = {};
    for (var m in allMembers) {
      if (m.invitedByUserId != null) {
        inviteCounts.update(
          m.invitedByUserId!,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
    }

    // 3. تحديد المقاعد الشاغرة
    int availableSensei = 1; 
    int availableHakusho = 1;
    int availableSenpai = 2;

    // 4. تصفية الأعضاء "العاديين"
    final candidates = allMembers.where((m) => m.role == Roles.member).toList();

    candidates.sort((a, b) {
      final aCount = inviteCounts[a.userId] ?? 0;
      final bCount = inviteCounts[b.userId] ?? 0;
      if (aCount != bCount) return bCount.compareTo(aCount);
      return a.joinedAt.compareTo(b.joinedAt);
    });

    final WriteBatch batch = firestore.batch();
    bool changed = false;

    // 5. توزيع الرتب الآلية
    for (var i = 0; i < candidates.length; i++) {
      // ✅ تم تغيير النوع هنا من String إلى Roles لحل الأخطاء الأربعة
      Roles newRole = Roles.member; 
      final member = candidates[i];

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

      // إذا تغيرت رتبة العضو، نضيفها للـ Batch
      if (member.role != newRole) {
        final ref = firestore
            .collection(FirestorePaths.groupMembers(groupId))
            .doc(member.userId);
        // ✅ نرسل name الخاص بالرتبة للـ Firestore (String)
        batch.update(ref, {'role': newRole.name}); 
        changed = true;
      }
    }

    if (changed) {
      await batch.commit();
    }
  }

  /// ✅ دالة مساعدة (قديمة) للحفاظ على التوافق
  static List<MemberModel> applyInviteRanking({
    required List<MemberModel> members,
  }) {
    final Map<String, int> inviteCount = {};
    for (var m in members) {
      if (m.invitedByUserId != null) {
        inviteCount.update(m.invitedByUserId!, (v) => v + 1, ifAbsent: () => 1);
      }
    }

    final eligibleMembers = members.where((m) => m.role == Roles.member).toList();

    eligibleMembers.sort((a, b) {
      final aInvites = inviteCount[a.userId] ?? 0;
      final bInvites = inviteCount[b.userId] ?? 0;
      if (aInvites != bInvites) return bInvites.compareTo(aInvites);
      return a.joinedAt.compareTo(b.joinedAt);
    });

    final int maxSenpai = Roles.senpai.maxCount ?? 2; 

    final Set<String> newSenpaiIds = eligibleMembers
        .take(maxSenpai)
        .map((e) => e.userId)
        .toSet();

    return members.map((member) {
      if (member.role == Roles.founder || 
          member.role == Roles.sensei || 
          member.role == Roles.hakusho) {
        return member;
      }
      if (newSenpaiIds.contains(member.userId)) {
        return member.copyWith(role: Roles.senpai);
      }
      return member.copyWith(role: Roles.member);
    }).toList();
  }

  static int getUserInviteCount(String userId, List<MemberModel> allMembers) {
    return allMembers.where((m) => m.invitedByUserId == userId).length;
  }
}