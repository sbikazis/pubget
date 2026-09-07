final class PublicProfile {
  const PublicProfile({
    required this.uid,
    this.username,
    this.displayName,
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
  final String? displayName;
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
      displayName: map['displayName'] as String?,
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

  /// Name shown as the primary line. Prefers a real display name, else username.
  String primaryName({String fallback = 'Pubget user'}) {
    final display = displayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final user = username?.trim();
    if (user != null && user.isNotEmpty) return user;
    return fallback;
  }

  /// `@username` only when it is distinct from the primary name.
  String? get distinctHandle {
    final user = username?.trim();
    if (user == null || user.isEmpty) return null;
    final display = displayName?.trim();
    if (display == null || display.isEmpty) return null;
    final normalizedUser = user.toLowerCase();
    final normalizedDisplay = display.toLowerCase();
    if (normalizedDisplay == normalizedUser) return null;
    if (normalizedDisplay == '@$normalizedUser') return null;
    return '@$user';
  }

  static int _int(Object? value) => value is num ? value.toInt() : 0;

  static String? _optionalId(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
