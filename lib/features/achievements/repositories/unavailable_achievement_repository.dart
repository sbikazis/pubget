import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../data/achievement_catalog.dart';
import '../models/achievement_models.dart';
import 'achievement_repository.dart';

final class UnavailableAchievementRepository implements AchievementRepository {
  UnavailableAchievementRepository([
    this.message = 'Achievements are unavailable in this build.',
  ]);

  final String message;

  @override
  Future<Result<List<AchievementItem>>> list({String? userId}) async {
    return Success(AchievementCatalog.lockedItems());
  }

  @override
  Stream<Result<List<AchievementItem>>> watch(String userId) async* {
    yield Success(AchievementCatalog.lockedItems());
  }
}

Failure unavailableAchievementFailure([String? message]) =>
    UnavailableError(message ?? 'Achievements are unavailable.');
