import 'dart:typed_data';

/// Intrinsic pixel size of a raster image, read from the file header alone.
///
/// The chat needs a media bubble's aspect ratio *before* the server has finished
/// processing, otherwise the bubble is laid out at a placeholder ratio and then
/// resizes — the visible "jumpy, cramped" image the spec forbids. Decoding with
/// `ui.instantiateImageCodec` to measure would cost a full raster decode of a
/// 12MP photo (tens of megabytes) purely to read two integers, so the header is
/// parsed directly instead.
///
/// Returns `null` for formats this reader does not understand (notably HEIC/HEIF
/// on iOS) and for truncated or corrupt headers. Callers must fall back to a
/// neutral ratio in that case; the server-recorded dimensions reconcile the
/// bubble once processing finishes.
({int width, int height})? readImageDimensions(Uint8List bytes) {
  if (bytes.length < 10) return null;
  return _png(bytes) ?? _gif(bytes) ?? _jpeg(bytes) ?? _webp(bytes);
}

const List<int> _pngSignature = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

({int width, int height})? _png(Uint8List b) {
  for (var i = 0; i < 8; i++) {
    if (b[i] != _pngSignature[i]) return null;
  }
  // IHDR is mandatory and always first: length(4) type(4) width(4) height(4).
  if (b.length < 24) return null;
  final width = _be32(b, 16);
  final height = _be32(b, 20);
  return _valid(width, height);
}

({int width, int height})? _gif(Uint8List b) {
  if (b[0] != 0x47 || b[1] != 0x49 || b[2] != 0x46) return null; // "GIF"
  if (b.length < 10) return null;
  // Logical screen descriptor: width(2 LE) height(2 LE) at offset 6.
  return _valid(_le16(b, 6), _le16(b, 8));
}

({int width, int height})? _jpeg(Uint8List b) {
  if (b[0] != 0xFF || b[1] != 0xD8) return null; // SOI
  var offset = 2;
  final end = b.length - 1;
  while (offset < end) {
    if (b[offset] != 0xFF) {
      offset++;
      continue;
    }
    var marker = b[offset + 1];
    // Skip fill bytes and standalone markers (no payload).
    while (marker == 0xFF && offset + 2 < b.length) {
      offset++;
      marker = b[offset + 1];
    }
    if (marker == 0xD8 || marker == 0x01 ||
        (marker >= 0xD0 && marker <= 0xD7)) {
      offset += 2;
      continue;
    }
    if (offset + 3 >= b.length) return null;
    // Start-of-frame markers carry the frame size. 0xC4 (Huffman), 0xC8 (JPG) and
    // 0xCC (arithmetic coding) share the numeric range but are not SOF.
    final isStartOfFrame =
        (marker >= 0xC0 && marker <= 0xCF) &&
        marker != 0xC4 &&
        marker != 0xC8 &&
        marker != 0xCC;
    if (isStartOfFrame) {
      if (offset + 9 >= b.length) return null;
      // segment(2) precision(1) height(2 BE) width(2 BE)
      final height = _be16(b, offset + 5);
      final width = _be16(b, offset + 7);
      return _valid(width, height);
    }
    if (marker == 0xDA) return null; // start of scan: no SOF seen
    if (offset + 3 >= b.length) return null;
    final length = _be16(b, offset + 2);
    if (length < 2) return null;
    offset += 2 + length;
  }
  return null;
}

({int width, int height})? _webp(Uint8List b) {
  if (b.length < 30) return null;
  if (b[0] != 0x52 || b[1] != 0x49 || b[2] != 0x46 || b[3] != 0x46) {
    return null; // "RIFF"
  }
  if (b[8] != 0x57 || b[9] != 0x45 || b[10] != 0x42 || b[11] != 0x50) {
    return null; // "WEBP"
  }
  final format = String.fromCharCodes(b.sublist(12, 16));
  switch (format) {
    case 'VP8X': // extended: 24-bit canvas size, 14 bits per axis, LE
      final width = 1 + (b[24] | (b[25] << 8) | (b[26] << 16));
      final height = 1 + (b[27] | (b[28] << 8) | (b[29] << 16));
      return _valid(width, height);
    case 'VP8 ': // lossy: frame header, 14-bit dimensions after the sync code
      if (b.length < 30) return null;
      return _valid(
        _le16(b, 26) & 0x3FFF,
        _le16(b, 28) & 0x3FFF,
      );
    case 'VP8L': // lossless: 14-bit dimensions packed after the signature byte
      if (b.length < 25) return null;
      final bits = b[21] | (b[22] << 8) | (b[23] << 16) | (b[24] << 24);
      return _valid(
        (bits & 0x3FFF) + 1,
        ((bits >> 14) & 0x3FFF) + 1,
      );
    default:
      return null;
  }
}

({int width, int height})? _valid(int width, int height) {
  if (width <= 0 || height <= 0) return null;
  return (width: width, height: height);
}

int _be16(Uint8List b, int i) => (b[i] << 8) | b[i + 1];

int _be32(Uint8List b, int i) =>
    (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];

int _le16(Uint8List b, int i) => b[i] | (b[i + 1] << 8);
