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

    // ✅ [إصلاح المشكلة 2] حساب المقاعد المتبقية ديناميكياً
    // = autoMaxCount من roles.dart (الإجمالي - اليدوي)
    // مع التأكد أن المقاعد المحسوبة لا تقل عن صفر
    final int manualSenseiCount = allMembers
        .where((m) => m.role == Roles.sensei && m.isManualRole == true)
        .length;
    final int manualHakushoCount = allMembers
        .where((m) => m.role == Roles.hakusho && m.isManualRole == true)
        .length;
    final int manualSenpaiCount = allMembers
        .where((m) => m.role == Roles.senpai && m.isManualRole == true)
        .length;

    // ✅ المقاعد المتاحة للدعوات = autoMaxCount - ما استُخدم من المقاعد اليدوية فعلياً
    // نستخدم autoMaxCount من roles.dart الذي يساوي (maxCount - manualMaxCount)
    int availableSensei = ((Roles.sensei.autoMaxCount ?? 0) - 
        (manualSenseiCount - (Roles.sensei.manualMaxCount ?? 0)).clamp(0, 999)).clamp(0, 999);
    int availableHakusho = ((Roles.hakusho.autoMaxCount ?? 0) - 
        (manualHakushoCount - (Roles.hakusho.manualMaxCount ?? 0)).clamp(0, 999)).clamp(0, 999);
    int availableSenpai = ((Roles.senpai.autoMaxCount ?? 0) - 
        (manualSenpaiCount - (Roles.senpai.manualMaxCount ?? 0)).clamp(0, 999)).clamp(0, 999);

    // ✅ تصفية الأعضاء "العاديين" الذين لا يملكون رتبة يدوية فقط
    // هؤلاء هم من يحق للنظام ترقيتهم تلقائياً بناءً على الدعوات
    final candidates = allMembers.where((m) => 
      m.role == Roles.member && m.isManualRole == false
    ).toList();

    // ✅ أيضاً نضيف من كانت رتبته تلقائية (sensei/hakusho/senpai غير يدوية)
    // لأنهم قد يحتاجون لإعادة ترتيب إذا تغيرت الدعوات
    final autoRankedMembers = allMembers.where((m) =>
      (m.role == Roles.sensei || m.role == Roles.hakusho || m.role == Roles.senpai) &&
      m.isManualRole == false
    ).toList();

    // دمج المرشحين: العاديون + من لديهم رتبة تلقائية قابلة للتغيير
    final allCandidates = [...candidates, ...autoRankedMembers];

    allCandidates.sort((a, b) {
      final aCount = inviteCounts[a.userId] ?? 0;
      final bCount = inviteCounts[b.userId] ?? 0;
      if (aCount != bCount) return bCount.compareTo(aCount);
      return a.joinedAt.compareTo(b.joinedAt);
    });

    final WriteBatch batch = firestore.batch();
    bool changed = false;

    // توزيع الرتب الآلية بناءً على المقاعد المتاحة المحسوبة ديناميكياً
    for (var member in allCandidates) {
      Roles newRole = Roles.member;

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
        // ✅ نحدث الرتبة مع التأكيد أن isManualRole يبقى false للتلقائيين
        batch.update(ref, {
          'role': newRole.name,
          'isManualRole': false,
        });
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

    // نأخذ فقط من ليس لديه رتبة يدوية
    final eligibleMembers = members.where((m) => 
      m.role == Roles.member && m.isManualRole == false
    ).toList();

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
      // إذا كان العضو يدوياً، لا تلمسه أبداً
      if (member.isManualRole) return member;

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