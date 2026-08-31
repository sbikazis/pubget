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

    // 1. حساب عدد المدعوين لكل عضو (رصيد النقاط)
    final Map<String, int> inviteCounts = {};
    for (var m in allMembers) {
      final inviter = m.invitedByUserId;
      // لا نحتسب الدعوة إلا إذا كانت لشخص آخر غير العضو نفسه
      if (inviter != null && inviter.isNotEmpty && inviter != m.userId) {
        inviteCounts.update(inviter, (v) => v + 1, ifAbsent: () => 1);
      }
    }

    // 2. تحديد المرشحين للمنافسة: 
    // أي شخص ليس مؤسساً ولم يتم تثبيت رتبته "يدوياً" من قبل الشوغو
    final candidates = allMembers.where((m) =>
      !m.isManualRole && m.role != Roles.founder
    ).toList();

    // 3. ترتيب المرشحين حسب عدد المدعوين (الأكثر أولاً)
    candidates.sort((a, b) {
      final countA = inviteCounts[a.userId] ?? 0;
      final countB = inviteCounts[b.userId] ?? 0;
      return countB.compareTo(countA);
    });

    // 4. المقاعد التلقائية المتاحة حسب النظام (1 سينسي، 1 هاكوشو، 2 سنباي)
    int availableSensei = Roles.sensei.autoMaxCount ?? 0;
    int availableHakusho = Roles.hakusho.autoMaxCount ?? 0;
    int availableSenpai = Roles.senpai.autoMaxCount ?? 0;

    final Map<String, Roles> newRoles = {};

    for (var candidate in candidates) {
      final count = inviteCounts[candidate.userId] ?? 0;

      // ✅ التعديل الذهبي: إذا كان العضو يملك 0 دعوات، فهو عضو عادي فوراً
      // ولا يحق له المنافسة على المقاعد الشاغرة مهما كانت خالية.
      if (count <= 0) {
        newRoles[candidate.userId] = Roles.member;
        continue; 
      }

      // توزيع الرتب على المستحقين (من لديهم دعوات > 0) بالترتيب
      if (availableSensei > 0) {
        newRoles[candidate.userId] = Roles.sensei;
        availableSensei--;
      } else if (availableHakusho > 0) {
        newRoles[candidate.userId] = Roles.hakusho;
        availableHakusho--;
      } else if (availableSenpai > 0) {
        newRoles[candidate.userId] = Roles.senpai;
        availableSenpai--;
      } else {
        newRoles[candidate.userId] = Roles.member;
      }
    }

    // 5. تحديث Firestore بالدفعات (Batch) فقط للأعضاء الذين تغيرت رتبهم فعلياً
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
          // نحافظ على isManualRole كـ false لأن هذه رتبة تلقائية ناتجة عن دعوات
          'isManualRole': false,
          'inviteCount': inviteCounts[member.userId] ?? 0,
        });
        changed = true;
      }
    }

    if (changed) await batch.commit();
  }

  /// دالة مساعدة لحساب عدد الدعوات لعضو معين (للعرض في الواجهات)
  static int getUserInviteCount(String userId, List<MemberModel> allMembers) {
    return allMembers.where((m) => m.invitedByUserId == userId).length;
  }
}