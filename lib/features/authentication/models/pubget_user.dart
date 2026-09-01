final class PubgetUser {
  const PubgetUser({
    required this.id,
    required this.email,
    this.username,
    this.displayName,
    this.avatarUrl,
    this.bio,
    this.favoriteAnimes = const <String>[],
    this.favoriteAnimeIds = const <String>[],
    this.profileVisibility = 'public',
    this.activityVisibility = 'public',
    this.whoCanMessageMe = 'related',
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
  final String? bio;
  final List<String> favoriteAnimes;
  final List<String> favoriteAnimeIds;
  final String profileVisibility;
  final String activityVisibility;
  final String whoCanMessageMe;
  final int totalRespect;
  final int fansCount;
  final DateTime createdAt;
  final bool isProfileCompleted;
  final bool hasSkippedOnboarding;

  factory PubgetUser.fromMap(Map<String, dynamic> map, {String? id}) {
    return PubgetUser(
      id: id ?? map['id'] as String? ?? '',
      email: map['email'] as String? ?? '',
      username: map['username'] as String?,
      displayName: map['displayName'] as String?,
      avatarUrl: map['avatarUrl'] as String?,
      bio: map['bio'] as String?,
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
      'bio': bio,
      'favoriteAnimes': favoriteAnimes,
      'favoriteAnimeIds': favoriteAnimeIds,
      'profileVisibility': profileVisibility,
      'activityVisibility': activityVisibility,
      'whoCanMessageMe': whoCanMessageMe,
      'createdAt': createdAt,
      'isProfileCompleted': isProfileCompleted,
      'hasSkippedOnboarding': hasSkippedOnboarding,
    };
  }

  PubgetUser copyWith({
    String? username,
    String? displayName,
    String? avatarUrl,
    String? bio,
    List<String>? favoriteAnimes,
    List<String>? favoriteAnimeIds,
    String? profileVisibility,
    String? activityVisibility,
    String? whoCanMessageMe,
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
      bio: bio ?? this.bio,
      favoriteAnimes: favoriteAnimes ?? this.favoriteAnimes,
      favoriteAnimeIds: favoriteAnimeIds ?? this.favoriteAnimeIds,
      profileVisibility: profileVisibility ?? this.profileVisibility,
      activityVisibility: activityVisibility ?? this.activityVisibility,
      whoCanMessageMe: whoCanMessageMe ?? this.whoCanMessageMe,
      totalRespect: totalRespect ?? this.totalRespect,
      fansCount: fansCount ?? this.fansCount,
      createdAt: createdAt,
      isProfileCompleted: isProfileCompleted ?? this.isProfileCompleted,
      hasSkippedOnboarding: hasSkippedOnboarding ?? this.hasSkippedOnboarding,
    );
  }

  static DateTime? _dateFrom(Object? value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static int _intFrom(Object? value) => value is num ? value.toInt() : 0;
}
