import '../../social/models/profile_section_privacy.dart';
import '../../social/models/profile_social_link.dart';

final class PubgetUser {
  const PubgetUser({
    required this.id,
    required this.email,
    this.username,
    this.displayName,
    this.avatarUrl,
    this.coverUrl,
    this.bio,
    this.age,
    this.country,
    this.favoriteQuote,
    this.animeTwin,
    this.socialLinks = const <ProfileSocialLink>[],
    this.favoriteAnimes = const <String>[],
    this.favoriteAnimeIds = const <String>[],
    this.profileVisibility = 'public',
    this.activityVisibility = 'public',
    this.whoCanMessageMe = 'related',
    this.sectionPrivacy = ProfileSectionPrivacy.public,
    this.totalRespect = 0,
    this.fansCount = 0,
    required this.createdAt,
    required this.isProfileCompleted,
    this.hasSkippedOnboarding = false,
  });

  final String id;
  final String email;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String? coverUrl;
  final String? bio;
  final int? age;
  final String? country;
  final String? favoriteQuote;
  final String? animeTwin;
  final List<ProfileSocialLink> socialLinks;
  final List<String> favoriteAnimes;
  final List<String> favoriteAnimeIds;
  final String profileVisibility;
  final String activityVisibility;
  final String whoCanMessageMe;
  final ProfileSectionPrivacy sectionPrivacy;
  final int totalRespect;
  final int fansCount;
  final DateTime createdAt;
  final bool isProfileCompleted;
  final bool hasSkippedOnboarding;

  String get primaryName {
    final display = displayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final user = username?.trim();
    if (user != null && user.isNotEmpty) return user;
    return 'Pubget user';
  }

  factory PubgetUser.fromMap(Map<String, dynamic> map, {String? id}) {
    return PubgetUser(
      id: id ?? map['id'] as String? ?? '',
      email: map['email'] as String? ?? '',
      username: map['username'] as String?,
      displayName: map['displayName'] as String?,
      avatarUrl: map['avatarUrl'] as String?,
      coverUrl: map['coverUrl'] as String?,
      bio: map['bio'] as String?,
      age: _optionalInt(map['age']),
      country: map['country'] as String?,
      favoriteQuote: map['favoriteQuote'] as String?,
      animeTwin: map['animeTwin'] as String?,
      socialLinks: _linksFrom(map['socialLinks']),
      favoriteAnimes:
          (map['favoriteAnimes'] as List<Object?>?)?.whereType<String>().toList(
            growable: false,
          ) ??
          const <String>[],
      favoriteAnimeIds:
          (map['favoriteAnimeIds'] as List<Object?>?)
              ?.whereType<String>()
              .toList(growable: false) ??
          const <String>[],
      profileVisibility: map['profileVisibility'] as String? ?? 'public',
      activityVisibility: map['activityVisibility'] as String? ?? 'public',
      whoCanMessageMe: map['whoCanMessageMe'] as String? ?? 'related',
      sectionPrivacy: ProfileSectionPrivacy.fromMap(
        map['sectionPrivacy'] is Map<String, dynamic>
            ? map['sectionPrivacy'] as Map<String, dynamic>
            : null,
      ),
      totalRespect: _intFrom(map['totalRespect']),
      fansCount: _intFrom(map['fansCount']),
      createdAt: _dateFrom(map['createdAt']) ?? DateTime.now(),
      isProfileCompleted: map['isProfileCompleted'] as bool? ?? false,
      hasSkippedOnboarding: map['hasSkippedOnboarding'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'email': email,
      'username': username,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'coverUrl': coverUrl,
      'bio': bio,
      'age': age,
      'country': country,
      'favoriteQuote': favoriteQuote,
      'animeTwin': animeTwin,
      'socialLinks': socialLinks.map((link) => link.toMap()).toList(),
      'favoriteAnimes': favoriteAnimes,
      'favoriteAnimeIds': favoriteAnimeIds,
      'profileVisibility': profileVisibility,
      'activityVisibility': activityVisibility,
      'whoCanMessageMe': whoCanMessageMe,
      'sectionPrivacy': sectionPrivacy.toMap(),
      'createdAt': createdAt,
      'isProfileCompleted': isProfileCompleted,
      'hasSkippedOnboarding': hasSkippedOnboarding,
    };
  }

  PubgetUser copyWith({
    String? username,
    String? displayName,
    String? avatarUrl,
    String? coverUrl,
    String? bio,
    int? age,
    bool clearAge = false,
    String? country,
    String? favoriteQuote,
    String? animeTwin,
    List<ProfileSocialLink>? socialLinks,
    List<String>? favoriteAnimes,
    List<String>? favoriteAnimeIds,
    String? profileVisibility,
    String? activityVisibility,
    String? whoCanMessageMe,
    ProfileSectionPrivacy? sectionPrivacy,
    int? totalRespect,
    int? fansCount,
    bool? isProfileCompleted,
    bool? hasSkippedOnboarding,
  }) {
    return PubgetUser(
      id: id,
      email: email,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      bio: bio ?? this.bio,
      age: clearAge ? null : (age ?? this.age),
      country: country ?? this.country,
      favoriteQuote: favoriteQuote ?? this.favoriteQuote,
      animeTwin: animeTwin ?? this.animeTwin,
      socialLinks: socialLinks ?? this.socialLinks,
      favoriteAnimes: favoriteAnimes ?? this.favoriteAnimes,
      favoriteAnimeIds: favoriteAnimeIds ?? this.favoriteAnimeIds,
      profileVisibility: profileVisibility ?? this.profileVisibility,
      activityVisibility: activityVisibility ?? this.activityVisibility,
      whoCanMessageMe: whoCanMessageMe ?? this.whoCanMessageMe,
      sectionPrivacy: sectionPrivacy ?? this.sectionPrivacy,
      totalRespect: totalRespect ?? this.totalRespect,
      fansCount: fansCount ?? this.fansCount,
      createdAt: createdAt,
      isProfileCompleted: isProfileCompleted ?? this.isProfileCompleted,
      hasSkippedOnboarding: hasSkippedOnboarding ?? this.hasSkippedOnboarding,
    );
  }

  static List<ProfileSocialLink> _linksFrom(Object? raw) {
    if (raw is! List<Object?>) return const <ProfileSocialLink>[];
    return raw
        .whereType<Map>()
        .map(
          (item) => ProfileSocialLink.fromMap(Map<String, dynamic>.from(item)),
        )
        .where((link) => link.url.isNotEmpty)
        .toList(growable: false);
  }

  static DateTime? _dateFrom(Object? value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static int _intFrom(Object? value) => value is num ? value.toInt() : 0;

  static int? _optionalInt(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}
