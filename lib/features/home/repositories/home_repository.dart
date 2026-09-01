import '../../../core/errors/result.dart';
import '../../groups/models/group_models.dart';
import '../../social/models/public_profile.dart';
import '../models/home_models.dart';

abstract interface class HomeRepository {
  Future<Result<List<Group>>> getPromotedGroups({int limit = 10, Group? after});
  Future<Result<List<Group>>> getRisingGroups({int limit = 10, Group? after});
  Future<Result<List<Group>>> getRecommendedGroups({
    int limit = 10,
    Group? after,
  });
  Future<Result<List<Group>>> getCommunityActivity({
    int limit = 10,
    Group? after,
  });
  Future<Result<List<PublicProfile>>> getRecommendedPeople({
    required String userId,
    int limit = 10,
    PublicProfile? after,
  });
  Future<Result<DiscoverySearchResults>> search(String query);
}
