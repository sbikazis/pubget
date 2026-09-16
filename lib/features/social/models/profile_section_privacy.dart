/// Per-section visibility for a Pubget life-report profile (SPEC §81).
final class ProfileSectionPrivacy {
  const ProfileSectionPrivacy({
    this.favorites = true,
    this.activity = true,
    this.friends = true,
    this.fans = true,
    this.works = true,
    this.groups = true,
    this.ratings = true,
    this.achievements = true,
  });

  final bool favorites;
  final bool activity;
  final bool friends;
  final bool fans;
  final bool works;
  final bool groups;
  final bool ratings;
  final bool achievements;

  static const public = ProfileSectionPrivacy();

  factory ProfileSectionPrivacy.fromMap(Map<String, dynamic>? map) {
    if (map == null) return public;
    return ProfileSectionPrivacy(
      favorites: map['favorites'] as bool? ?? true,
      activity: map['activity'] as bool? ?? true,
      friends: map['friends'] as bool? ?? true,
      fans: map['fans'] as bool? ?? true,
      works: map['works'] as bool? ?? true,
      groups: map['groups'] as bool? ?? true,
      ratings: map['ratings'] as bool? ?? true,
      achievements: map['achievements'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'favorites': favorites,
    'activity': activity,
    'friends': friends,
    'fans': fans,
    'works': works,
    'groups': groups,
    'ratings': ratings,
    'achievements': achievements,
  };

  ProfileSectionPrivacy copyWith({
    bool? favorites,
    bool? activity,
    bool? friends,
    bool? fans,
    bool? works,
    bool? groups,
    bool? ratings,
    bool? achievements,
  }) {
    return ProfileSectionPrivacy(
      favorites: favorites ?? this.favorites,
      activity: activity ?? this.activity,
      friends: friends ?? this.friends,
      fans: fans ?? this.fans,
      works: works ?? this.works,
      groups: groups ?? this.groups,
      ratings: ratings ?? this.ratings,
      achievements: achievements ?? this.achievements,
    );
  }
}
