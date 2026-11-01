/// The kinds of media the unified media layer accepts, plus the storage
/// backend that actually holds the bytes.
///
/// The folder segment of every storage key is derived from [MediaKind], so a
/// key's prefix always tells you both what the object is and who owns it —
/// see `media_keys.dart`.
library;

/// Where bytes are physically stored.
///
/// Swapping the backend must never touch feature code: features depend on
/// [MediaRepository]/[MediaUploadService], never on a concrete provider.
enum MediaBackend {
  /// Firebase Cloud Storage (the default; its rules already gate every path).
  firebase,

  /// Cloudflare R2 behind the `worker/` service. Only selected when a worker
  /// URL is configured — see `resolveMediaBackendConfig`.
  r2,

  /// In-memory store used by tests and previews. Never for production bytes.
  memory,
}

/// Accepted media categories.
enum MediaKind {
  image(
    folder: 'images',
    contentTypes: <String>{'image/jpeg', 'image/png', 'image/webp', 'image/gif'},
    extensions: <String>{'jpg', 'jpeg', 'png', 'webp', 'gif'},
  ),

  /// Short-form video (Reels).
  reels(
    folder: 'reels',
    // video/quicktime is accepted beyond the required mp4/webm because iOS
    // captures .MOV; `storage.rules` already accepts the same three.
    contentTypes: <String>{'video/mp4', 'video/webm', 'video/quicktime'},
    extensions: <String>{'mp4', 'webm', 'mov'},
  ),

  audio(
    folder: 'audio',
    // audio/mp4 covers .m4a, which is what the recorder emits on iOS and
    // what `storage.rules` voices paths already allow.
    contentTypes: <String>{'audio/mpeg', 'audio/aac', 'audio/ogg', 'audio/mp4'},
    extensions: <String>{'mp3', 'aac', 'ogg', 'm4a'},
  );

  const MediaKind({
    required this.folder,
    required this.contentTypes,
    required this.extensions,
  });

  /// First path segment of every storage key of this kind.
  final String folder;

  /// Exact, lower-case MIME types accepted for this kind.
  final Set<String> contentTypes;

  /// File-name extensions accepted for this kind (normalized, no dot).
  final Set<String> extensions;

  /// Maps a storage-key folder back to its kind, or null when unknown.
  static MediaKind? fromFolder(String folder) {
    for (final kind in values) {
      if (kind.folder == folder) return kind;
    }
    return null;
  }

  /// True when [contentType] (with any `;参数` suffix stripped) is allowed.
  bool allowsContentType(String? contentType) {
    if (contentType == null) return false;
    final normalized = normalizeContentType(contentType);
    return contentTypes.contains(normalized);
  }

  /// True when [extension] (normalized, no dot) is allowed for this kind.
  bool allowsExtension(String extension) {
    return extensions.contains(extension.toLowerCase());
  }
}

/// Lower-cases [contentType] and drops codec/charset parameters, e.g.
/// `video/mp4; codecs="avc1.42E01E"` → `video/mp4`.
String normalizeContentType(String contentType) {
  final base = contentType.split(';').first.trim().toLowerCase();
  return base;
}

/// Extension of a file name, normalized to lower case without the dot.
/// Returns an empty string when there is no usable extension.
String extensionOfFileName(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) return '';
  return fileName.substring(dot + 1).toLowerCase();
}
