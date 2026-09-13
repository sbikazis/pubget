import 'dart:typed_data';

import '../../../core/errors/result.dart';
import '../../authentication/models/pubget_user.dart';
import '../models/profile_section_privacy.dart';
import '../models/profile_social_link.dart';
import '../models/public_profile.dart';

final class ProfileUpdate {
  const ProfileUpdate({
    this.username,
    this.displayName,
    this.bio,
    this.age,
    this.clearAge = false,
    this.country,
    this.favoriteQuote,
    this.animeTwin,
    this.socialLinks,
    this.favoriteAnimeIds,
    this.favoriteAnimes,
    this.profileVisibility,
    this.activityVisibility,
    this.whoCanMessageMe,
    this.sectionPrivacy,
    this.coverUrl,
  });

  final String? username;
  final String? displayName;
  final String? bio;
  final int? age;
  final bool clearAge;
  final String? country;
  final String? favoriteQuote;
  final String? animeTwin;
  final List<ProfileSocialLink>? socialLinks;
  final List<String>? favoriteAnimeIds;
  final List<String>? favoriteAnimes;
  final String? profileVisibility;
  final String? activityVisibility;
  final String? whoCanMessageMe;
  final ProfileSectionPrivacy? sectionPrivacy;
  final String? coverUrl;

  Map<String, dynamic> toMap() => <String, dynamic>{
    if (username != null) 'username': username!.trim(),
    if (displayName != null) 'displayName': displayName!.trim(),
    if (bio != null) 'bio': bio!.trim(),
    if (clearAge) 'age': null else if (age != null) 'age': age,
    if (country != null) 'country': country!.trim(),
    if (favoriteQuote != null) 'favoriteQuote': favoriteQuote!.trim(),
    if (animeTwin != null) 'animeTwin': animeTwin!.trim(),
    if (socialLinks != null)
      'socialLinks': socialLinks!.map((link) => link.toMap()).toList(),
    if (favoriteAnimeIds != null) 'favoriteAnimeIds': favoriteAnimeIds,
    if (favoriteAnimes != null) 'favoriteAnimes': favoriteAnimes,
    if (profileVisibility != null) 'profileVisibility': profileVisibility,
    if (activityVisibility != null) 'activityVisibility': activityVisibility,
    if (whoCanMessageMe != null) 'whoCanMessageMe': whoCanMessageMe,
    if (sectionPrivacy != null) 'sectionPrivacy': sectionPrivacy!.toMap(),
    if (coverUrl != null) 'coverUrl': coverUrl,
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

  Future<Result<String>> uploadCover({
    required String userId,
    required Uint8List bytes,
    required String contentType,
  });
}
