final class PublicProfile {
  const PublicProfile({
    required this.uid,
    this.username,
    this.avatarUrl,
    this.bio,
    this.totalRespect = 0,
    this.fansCount = 0,
    this.equippedFrameId,
    this.equippedBadgeId,
    this.equippedNameplateId,
    this.favoriteAnimeIds = const <String>[],
  });

  final String uid;
  final String? username;
  final String? avatarUrl;
  final String? bio;
  final int totalRespect;
  final int fansCount;
  final String? equippedFrameId;
  final String? equippedBadgeId;
  final String? equippedNameplateId;
  final List<String> favoriteAnimeIds;

  factory PublicProfile.fromMap(Map<String, dynamic> map, {String? uid}) {
    return PublicProfile(
      uid: uid ?? map['uid'] as String? ?? '',
      username: map['username'] as String?,
      avatarUrl: map['avatarUrl'] as String?,
      bio: map['bio'] as String?,
      totalRespect: _int(map['totalRespect']),
      fansCount: _int(map['fansCount']),
      equippedFrameId: _optionalId(map['equippedFrameId']),
      equippedBadgeId: _optionalId(map['equippedBadgeId']),
      equippedNameplateId: _optionalId(map['equippedNameplateId']),
      favoriteAnimeIds:
          (map['favoriteAnimeIds'] as List<Object?>?)
              ?.whereType<String>()
              .toList(growable: false) ??
          const <String>[],
    );
  }

  static int _int(Object? value) => value is num ? value.toInt() : 0;

  static String? _optionalId(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
