import 'dart:math';
import 'dart:typed_data';

import 'package:pubget/core/media/media_compressor.dart';
import 'package:pubget/core/media/media_keys.dart';
import 'package:pubget/core/media/media_kind.dart';
import 'package:pubget/core/media/media_storage_provider.dart';

/// A [MediaStorageProvider] whose failures are scripted per call.
final class FakeMediaStorageProvider implements MediaStorageProvider {
  FakeMediaStorageProvider({Random? random}) : _random = random ?? Random(7);

  final Random _random;

  /// Errors thrown by [upload] in order before it starts succeeding.
  final List<Object> uploadErrors = <Object>[];
  final List<Map<String, Object?>> uploadCalls = <Map<String, Object?>>[];
  final List<String> deletedKeys = <String>[];

  Object? deleteError;
  Object? resolveError;
  String urlPrefix = 'fake://';

  @override
  MediaBackend get backend => MediaBackend.memory;

  @override
  Future<String> upload({
    required String ownerUid,
    required MediaKind kind,
    required Uint8List bytes,
    required String contentType,
    required String extension,
    void Function(double progress)? onProgress,
  }) async {
    uploadCalls.add(<String, Object?>{
      'ownerUid': ownerUid,
      'kind': kind,
      'bytes': bytes,
      'contentType': contentType,
      'extension': extension,
    });
    if (uploadErrors.isNotEmpty) throw uploadErrors.removeAt(0);
    final key = buildMediaKey(
      kind: kind,
      ownerUid: ownerUid,
      extension: extension,
      random: _random,
    );
    onProgress?.call(1);
    return key;
  }

  @override
  Future<void> delete(String storageKey) async {
    if (deleteError != null) throw deleteError!;
    deletedKeys.add(storageKey);
  }

  @override
  Future<String> resolveUrl(String storageKey) async {
    if (resolveError != null) throw resolveError!;
    return '$urlPrefix$storageKey';
  }
}

/// A [MediaCompressor] that returns a scripted result instead of touching
/// pixels, so service logic can be tested without real image data.
final class FakeMediaCompressor implements MediaCompressor {
  FakeMediaCompressor({this.result});

  CompressedMedia? result;
  final List<Map<String, Object?>> calls = <Map<String, Object?>>[];

  @override
  Future<CompressedMedia> compressImage(
    Uint8List bytes, {
    String? sourceContentType,
    int? targetBytes,
  }) async {
    calls.add(<String, Object?>{
      'bytes': bytes,
      'sourceContentType': sourceContentType,
      'targetBytes': targetBytes,
    });
    final configured = result;
    if (configured != null) return configured;
    return CompressedMedia(
      bytes: bytes,
      contentType: sourceContentType ?? 'image/jpeg',
    );
  }
}

/// A minimal ISO-BMFF file: `ftyp` + `moov`(`mvhd`) carrying [seconds].
Uint8List buildMp4Bytes({
  required int seconds,
  int timescale = 1000,
  int extraPadding = 0,
}) {
  final ftyp = <int>[
    0x00, 0x00, 0x00, 0x18, // size 24
    0x66, 0x74, 0x79, 0x70, // 'ftyp'
    0x69, 0x73, 0x6F, 0x6D, // brand 'isom'
    0x00, 0x00, 0x00, 0x01, // minor version
    0x69, 0x73, 0x6F, 0x6D, // compatible 'isom'
    0x6D, 0x70, 0x34, 0x31, // 'mp41'
  ];

  final mvhdPayload = <int>[
    0x00, 0x00, 0x00, 0x00, // version 0 + flags
    0x00, 0x00, 0x00, 0x00, // creation time
    0x00, 0x00, 0x00, 0x00, // modification time
    (timescale >> 24) & 0xff, (timescale >> 16) & 0xff,
    (timescale >> 8) & 0xff, timescale & 0xff,
    (seconds * timescale >> 24) & 0xff, (seconds * timescale >> 16) & 0xff,
    (seconds * timescale >> 8) & 0xff, (seconds * timescale) & 0xff,
  ];
  final mvhdSize = 8 + mvhdPayload.length;
  final moovSize = 8 + mvhdSize;

  return Uint8List.fromList(<int>[
    ...ftyp,
    (moovSize >> 24) & 0xff, (moovSize >> 16) & 0xff,
    (moovSize >> 8) & 0xff, moovSize & 0xff,
    0x6D, 0x6F, 0x6F, 0x76, // 'moov'
    (mvhdSize >> 24) & 0xff, (mvhdSize >> 16) & 0xff,
    (mvhdSize >> 8) & 0xff, mvhdSize & 0xff,
    0x6D, 0x76, 0x68, 0x64, // 'mvhd'
    ...mvhdPayload,
    ...List<int>.filled(extraPadding, 0),
  ]);
}

/// 12-byte magic-byte prefixes for each accepted container.
final Uint8List jpegBytes = Uint8List.fromList(
  <int>[0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01],
);

final Uint8List pngBytes = Uint8List.fromList(
  <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d],
);

final Uint8List gifBytes = Uint8List.fromList(
  <int>[0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
);

final Uint8List webpBytes = Uint8List.fromList(
  <int>[0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50],
);

final Uint8List webmBytes = Uint8List.fromList(
  <int>[0x1a, 0x45, 0xdf, 0xa3, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
);

final Uint8List htmlBytes =
    Uint8List.fromList('<html><body>not an image</body></html>'.codeUnits);
