final class PublicProfile {
  const PublicProfile({
    required this.uid,
    this.username,
    this.avatarUrl,
    this.bio,
    this.totalRespect = 0,
    this.fansCount = 0,
  });

  final String uid;
  final String? username;
  final String? avatarUrl;
  final String? bio;
  final int totalRespect;
  final int fansCount;

  factory PublicProfile.fromMap(Map<String, dynamic> map, {String? uid}) {
    return PublicProfile(
      uid: uid ?? map['uid'] as String? ?? '',
      username: map['username'] as String?,
      avatarUrl: map['avatarUrl'] as String?,
      bio: map['bio'] as String?,
      totalRespect: _int(map['totalRespect']),
      fansCount: _int(map['fansCount']),
    );
  }

  static int _int(Object? value) => value is num ? value.toInt() : 0;
}
