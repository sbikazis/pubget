import 'package:pubget/core/constants/group_type.dart';
import 'package:pubget/core/constants/firestore_paths.dart';
import 'package:pubget/core/utils/validators.dart';
import 'package:pubget/services/api/anime_api_service.dart';
import '../../../services/firebase/firestore_service.dart';

class JoinValidationResult {
  final bool isValid;
  final String? errorMessage;

  const JoinValidationResult({
    required this.isValid,
    this.errorMessage,
  });

  factory JoinValidationResult.success() {
    return const JoinValidationResult(
      isValid: true,
    );
  }

  factory JoinValidationResult.failure(
      String message) {
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

  /// Main Entry Point
  Future<JoinValidationResult> validateJoin({
    required String groupId,
    required GroupType groupType,
    required String? characterName,
    required String? characterImageUrl,
    required String? animeName,
  }) async {
    //  Public group
    if (!groupType.requiresCharacter) {
      return JoinValidationResult.success();
    }

    //  Validate character name locally
    final nameError =
        Validators.validateCharacterName(
            characterName);

    if (nameError != null) {
      return JoinValidationResult.failure(
          nameError);
    }

    //  Validate image
    if (characterImageUrl == null ||
        characterImageUrl.trim().isEmpty) {
      return JoinValidationResult.failure(
          'يجب اختيار صورة للشخصية');
    }

    //  Validate anime exists
    if (animeName == null ||
        animeName.trim().isEmpty) {
      return JoinValidationResult.failure(
          'اسم الأنمي غير محدد');
    }

    final animeExists =
        await AnimeApiService
            .validateAnimeExists(animeName);

    if (!animeExists) {
      return JoinValidationResult.failure(
          'الأنمي غير موجود في قاعدة البيانات');
    }

    //  Validate character belongs to anime
    final characterExists =
        await AnimeApiService
            .validateCharacterExists(
      animeName: animeName,
      characterName:
          characterName!.trim(),
    );

    if (!characterExists) {
      return JoinValidationResult.failure(
          'الشخصية غير موجودة في هذا الأنمي');
    }

    //  Check if character reserved
    final doc =
        await _firestoreService.getDocument(
      path: FirestorePaths
          .groupCharacters(groupId),
      docId: characterName,
    );

    if (doc != null) {
      return JoinValidationResult.failure(
          'هذه الشخصية محجوزة بالفعل داخل المجموعة');
    }

    return JoinValidationResult.success();
  }
}