/// Optional social / external link shown on a Pubget profile.
final class ProfileSocialLink {
  const ProfileSocialLink({
    required this.url,
    this.label,
    this.platform,
  });

  final String url;
  final String? label;
  final String? platform;

  factory ProfileSocialLink.fromMap(Map<String, dynamic> map) {
    return ProfileSocialLink(
      url: (map['url'] as String? ?? '').trim(),
      label: _clean(map['label'] as String?),
      platform: _clean(map['platform'] as String?),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'url': url.trim(),
    if (label != null) 'label': label,
    if (platform != null) 'platform': platform,
  };

  String get resolvedPlatform {
    final explicit = platform?.trim().toLowerCase();
    if (explicit != null && explicit.isNotEmpty && explicit != 'other') {
      return explicit;
    }
    return detectPlatform(url);
  }

  String get displayLabel {
    final custom = label?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    final host = Uri.tryParse(url)?.host.replaceFirst(RegExp(r'^www\.'), '');
    if (host != null && host.isNotEmpty) return host;
    return resolvedPlatform;
  }

  static String detectPlatform(String rawUrl) {
    final lower = rawUrl.trim().toLowerCase();
    if (lower.contains('twitter.com') || lower.contains('x.com')) {
      return 'x';
    }
    if (lower.contains('instagram.com')) return 'instagram';
    if (lower.contains('tiktok.com')) return 'tiktok';
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      return 'youtube';
    }
    if (lower.contains('discord.gg') || lower.contains('discord.com')) {
      return 'discord';
    }
    if (lower.contains('telegram.me') || lower.contains('t.me')) {
      return 'telegram';
    }
    if (lower.contains('myanimelist.net')) return 'mal';
    if (lower.contains('anilist.co')) return 'anilist';
    return 'other';
  }

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
