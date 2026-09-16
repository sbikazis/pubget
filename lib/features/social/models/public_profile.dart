import 'profile_section_privacy.dart';
import 'profile_social_link.dart';

final class PublicProfile {
  const PublicProfile({
    required this.uid,
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
    this.totalRespect = 0,
    this.fansCount = 0,
    this.equippedFrameId,
    this.equippedBadgeId,
    this.equippedNameplateId,
    this.favoriteAnimeIds = const <String>[],
    this.favoriteAnimes = const <String>[],
    this.sectionPrivacy = ProfileSectionPrivacy.public,
    this.createdAt,
  });

  final String uid;
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
  final int totalRespect;
  final int fansCount;
  final String? equippedFrameId;
  final String? equippedBadgeId;
  final String? equippedNameplateId;
  final List<String> favoriteAnimeIds;
  final List<String> favoriteAnimes;
  final ProfileSectionPrivacy sectionPrivacy;
  final DateTime? createdAt;

  factory PublicProfile.fromMap(Map<String, dynamic> map, {String? uid}) {
    return PublicProfile(
      uid: uid ?? map['uid'] as String? ?? '',
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
      favoriteAnimes:
          (map['favoriteAnimes'] as List<Object?>?)
              ?.whereType<String>()
              .toList(growable: false) ??
          const <String>[],
      sectionPrivacy: ProfileSectionPrivacy.fromMap(
        map['sectionPrivacy'] is Map<String, dynamic>
            ? map['sectionPrivacy'] as Map<String, dynamic>
            : null,
      ),
      createdAt: _date(map['createdAt']),
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

  static int? _optionalInt(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static String? _optionalId(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static DateTime? _date(Object? value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
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
}
