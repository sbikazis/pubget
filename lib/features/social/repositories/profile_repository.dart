import 'dart:typed_data';

import '../../../core/errors/result.dart';
import '../../authentication/models/pubget_user.dart';
import '../models/public_profile.dart';

final class ProfileUpdate {
  const ProfileUpdate({
    this.bio,
    this.favoriteAnimeIds,
    this.profileVisibility,
    this.activityVisibility,
  });

  final String? bio;
  final List<String>? favoriteAnimeIds;
  final String? profileVisibility;
  final String? activityVisibility;

  Map<String, dynamic> toMap() => <String, dynamic>{
    if (bio != null) 'bio': bio!.trim(),
    if (favoriteAnimeIds != null) 'favoriteAnimeIds': favoriteAnimeIds,
    if (profileVisibility != null) 'profileVisibility': profileVisibility,
    if (activityVisibility != null) 'activityVisibility': activityVisibility,
  };
}

abstract interface class ProfileRepository {
  Future<Result<PublicProfile>> getPublicProfile(String userId);

  Future<Result<PubgetUser>> getOwnProfile(String userId);

  Future<Result<PubgetUser>> updateProfile(String userId, ProfileUpdate update);

  Future<Result<String>> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String contentType,
  });
}
