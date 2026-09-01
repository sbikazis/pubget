import '../../../core/errors/result.dart';
import '../models/group_models.dart';

abstract interface class RoleplayRepository {
  Future<Result<void>> reserveCharacter({
    required String groupId,
    required String characterKey,
    required RoleplayCharacter character,
  });

  Future<Result<void>> releaseCharacter({
    required String groupId,
    required String characterKey,
  });

  Future<Result<List<RoleplayCharacter>>> getAvailableCharacters(
    String groupId,
  );
}
