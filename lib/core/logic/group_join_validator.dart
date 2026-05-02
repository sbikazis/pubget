import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pubget/core/constants/group_type.dart';
import 'package:pubget/core/constants/firestore_paths.dart';
import 'package:pubget/core/utils/validators.dart';
import 'package:pubget/services/api/anime_api_service.dart';
import '../../../services/firebase/firestore_service.dart';
import '../../models/user_model.dart';
import 'subscription_limits_logic.dart';

class JoinValidationResult {
  final bool isValid;
  final String? errorMessage;
  final String? foundInviterId;
  final bool shouldShowUpgrade;

  const JoinValidationResult({
    required this.isValid,
    this.errorMessage,
    this.foundInviterId,
    this.shouldShowUpgrade = false,
  });

  factory JoinValidationResult.success({String? inviterId}) {
    return JoinValidationResult(
      isValid: true,
      foundInviterId: inviterId,
    );
  }

  factory JoinValidationResult.failure(String message, {bool shouldUpgrade = false}) {
    return JoinValidationResult(
      isValid: false,
      errorMessage: message,
      shouldShowUpgrade: shouldUpgrade,
    );
  }
}

class GroupJoinValidator {
  final FirestoreService _firestoreService;

  GroupJoinValidator({
    required FirestoreService firestoreService,
  }) : _firestoreService = firestoreService;

  String _formatCharacterName(String name) {
    return name.trim(); 
  }

  // ✅ [إصلاح] إضافة البحث بـ realUserName لإيجاد صاحب الدعوة بالاسم الحقيقي أو اللقب
  // هذا هو المصدر الجذري لمشكلة "من يترقى" — بدون هذا الإصلاح لا يُحفظ invitedByUserId
  Future<String?> _verifyInviter(String groupId, String inviterName) async {
    final name = inviterName.trim();
    if (name.isEmpty) return null;

    final membersRef = FirebaseFirestore.instance
        .collection(FirestorePaths.groupMembers(groupId));

    // البحث 1: بالاسم المعروض داخل المجموعة (displayName)
    final displayQuery = await membersRef
        .where('displayName', isEqualTo: name)
        .limit(1)
        .get();
    if (displayQuery.docs.isNotEmpty) return displayQuery.docs.first.id;

    // البحث 2: باسم الشخصية (characterName / اللقب)
    final characterQuery = await membersRef
        .where('characterName', isEqualTo: name)
        .limit(1)
        .get();
    if (characterQuery.docs.isNotEmpty) return characterQuery.docs.first.id;

    // ✅ [إصلاح] البحث 3: بالاسم الحقيقي للمستخدم (realUserName)
    // هذا كان مفقوداً وهو سبب فشل التعرف على صاحب الدعوة عند كتابة اسمه الحقيقي
    final realNameQuery = await membersRef
        .where('realUserName', isEqualTo: name)
        .limit(1)
        .get();
    if (realNameQuery.docs.isNotEmpty) return realNameQuery.docs.first.id;

    return null;
  }

  Future<JoinValidationResult> validateJoin({
    required UserModel user, 
    required int currentJoinedGroupsCount, 
    required String groupId,
    required GroupType groupType,
    required String? characterName,
    required String? characterImageUrl,
    required String? animeName,
    required dynamic animeId, 
    List<dynamic>? franchiseIds, 
    String? inviterName,
  }) async {
   
    String? inviterId;

    try {
      final limitResult = SubscriptionLimitsLogic.canJoinGroup(
        user,
        currentJoinedGroupsCount,
      );

      if (!limitResult.isAllowed) {
        return JoinValidationResult.failure(
          limitResult.message ?? 'لقد وصلت للحد الأقصى للمجموعات.',
          shouldUpgrade: limitResult.shouldShowUpgrade,
        );
      }

      if (inviterName != null && inviterName.trim().isNotEmpty) {
        inviterId = await _verifyInviter(groupId, inviterName);
        if (inviterId == null) {
          return JoinValidationResult.failure('العضو "$inviterName" غير موجود في هذه المجموعة.');
        }
      }

      if (!groupType.requiresCharacter) {
        return JoinValidationResult.success(inviterId: inviterId);
      }

      if (characterName == null || characterName.trim().isEmpty) {
        return JoinValidationResult.failure('الرجاء إدخال اسم الشخصية');
      }

      final formattedCharacterName = _formatCharacterName(characterName);

      final nameError = Validators.validateCharacterName(formattedCharacterName);
      if (nameError != null) {
        return JoinValidationResult.failure(nameError);
      }

      if (characterImageUrl == null || characterImageUrl.trim().isEmpty) {
        return JoinValidationResult.failure('يجب اختيار صورة للشخصية');
      }

      // ✅ بقوة: فحص حجز الشخصية يظل فعالاً لكل أنواع التقمص (محدد أو مفتوح) لمنع التكرار
      final String characterKey = formattedCharacterName
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), '');

      final reservedDoc = await _firestoreService.getDocument(
        path: FirestorePaths.groupCharacters(groupId),
        docId: characterKey,
      );

      if (reservedDoc != null) {
        return JoinValidationResult.failure('هذه الشخصية محجوزة بالفعل داخل المجموعة.');
      }

      // =========================================================
      // ✅ التعديل الجوهري: منطق التحقق حسب نوع التقمص
      // =========================================================
      
      bool characterExists = false;

      // أ. في حالة التقمص المفتوح: تخطي قيود السلسلة والبحث عالمياً
      if (groupType == GroupType.openRoleplay) {
        // نستخدم جلب الصورة كدليل على وجود الشخصية عالمياً
        final globalImage = await AnimeApiService.getCharacterImage(formattedCharacterName)
            .timeout(const Duration(seconds: 15));
        characterExists = globalImage != null;
      } 
      // ب. في حالة التقمص المحدد: الالتزام بالسلسلة (Franchise)
      else {
        if (animeId == null) {
          return JoinValidationResult.failure(
            'رقم تعريف الأنمي (ID) غير محدد لهذه المجموعة.',
          );
        }

        Set<int> idsToSearch = {};
        final int? mainId = int.tryParse(animeId.toString());
        if (mainId != null) idsToSearch.add(mainId);

        if (franchiseIds != null) {
          for (var id in franchiseIds) {
            final int? parsedId = int.tryParse(id.toString());
            if (parsedId != null) idsToSearch.add(parsedId);
          }
        }

        characterExists = await AnimeApiService.validateCharacterExists(
          animeIds: idsToSearch.toList(),
          characterName: formattedCharacterName,
        ).timeout(const Duration(seconds: 15));

        // المرحلة الاحتياطية للتقمص المحدد فقط
        if (!characterExists && animeName != null) {
          characterExists = await AnimeApiService.isCharacterInFranchise(
            animeName: animeName,
            characterName: formattedCharacterName,
          );
        }
      }

      if (!characterExists) {
        return JoinValidationResult.failure(
          'لم نتمكن من العثور على "$formattedCharacterName" ضمن قائمة الشخصيات. تأكد من كتابة الاسم بدقة بالإنجليزية.',
        );
      }

      return JoinValidationResult.success(inviterId: inviterId);

    } on TimeoutException {
      return JoinValidationResult.failure(
        'فشل الاتصال بخادم الأنمي (انتهت المهلة)، حاول مجدداً.',
      );
    } catch (e) {
      return JoinValidationResult.failure(
        'حدث خطأ غير متوقع: ${e.toString()}',
      );
    }
  }
}
