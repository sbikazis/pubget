// lib/core/logic/group_join_validator.dart
import 'dart:async'; // ✅ مضاف للتحكم في مهلة الانتظار
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

  // ✅ دالة ذكية لتنظيف وتنسيق اسم الشخصية (تعالج مشكلة الفواصل والعكس)
  String _formatCharacterName(String name) {
    String clean = name.trim();
    
    if (clean.contains(',')) {
      final parts = clean.split(',');
      if (parts.length == 2) {
        clean = '${parts[1].trim()} ${parts[0].trim()}';
      }
    }
    
    return clean.replaceAll(RegExp(r'[^\w\s]'), '').trim();
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
    String? inviterName, 
  }) async {
    
    String? inviterId;

    try {
      // ✅ أولاً: التحقق من "اسم الداعي"
      if (inviterName != null && inviterName.trim().isNotEmpty) {
        inviterId = await _verifyInviter(groupId, inviterName);
        if (inviterId == null) {
          return JoinValidationResult.failure('العضو "$inviterName" غير موجود في هذه المجموعة.');
        }
      }

      // Public group
      if (!groupType.requiresCharacter) {
        return JoinValidationResult.success(inviterId: inviterId);
      }

      if (characterName == null || characterName.trim().isEmpty) {
        return JoinValidationResult.failure('الرجاء إدخال اسم الشخصية');
      }

      final formattedCharacterName = _formatCharacterName(characterName);
      final cleanAnimeName = animeName?.trim();

      final nameError = Validators.validateCharacterName(formattedCharacterName);
      if (nameError != null) {
        return JoinValidationResult.failure(nameError);
      }

      if (characterImageUrl == null || characterImageUrl.trim().isEmpty) {
        return JoinValidationResult.failure('يجب اختيار صورة للشخصية');
      }

      if (cleanAnimeName == null || cleanAnimeName.isEmpty) {
        return JoinValidationResult.failure('اسم الأنمي غير محدد');
      }

      // ✅ تحسين: إضافة مهلة انتظار (Timeout) للتحقق من الأنمي
      final animeExists = await AnimeApiService.validateAnimeExists(cleanAnimeName)
          .timeout(const Duration(seconds: 10), onTimeout: () => throw TimeoutException('استغرقت العملية وقتاً طويلاً'));

      if (!animeExists) {
        return JoinValidationResult.failure('الأنمي غير موجود في قاعدة البيانات');
      }

      // ✅ تحسين: إضافة مهلة انتظار (Timeout) للتحقق من الشخصية
      final characterExists = await AnimeApiService.validateCharacterExists(
        animeName: cleanAnimeName,
        characterName: formattedCharacterName,
      ).timeout(const Duration(seconds: 10), onTimeout: () => throw TimeoutException('استغرقت العملية وقتاً طويلاً'));

      if (!characterExists) {
        return JoinValidationResult.failure(
          'لم نتمكن من العثور على "$formattedCharacterName" في أنمي "$cleanAnimeName".',
        );
      }

      // Check if character reserved
      final reservedDoc = await _firestoreService.getDocument(
        path: FirestorePaths.groupCharacters(groupId),
        docId: formattedCharacterName.toLowerCase(), 
      );

      if (reservedDoc != null) {
        return JoinValidationResult.failure('هذه الشخصية محجوزة بالفعل داخل المجموعة');
      }

      return JoinValidationResult.success(inviterId: inviterId);

    } on TimeoutException catch (_) {
      return JoinValidationResult.failure('فشل الاتصال: خادم الأنمي لا يستجيب حالياً، حاول مجدداً.');
    } catch (e) {
      return JoinValidationResult.failure('حدث خطأ أثناء التحقق: ${e.toString()}');
    }
  }
}