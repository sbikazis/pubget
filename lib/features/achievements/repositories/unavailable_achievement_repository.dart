import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../models/achievement_models.dart';
import 'achievement_repository.dart';

final class UnavailableAchievementRepository implements AchievementRepository {
  UnavailableAchievementRepository(this.message);

  final String message;

  @override
  Future<Result<List<AchievementItem>>> list() async =>
      FailureResult(UnknownError(message));

  @override
  Stream<Result<List<AchievementItem>>> watch(String userId) =>
      Stream<Result<List<AchievementItem>>>.value(
        FailureResult(UnknownError(message)),
      );
}
