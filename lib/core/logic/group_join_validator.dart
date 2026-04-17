// lib/core/logic/group_join_validator.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pubget/core/constants/group_type.dart';
import 'package:pubget/core/constants/firestore_paths.dart';
import 'package:pubget/core/utils/validators.dart';
import 'package:pubget/services/api/anime_api_service.dart';
import '../../../services/firebase/firestore_service.dart';

class JoinValidationResult {
  final bool isValid;
  final String? errorMessage;
  final String? foundInviterId;

  const JoinValidationResult({
    required this.isValid,
    this.errorMessage,
    this.foundInviterId,
  });

  factory JoinValidationResult.success({String? inviterId}) {
    return JoinValidationResult(
      isValid: true,
      foundInviterId: inviterId,
    );
  }

  factory JoinValidationResult.failure(String message) {
    return JoinValidationResult(
      isValid: false,
      errorMessage: message,
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
    return name.trim(); // نكتفي بحذف المسافات الجانبية لإرسال الاسم كما هو في MAL
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
    required String groupId,
    required GroupType groupType,
    required String? characterName,
    required String? characterImageUrl,
    required String? animeName,
    required dynamic animeId, // ✅ التعديل: إضافة animeId المطلوب للنسخة الجديدة من الـ API
    String? inviterName,
  }) async {
   
    String? inviterId;

    try {
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

      // التحقق من المدخلات الأساسية
      if (characterName == null || characterName.trim().isEmpty) {
        return JoinValidationResult.failure('الرجاء إدخال اسم الشخصية');
      }

      // التعديل: استخدام الاسم كما أدخله المستخدم لضمان مطابقة الـ API
      final formattedCharacterName = _formatCharacterName(characterName);

      final nameError = Validators.validateCharacterName(formattedCharacterName);
      if (nameError != null) {
        return JoinValidationResult.failure(nameError);
      }

      if (characterImageUrl == null || characterImageUrl.trim().isEmpty) {
        return JoinValidationResult.failure('يجب اختيار صورة للشخصية');
      }

      // ✅ التعديل الجوهري: إزالة التحقق الإجباري من animeName النصي والاعتماد على animeId
      if (animeId == null) {
        return JoinValidationResult.failure('رقم تعريف الأنمي (ID) غير محدد لهذه المجموعة، يرجى التواصل مع الشوغو.');
      }

      // ✅ التعديل الجوهري: توحيد الاسم لـ lowercase وحذف المسافات تماماً عند فحص Firestore
      // هذا هو "المفتاح" الذي نستخدمه في الـ Provider لضمان عدم التكرار (مثلاً: leviackerman)
      final String characterKey = formattedCharacterName.toLowerCase().replaceAll(RegExp(r'\s+'), '');

      final reservedDoc = await _firestoreService.getDocument(
        path: FirestorePaths.groupCharacters(groupId),
        docId: characterKey,
      );

      if (reservedDoc != null) {
        return JoinValidationResult.failure('هذه الشخصية محجوزة بالفعل داخل المجموعة من قبل عضو آخر.');
      }

      // ✅ التعديل الجوهري: استدعاء الـ API باستخدام animeId لضمان دقة البحث
      // تم رفع مهلة الانتظار إلى 15 ثانية لضمان استقرار الرد من خادم الأنمي
      final characterExists = await AnimeApiService.validateCharacterExists(
        animeId: animeId, 
        characterName: formattedCharacterName,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('استغرقت عملية التحقق وقتاً طويلاً، خادم الأنمي بطيء حالياً.')
      );

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