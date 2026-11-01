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

  /// Server-authoritative roleplay context: group type, linked anime, and the
  /// currently reserved character keys.
  Future<Result<RoleplayGroupContext>> roleplayContext(String groupId);
}
