import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Result returned by [MediaCompressor].
final class MediaCompressionResult {
  const MediaCompressionResult({
    required this.bytes,
    required this.contentType,
    this.width,
    this.height,
  });

  final Uint8List bytes;
  final String contentType;
  final int? width;
  final int? height;
}

/// Compresses still images before upload. Video and audio are never rewritten
/// by this layer; animated GIFs are preserved byte-for-byte to avoid flattening
/// animation into a single frame.
abstract interface class MediaCompressor {
  Future<MediaCompressionResult> compressImage(
    Uint8List bytes, {
    required String sourceContentType,
    required int targetBytes,
  });
}

/// Pure-Dart image compressor. Runs decoding/resizing off the UI isolate on
/// native platforms and retains the original if recompression is not smaller.
final class DefaultMediaCompressor implements MediaCompressor {
  const DefaultMediaCompressor();

  @override
  Future<MediaCompressionResult> compressImage(
    Uint8List bytes, {
    required String sourceContentType,
    required int targetBytes,
  }) async {
    if (bytes.isEmpty || targetBytes <= 0) {
      throw const FormatException('Invalid image compression input.');
    }
    // The image package decodes GIF to a single frame. Never flatten animated
    // content: keep GIFs unchanged and let the upload hard-limit decide.
    if (sourceContentType == 'image/gif') {
      return MediaCompressionResult(
        bytes: bytes,
        contentType: sourceContentType,
      );
    }
    return compute<_CompressionInput, MediaCompressionResult>(
      _compressImageInBackground,
      _CompressionInput(
        bytes: bytes,
        contentType: sourceContentType,
        targetBytes: targetBytes,
      ),
    );
  }
}

final class _CompressionInput {
  const _CompressionInput({
    required this.bytes,
    required this.contentType,
    required this.targetBytes,
  });

  final Uint8List bytes;
  final String contentType;
  final int targetBytes;
}

MediaCompressionResult _compressImageInBackground(_CompressionInput input) {
  final decoded = img.decodeImage(input.bytes);
  if (decoded == null) {
    throw const FormatException('The image could not be decoded.');
  }

  var working = img.bakeOrientation(decoded);
  final originalWidth = working.width;
  final originalHeight = working.height;
  var quality = 86;
  Uint8List best = input.bytes;
  var bestWidth = originalWidth;
  var bestHeight = originalHeight;
  final mime = input.contentType;

  Uint8List encode(img.Image image, int jpegQuality) {
    switch (mime) {
      case 'image/jpeg':
        return Uint8List.fromList(
          img.encodeJpg(image, quality: jpegQuality, chroma: img.JpegChroma.yuv420),
        );
      case 'image/png':
        return Uint8List.fromList(img.encodePng(image, level: 7));
      case 'image/webp':
        return Uint8List.fromList(
          img.encodeWebP(image, lossless: false, quality: jpegQuality),
        );
      default:
        return input.bytes;
    }
  }

  // Reduce dimensions progressively; JPEG/WebP quality is lowered only after
  // resizing. Keep aspect ratio and never upscale.
  for (var attempt = 0; attempt < 8; attempt++) {
    if (attempt > 0) {
      final nextWidth = (working.width * 0.85).round().clamp(1, working.width).toInt();
      working = img.copyResize(
        working,
        width: nextWidth,
        interpolation: img.Interpolation.average,
      );
      quality = (quality - 5).clamp(55, 86).toInt();
    }
    final candidate = encode(working, quality);
    if (candidate.length < best.length) {
      best = candidate;
      bestWidth = working.width;
      bestHeight = working.height;
    }
    if (best.length <= input.targetBytes) break;
  }

  // PNG may not compress smaller, in which case the caller will enforce its
  // hard ceiling. Report the true dimensions of the bytes we return.
  if (identical(best, input.bytes) || best.length == input.bytes.length) {
    return MediaCompressionResult(
      bytes: input.bytes,
      contentType: mime,
      width: originalWidth,
      height: originalHeight,
    );
  }
  return MediaCompressionResult(
    bytes: best,
    contentType: mime,
    width: bestWidth,
    height: bestHeight,
  );
}
