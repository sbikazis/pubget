import '../../../core/errors/result.dart';
import '../models/achievement_models.dart';

abstract interface class AchievementRepository {
  Future<Result<List<AchievementItem>>> list();

  Stream<Result<List<AchievementItem>>> watch(String userId);
}
