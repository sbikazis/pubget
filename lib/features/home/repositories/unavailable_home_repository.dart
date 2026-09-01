import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../groups/models/group_models.dart';
import '../../social/models/public_profile.dart';
import '../models/home_models.dart';
import 'home_repository.dart';

final class UnavailableHomeRepository implements HomeRepository {
  const UnavailableHomeRepository(this.message);
  final String message;

  FailureResult<T> _failure<T>() => FailureResult(UnknownError(message));

  @override
  Future<Result<List<Group>>> getPromotedGroups({
    int limit = 10,
    Group? after,
  }) async => _failure();

  @override
  Future<Result<List<Group>>> getRisingGroups({
    int limit = 10,
    Group? after,
  }) async => _failure();

  @override
  Future<Result<List<Group>>> getRecommendedGroups({
    int limit = 10,
    Group? after,
  }) async => _failure();

  @override
  Future<Result<List<Group>>> getCommunityActivity({
    int limit = 10,
    Group? after,
  }) async => _failure();

  @override
  Future<Result<List<PublicProfile>>> getRecommendedPeople({
    required String userId,
    int limit = 10,
    PublicProfile? after,
  }) async => _failure();

  @override
  Future<Result<DiscoverySearchResults>> search(String query) async =>
      _failure();
}
