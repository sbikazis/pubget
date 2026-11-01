import 'dart:typed_data';

import '../errors/failure.dart';
import 'media_kind.dart';
import 'media_limits.dart';

/// What the file's bytes actually claim to be, independent of the file name
/// or the client-supplied Content-Type.
final class MediaSignature {
  const MediaSignature({
    required this.kind,
    required this.contentType,
    required this.extension,
  });

  final MediaKind kind;
  final String contentType;
  final String extension;
}

/// Detects the media kind from leading bytes (magic numbers), or null when
/// the content is not one of the accepted formats.
///
/// The extension and Content-Type are never trusted on their own: a `.jpg`
/// that is really an executable must not pass because it was renamed.
MediaSignature? sniffMediaSignature(Uint8List bytes) {
  if (bytes.length < 12) return null;

  if (_startsWith(bytes, const [0xff, 0xd8, 0xff])) {
    return const MediaSignature(
      kind: MediaKind.image,
      contentType: 'image/jpeg',
      extension: 'jpg',
    );
  }
  if (_startsWith(bytes, const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) {
    return const MediaSignature(
      kind: MediaKind.image,
      contentType: 'image/png',
      extension: 'png',
    );
  }
  if (_ascii(bytes, 0, 6) == 'GIF87a' || _ascii(bytes, 0, 6) == 'GIF89a') {
    return const MediaSignature(
      kind: MediaKind.image,
      contentType: 'image/gif',
      extension: 'gif',
    );
  }
  if (_ascii(bytes, 0, 4) == 'RIFF' && _ascii(bytes, 8, 4) == 'WEBP') {
    return const MediaSignature(
      kind: MediaKind.image,
      contentType: 'image/webp',
      extension: 'webp',
    );
  }
  if (_ascii(bytes, 4, 4) == 'ftyp') {
    final brand = _ascii(bytes, 8, 4) ?? '';
    if (brand.startsWith('qt')) {
      return const MediaSignature(
        kind: MediaKind.reels,
        contentType: 'video/quicktime',
        extension: 'mov',
      );
    }
    return const MediaSignature(
      kind: MediaKind.reels,
      contentType: 'video/mp4',
      extension: 'mp4',
    );
  }
  if (_startsWith(bytes, const [0x1a, 0x45, 0xdf, 0xa3])) {
    return const MediaSignature(
      kind: MediaKind.reels,
      contentType: 'video/webm',
      extension: 'webm',
    );
  }
  if (_ascii(bytes, 0, 3) == 'ID3' || _isMp3Sync(bytes, 0)) {
    return const MediaSignature(
      kind: MediaKind.audio,
      contentType: 'audio/mpeg',
      extension: 'mp3',
    );
  }
  if (_isAdtsAac(bytes)) {
    return const MediaSignature(
      kind: MediaKind.audio,
      contentType: 'audio/aac',
      extension: 'aac',
    );
  }
  if (_ascii(bytes, 0, 4) == 'OggS') {
    return const MediaSignature(
      kind: MediaKind.audio,
      contentType: 'audio/ogg',
      extension: 'ogg',
    );
  }
  return null;
}

/// Outcome of [validateMediaUpload]: either the detected [signature] (when
/// the upload may proceed) or the [failure] to surface. Never both, never
/// neither.
final class MediaValidationResult {
  const MediaValidationResult.accepted(this.signature) : failure = null;
  const MediaValidationResult.rejected(this.failure) : signature = null;

  final MediaSignature? signature;
  final Failure? failure;

  bool get isAccepted => failure == null;
}

/// Pre-flight validation for an upload about to happen.
///
/// Checks, in order: magic bytes → declared kind → claimed Content-Type →
/// declared extension → hard size ceiling. Duration is validated by the
/// caller because it needs container parsing (`media_duration.dart`) and
/// kind-specific policy. Never throws.
MediaValidationResult validateMediaUpload({
  required MediaKind kind,
  required Uint8List bytes,
  required String claimedContentType,
  required MediaLimits limits,
  String? declaredExtension,
}) {
  if (bytes.isEmpty) {
    return const MediaValidationResult.rejected(
      ValidationError('The file is empty.'),
    );
  }

  final signature = sniffMediaSignature(bytes);
  if (signature == null) {
    return const MediaValidationResult.rejected(
      ValidationError('This file type is not supported.'),
    );
  }
  if (signature.kind != kind) {
    return MediaValidationResult.rejected(
      ValidationError(
        'The file contents are ${signature.kind.folder}, not ${kind.folder}.',
      ),
    );
  }
  if (!kind.allowsContentType(signature.contentType)) {
    return const MediaValidationResult.rejected(
      ValidationError('This file type is not supported.'),
    );
  }

  final claimed = normalizeContentType(claimedContentType);
  if (claimed.isNotEmpty &&
      !kind.allowsContentType(claimed) &&
      claimed != signature.contentType) {
    return MediaValidationResult.rejected(
      ValidationError('Declared content type "$claimed" is not allowed.'),
    );
  }

  if (declaredExtension != null && declaredExtension.isNotEmpty) {
    final normalized = declaredExtension.toLowerCase().replaceAll('.', '');
    final canonical = normalized == 'jpeg' ? 'jpg' : normalized;
    if (!kind.allowsExtension(canonical)) {
      return MediaValidationResult.rejected(
        ValidationError('File extension "$normalized" is not allowed.'),
      );
    }
    if (canonical != signature.extension) {
      return MediaValidationResult.rejected(
        ValidationError(
          'File extension "$normalized" does not match the file contents.',
        ),
      );
    }
  }

  final maxBytes = limits.maxBytesFor(kind);
  if (bytes.length > maxBytes) {
    return MediaValidationResult.rejected(
      ValidationError(
        'This file is ${_formatMb(bytes.length)} — the limit for '
        '${kind.folder} is ${_formatMb(maxBytes)}.',
      ),
    );
  }
  return MediaValidationResult.accepted(signature);
}

String _formatMb(int bytes) {
  final mb = bytes / (1024 * 1024);
  return '${mb.toStringAsFixed(mb >= 10 ? 0 : 1)} MB';
}

bool _startsWith(Uint8List bytes, List<int> prefix) {
  if (bytes.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[i] != prefix[i]) return false;
  }
  return true;
}

String? _ascii(Uint8List bytes, int offset, int length) {
  if (bytes.length < offset + length) return null;
  final buffer = StringBuffer();
  for (var i = offset; i < offset + length; i++) {
    buffer.writeCharCode(bytes[i]);
  }
  return buffer.toString();
}

bool _isMp3Sync(Uint8List bytes, int offset) {
  if (bytes.length < offset + 2) return false;
  if (bytes[offset] != 0xff) return false;
  final second = bytes[offset + 1];
  if ((second & 0xe0) != 0xe0) return false;
  // Exclude MPEG frame syncs that belong to other formats we already handle
  // (0xFF 0xF? are ADTS AAC frames).
  return !_isAdtsAac(bytes);
}

bool _isAdtsAac(Uint8List bytes) {
  if (bytes.length < 2) return false;
  if (bytes[0] != 0xff) return false;
  final second = bytes[1];
  return (second & 0xf6) == 0xf0;
}
