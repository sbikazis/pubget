class R2Config {
  R2Config._();

  static const String accountId = 'ecfe62b9c4a9e3e2f683a07aa7e6035b';
  static const String bucketName = 'pubget-media';

  /// API Worker endpoint - update after deployment
  static const String apiBaseUrl = String.fromEnvironment(
    'R2_API_BASE_URL',
    defaultValue: 'https://pubget-api.workers.dev',
  );

  /// Media Worker endpoint - update after deployment
  static const String mediaBaseUrl = String.fromEnvironment(
    'R2_MEDIA_BASE_URL',
    defaultValue: 'https://pubget-media.workers.dev',
  );

  /// Get public URL for a key
  static String publicUrl(String key) {
    if (key.isEmpty) return '';
    final base = mediaBaseUrl.endsWith('/')
        ? mediaBaseUrl.substring(0, mediaBaseUrl.length - 1)
        : mediaBaseUrl;
    final cleanKey = key.startsWith('/') ? key.substring(1) : key;
    return '$base/$cleanKey';
  }

  /// Get presigned upload URL endpoint
  static String get presignUrl => '$apiBaseUrl/upload/presign';

  /// Get complete upload endpoint
  static String get completeUploadUrl => '$apiBaseUrl/upload/complete';

  /// Get delete endpoint
  static String get deleteUrl => '$apiBaseUrl/files';
}
