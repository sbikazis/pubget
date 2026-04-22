import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pubget/core/constants/group_type.dart';
import 'package:pubget/core/constants/firestore_paths.dart';
import 'package:pubget/core/utils/validators.dart';
import 'package:pubget/services/api/anime_api_service.dart';
import '../../../services/firebase/firestore_service.dart';
import '../../models/user_model.dart'; // إضافة استيراد الموديل
import 'subscription_limits_logic.dart'; // إضافة منطق الحدود

class JoinValidationResult {
  final bool isValid;
  final String? errorMessage;
  final String? foundInviterId;
  final bool shouldShowUpgrade; // إضافة حقل لدعم واجهة الترقية

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

  // ✅ التعديل: تبسيط التنظيف ليكون متوافقاً مع الـ API دون تغيير ترتيب الكلمات
  String _formatCharacterName(String name) {
    return name.trim(); 
  }

  /// ✅ وظيفة البحث عن الداعي للتأكد من وجوده في المجموعة
  Future<String?> _verifyInviter(String groupId, String inviterName) async {
    final name = inviterName.trim();
    if (name.isEmpty) return null;

    final membersRef = FirebaseFirestore.instance.collection(FirestorePaths.groupMembers(groupId));

    final displayQuery = await membersRef.where('displayName', isEqualTo: name).limit(1).get();
    if (displayQuery.docs.isNotEmpty) return displayQuery.docs.first.id;

    final characterQuery = await membersRef.where('characterName', isEqualTo: name).limit(1).get();
    if (characterQuery.docs.isNotEmpty) return characterQuery.docs.first.id;

    return null;
  }

  /// Main Entry Point
  Future<JoinValidationResult> validateJoin({
    required UserModel user, // ✅ التعديل: تمرير المستخدم للفحص الأولي
    required int currentJoinedGroupsCount, // ✅ التعديل: تمرير عدد المجموعات الحالية
    required String groupId,
    required GroupType groupType,
    required String? characterName,
    required String? characterImageUrl,
    required String? animeName,
    required dynamic animeId, 
    String? inviterName,
  }) async {
   
    String? inviterId;

    try {
      // 🟢 الخطوة 0: التحقق من حدود الاشتراك (قبل أي عملية مكلفة)
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

      // 1. التحقق من "اسم الداعي" أولاً (محلي سريع)
      if (inviterName != null && inviterName.trim().isNotEmpty) {
        inviterId = await _verifyInviter(groupId, inviterName);
        if (inviterId == null) {
          return JoinValidationResult.failure('العضو "$inviterName" غير موجود في هذه المجموعة.');
        }
      }

      // إذا كانت المجموعة عامة ولا تتطلب شخصية، نكتفي بالنجاح هنا
      if (!groupType.requiresCharacter) {
        return JoinValidationResult.success(inviterId: inviterId);
      }

      // التحقق من المدخلات الأساسية للشخصية
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

      // التحقق من وجود AnimeId
      if (animeId == null) {
        return JoinValidationResult.failure('رقم تعريف الأنمي (ID) غير محدد لهذه المجموعة، يرجى التواصل مع الشوغو.');
      }

      // فحص حجز الشخصية في Firestore (مفتاح فريد)
      final String characterKey = formattedCharacterName.toLowerCase().replaceAll(RegExp(r'\s+'), '');

      final reservedDoc = await _firestoreService.getDocument(
        path: FirestorePaths.groupCharacters(groupId),
        docId: characterKey,
      );

      if (reservedDoc != null) {
        return JoinValidationResult.failure('هذه الشخصية محجوزة بالفعل داخل المجموعة من قبل عضو آخر.');
      }

      // =========================================================
      // ✅ التعديل الذهبي: منطق التحقق الثنائي (Double Verification)
      // فك الارتباط الصارم بالموسم عند الحاجة
      // =========================================================
      
      // المرحلة أ: البحث في الموسم المحدد (السريع والمعتاد)
      bool characterExists = await AnimeApiService.validateCharacterExists(
        animeId: animeId, 
        characterName: formattedCharacterName,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('استغرقت عملية التحقق وقتاً طويلاً، خادم الأنمي بطيء حالياً.')
      );

      // المرحلة ب: المنقذ - إذا فشل الموسم، نبحث في السلسلة الكاملة باستخدام المطابقة المتقاطعة
      if (!characterExists && animeName != null) {
        characterExists = await AnimeApiService.isCharacterInFranchise(
          animeId: animeId, // تم إضافة المعرف لدقة المليار بالمئة
          animeName: animeName,
          characterName: formattedCharacterName,
        );
      }

      if (!characterExists) {
        return JoinValidationResult.failure(
          'لم نتمكن من العثور على "$formattedCharacterName" ضمن قائمة شخصيات هذا الأنمي المعتمدة. تأكد من كتابة الاسم بدقة بالإنجليزية كما هو في MyAnimeList.',
        );
      }

      return JoinValidationResult.success(inviterId: inviterId);

    } on TimeoutException catch (e) {
      return JoinValidationResult.failure(e.message ?? 'فشل الاتصال بخادم الأنمي، حاول مجدداً.');
    } catch (e) {
      return JoinValidationResult.failure('حدث خطأ غير متوقع أثناء التحقق: ${e.toString()}');
    }
  }
}