import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Result of a compression attempt: bytes plus what they became.
final class CompressedMedia {
  const CompressedMedia({
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

/// Turns picked bytes into something that meets the size targets — or, when
/// that is impossible, into the smallest honest representation so the hard
/// ceiling check afterwards can reject it.
///
/// Compression never *guarantees* a size: the caller must still enforce the
/// hard limit on the returned bytes (see `MediaUploadService`).
abstract interface class MediaCompressor {
  Future<CompressedMedia> compressImage(
    Uint8List bytes, {
    String? sourceContentType,
    int? targetBytes,
  });
}

/// Image compression built on the pure-Dart `image` package (no platform
/// channel, works on every target including tests).
///
/// Strategy:
/// * already small enough → returned untouched (no extra generation loss);
/// * opaque image → JPEG with a descending quality ladder until the target
///   is met;
/// * image with alpha → PNG (JPEG would destroy transparency), which usually
///   stays above the photo target — the hard ceiling still applies.
final class ImagePackageMediaCompressor implements MediaCompressor {
  const ImagePackageMediaCompressor();

  static const List<int> _jpegQualityLadder = <int>[88, 74, 60, 48, 38, 30];
  static const int _maxDimension = 4096;

  @override
  Future<CompressedMedia> compressImage(
    Uint8List bytes, {
    String? sourceContentType,
    int? targetBytes,
  }) async {
    if (targetBytes == null || bytes.length <= targetBytes) {
      return _passthrough(bytes, sourceContentType);
    }

    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      // Undecodable input: hand it back unchanged so validation — which runs
      // on magic bytes — decides whether it may be uploaded at all.
      return _passthrough(bytes, sourceContentType);
    }

    var image = decoded;
    if (image.width > _maxDimension || image.height > _maxDimension) {
      image = img.copyResize(
        image,
        width: image.width >= image.height ? _maxDimension : null,
        height: image.height > image.width ? _maxDimension : null,
        interpolation: img.Interpolation.average,
      );
    }

    if (image.hasAlpha) {
      final png = Uint8List.fromList(img.encodePng(image));
      return CompressedMedia(
        bytes: png,
        contentType: 'image/png',
        width: image.width,
        height: image.height,
      );
    }

    Uint8List? encoded;
    for (final quality in _jpegQualityLadder) {
      encoded = Uint8List.fromList(img.encodeJpg(image, quality: quality));
      if (encoded.length <= targetBytes) break;
    }
    return CompressedMedia(
      bytes: encoded ?? Uint8List.fromList(img.encodeJpg(image, quality: 30)),
      contentType: 'image/jpeg',
      width: image.width,
      height: image.height,
    );
  }

  CompressedMedia _passthrough(Uint8List bytes, String? contentType) {
    return CompressedMedia(
      bytes: bytes,
      contentType: contentType ?? '',
    );
  }
}
