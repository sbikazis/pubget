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

    // ✅ حساب المقاعد المتبقية ديناميكياً
    final int manualSenseiCount = allMembers
        .where((m) => m.role == Roles.sensei && m.isManualRole == true)
        .length;
    final int manualHakushoCount = allMembers
        .where((m) => m.role == Roles.hakusho && m.isManualRole == true)
        .length;
    final int manualSenpaiCount = allMembers
        .where((m) => m.role == Roles.senpai && m.isManualRole == true)
        .length;

    // المقاعد المتاحة للدعوات = autoMaxCount - ما استُخدم من المقاعد اليدوية فعلياً
    int availableSensei = ((Roles.sensei.autoMaxCount ?? 0) - 
        (manualSenseiCount - (Roles.sensei.manualMaxCount ?? 0)).clamp(0, 999)).clamp(0, 999);
    int availableHakusho = ((Roles.hakusho.autoMaxCount ?? 0) - 
        (manualHakushoCount - (Roles.hakusho.manualMaxCount ?? 0)).clamp(0, 999)).clamp(0, 999);
    int availableSenpai = ((Roles.senpai.autoMaxCount ?? 0) - 
        (manualSenpaiCount - (Roles.senpai.manualMaxCount ?? 0)).clamp(0, 999)).clamp(0, 999);

    // ✅ تصفية الأعضاء "العاديين" الذين لا يملكون رتبة يدوية فقط
    // + من لديهم رتبة تلقائية قابلة لإعادة الترتيب
    final allCandidates = allMembers.where((m) => 
      (m.role == Roles.member && m.isManualRole == false) ||
      ((m.role == Roles.sensei || m.role == Roles.hakusho || m.role == Roles.senpai) &&
        m.isManualRole == false)
    ).toList();

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

  /// ✅ [تعديل المشكلة 4] دالة مساعدة تطبق السلم الكامل: سينسي → هاكوشو → سنباي
  static List<MemberModel> applyInviteRanking({
    required List<MemberModel> members,
  }) {
    // 1. حساب عدد الدعوات لكل عضو
    final Map<String, int> inviteCounts = {};
    for (var m in members) {
      if (m.invitedByUserId != null) {
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
    final List<MemberModel> candidates = members.where((m) =>
      (m.role == Roles.member && m.isManualRole == false) ||
      ((m.role == Roles.sensei || m.role == Roles.hakusho || m.role == Roles.senpai) &&
        m.isManualRole == false)
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

    // 6. بناء القائمة النهائية: نحافظ على اليدوي، نحدث التلقائي
    return members.map((member) {
      // لو يدوي أو شوغو، لا نلمسه أبداً
      if (member.isManualRole || member.role == Roles.founder) {
        return member;
      }
      // لو كان مرشح، نعطيه رتبته الجديدة
      if (newRoles.containsKey(member.userId)) {
        return member.copyWith(role: newRoles[member.userId]!);
      }
      // غير ذلك يبقى كما هو
      return member;
    }).toList();
  }

  static int getUserInviteCount(String userId, List<MemberModel> allMembers) {
    return allMembers.where((m) => m.invitedByUserId == userId).length;
  }
}