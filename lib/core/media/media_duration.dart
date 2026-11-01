import 'dart:typed_data';

import 'media_kind.dart';

/// Reads the real duration out of the container bytes.
///
/// Returns null when the format is unsupported or the duration cannot be
/// derived — callers must treat null as "unverified", never as "short
/// enough". File extensions and client-declared durations are not evidence.
Duration? parseMediaDuration(Uint8List bytes, MediaKind kind) {
  switch (kind) {
    case MediaKind.image:
      return null;
    case MediaKind.reels:
      return _parseIsoBmffDuration(bytes) ?? _parseMatroskaDuration(bytes);
    case MediaKind.audio:
      return _parseIsoBmffDuration(bytes) ??
          _parseMp3Duration(bytes) ??
          _parseOggDuration(bytes);
  }
}

/// ISO Base Media File Format (mp4/mov/m4a): walk top-level boxes to `moov`,
/// then read `mvhd`'s timescale/duration.
Duration? _parseIsoBmffDuration(Uint8List bytes) {
  final moov = _findBoxPayload(bytes, 0, bytes.length, 'moov');
  if (moov == null) return null;
  final payload = _findBoxPayload(bytes, moov.start, moov.end, 'mvhd');
  if (payload == null) return null;

  var cursor = payload.start;
  if (cursor + 4 > payload.end) return null;
  final version = bytes[cursor];
  cursor += 4; // consume version(1) + flags(3)

  // mvhd then holds creation_time, modification_time, timescale, duration.
  int timescale;
  int duration;
  if (version == 1) {
    // creation(8) + modification(8) + timescale(4) + duration(8) = 28 bytes.
    if (cursor + 28 > payload.end) return null;
    timescale = _readUint32(bytes, cursor + 16);
    duration = _readUint64(bytes, cursor + 20);
  } else {
    // creation(4) + modification(4) + timescale(4) + duration(4) = 16 bytes.
    if (cursor + 16 > payload.end) return null;
    timescale = _readUint32(bytes, cursor + 8);
    duration = _readUint32(bytes, cursor + 12);
  }
  if (timescale <= 0 || duration == 0 || duration == 0xffffffff) return null;
  return Duration(microseconds: (duration * 1000000) ~/ timescale);
}

final class _BoxRange {
  const _BoxRange(this.start, this.end);
  final int start;
  final int end;
}

/// Finds [type] among sibling boxes in [from,until) and returns its payload
/// range, or null when the box is absent.
_BoxRange? _findBoxPayload(
  Uint8List bytes,
  int from,
  int until,
  String type,
) {
  var cursor = from;
  while (cursor + 8 <= until) {
    var size = _readUint32(bytes, cursor);
    final boxType = String.fromCharCodes(bytes, cursor + 4, cursor + 8);
    var headerSize = 8;
    if (size == 1) {
      if (cursor + 16 > until) return null;
      size = _readUint64(bytes, cursor + 8);
      headerSize = 16;
    } else if (size == 0) {
      size = until - cursor;
    }
    if (size < headerSize || cursor + size > until) return null;
    final payloadStart = cursor + headerSize;
    final payloadEnd = cursor + size;
    if (boxType == type) {
      return _BoxRange(payloadStart, payloadEnd);
    }
    cursor = payloadEnd;
  }
  return null;
}

/// Matroska/WebM: read Segment → Info → Duration (float, in TimecodeScale
/// units of 1 ms by default).
Duration? _parseMatroskaDuration(Uint8List bytes) {
  final duration = _readEbmlFloatAfterId(bytes, 'Duration');
  if (duration == null || duration.isNaN || duration <= 0) return null;
  return Duration(microseconds: (duration * 1000).round());
}

Duration? _parseOggDuration(Uint8List bytes) {
  // Best-effort: Ogg needs the last page's granule position, which a prefix
  // read cannot provide. Unverified audio is governed by MediaLimits policy.
  return null;
}

/// MPEG audio duration from the first frame header's bitrate (CBR
/// estimate). Good enough to reject an oversized file; flagged approximate
/// in the caller's docs.
Duration? _parseMp3Duration(Uint8List bytes) {
  var offset = 0;
  if (bytes.length > 10 &&
      bytes[0] == 0x49 && // 'I'
      bytes[1] == 0x44 && // 'D'
      bytes[2] == 0x33) {
    // ID3v2 size is a 28-bit syncsafe integer.
    final size = ((bytes[6] & 0x7f) << 21) |
        ((bytes[7] & 0x7f) << 14) |
        ((bytes[8] & 0x7f) << 7) |
        (bytes[9] & 0x7f);
    offset = 10 + size;
  }
  while (offset + 4 <= bytes.length) {
    if (bytes[offset] == 0xff && (bytes[offset + 1] & 0xe0) == 0xe0) {
      final header = _MpegAudioHeader.parse(bytes, offset);
      if (header != null) {
        final audioBytes = bytes.length - offset;
        final bits = audioBytes * 8;
        final micros = (bits * 1000000) ~/ header.bitrateBitsPerSecond;
        return Duration(microseconds: micros);
      }
    }
    offset++;
  }
  return null;
}

final class _MpegAudioHeader {
  const _MpegAudioHeader(this.bitrateBitsPerSecond);

  final int bitrateBitsPerSecond;

  static _MpegAudioHeader? parse(Uint8List bytes, int offset) {
    final b1 = bytes[offset + 1];
    final b2 = bytes[offset + 2];
    final versionBits = (b1 >> 3) & 0x03; // 3 = MPEG1, 2 = MPEG2, 0 = MPEG2.5
    final layerBits = (b1 >> 1) & 0x03; // 1 = Layer III
    if (versionBits == 1 || layerBits != 1) return null;

    final bitrateIndex = (b2 >> 4) & 0x0f;
    if (bitrateIndex == 0 || bitrateIndex == 0x0f) return null;
    const mpeg1Layer3 = <int>[
      0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0,
    ];
    const mpeg2Layer3 = <int>[
      0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0,
    ];
    final table = versionBits == 3 ? mpeg1Layer3 : mpeg2Layer3;
    final kbps = table[bitrateIndex];
    if (kbps == 0) return null;
    return _MpegAudioHeader(kbps * 1000);
  }
}

/// Walks the EBML tree looking for an element with the ASCII ID [id] and
/// returns its value as a float.
double? _readEbmlFloatAfterId(Uint8List bytes, String id) {
  final target = <int>[for (final c in id.codeUnits) c];
  for (var i = 0; i + target.length < bytes.length; i++) {
    if (!_matchesAt(bytes, i, target)) continue;
    final infoStart = i + target.length;
    if (infoStart >= bytes.length) return null;
    final lengthByte = bytes[infoStart];
    if (lengthByte & 0x80 != 0x80) continue; // only 1-byte lengths supported
    final valueLength = lengthByte & 0x7f;
    if (valueLength == 0 || infoStart + 1 + valueLength > bytes.length) {
      continue;
    }
    final valueStart = infoStart + 1;
    if (valueLength == 4) {
      final bits = ByteData.sublistView(
        bytes,
        valueStart,
        valueStart + valueLength,
      );
      return bits.getFloat32(0, Endian.big);
    }
    if (valueLength == 8) {
      final bits = ByteData.sublistView(
        bytes,
        valueStart,
        valueStart + valueLength,
      );
      return bits.getFloat64(0, Endian.big);
    }
    return null;
  }
  return null;
}

bool _matchesAt(Uint8List bytes, int offset, List<int> pattern) {
  for (var i = 0; i < pattern.length; i++) {
    if (bytes[offset + i] != pattern[i]) return false;
  }
  return true;
}

int _readUint32(Uint8List bytes, int offset) =>
    (bytes[offset] << 24) |
    (bytes[offset + 1] << 16) |
    (bytes[offset + 2] << 8) |
    bytes[offset + 3];

int _readUint64(Uint8List bytes, int offset) {
  var value = 0;
  for (var i = 0; i < 8; i++) {
    value = (value << 8) | bytes[offset + i];
  }
  return value;
}
