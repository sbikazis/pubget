import '../../../core/errors/result.dart';
import '../models/achievement_models.dart';

abstract interface class AchievementRepository {
  /// Server catalog + progress for [userId] (viewer must be signed in).
  Future<Result<List<AchievementItem>>> list({String? userId});

  /// Live unlocked docs for [userId] (signed-in readable).
  Stream<Result<List<AchievementItem>>> watch(String userId);
}
