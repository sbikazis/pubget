// Magic-byte sniffing for the proxied upload path.
//
// The declared content type is a claim. When the worker actually holds the
// bytes (proxied upload) it also checks the real container header, so a file
// cannot be stored as an image while being, say, HTML.
//
// Presigned uploads cannot be inspected this way (the bytes never reach the
// worker) — that is a documented trade-off of direct-to-R2 uploads.

const SIGNATURES = [
  { kind: 'image', subtype: 'jpeg', bytes: [0xff, 0xd8, 0xff] },
  { kind: 'image', subtype: 'png', bytes: [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a] },
  { kind: 'image', subtype: 'gif', bytes: [0x47, 0x49, 0x46, 0x38] },
  // RIFF....WEBP
  {
    kind: 'image',
    subtype: 'webp',
    bytes: [0x52, 0x49, 0x46, 0x46],
    extra: { offset: 8, bytes: [0x57, 0x45, 0x42, 0x50] },
  },
  // ....ftyp{isom,iso2,mp42,avc1,mmp4,...}
  {
    kind: 'reels',
    subtype: 'mp4',
    bytes: [0x66, 0x74, 0x79, 0x70],
    offset: 4,
  },
  { kind: 'reels', subtype: 'webm', bytes: [0x1a, 0x45, 0xdf, 0xa3] },
  // MP3: ID3 tag or MPEG frame sync.
  { kind: 'audio', subtype: 'mp3-id3', bytes: [0x49, 0x44, 0x33] },
  // ADTS AAC.
  { kind: 'audio', subtype: 'aac', bytes: [0xff, 0xf1] },
  { kind: 'audio', subtype: 'ogg', bytes: [0x4f, 0x67, 0x67, 0x53] },
];

function startsWith(bytes, offset, signature) {
  if (bytes.length < offset + signature.length) return false;
  for (let i = 0; i < signature.length; i++) {
    if (bytes[offset + i] !== signature[i]) return false;
  }
  return true;
}

/**
 * @param {Uint8Array} bytes first ~32 bytes of the file
 * @returns {{ kind: string, subtype: string } | null}
 */
export function sniff(bytes) {
  for (const spec of SIGNATURES) {
    const offset = spec.offset || 0;
    if (!startsWith(bytes, offset, spec.bytes)) continue;
    if (spec.extra && !startsWith(bytes, spec.extra.offset, spec.extra.bytes)) continue;
    return { kind: spec.kind, subtype: spec.subtype };
  }
  // MPEG frame sync (0xFF 0xEx/0xFx) as a fallback for bare MP3.
  if (bytes.length >= 2 && bytes[0] === 0xff && (bytes[1] & 0xe0) === 0xe0) {
    return { kind: 'audio', subtype: 'mpeg' };
  }
  return null;
}

/**
 * Checks that the declared kind matches what the bytes actually are.
 * `mov` and `m4a` are container-ambiguous (both are ISO-BMFF), so a `ftyp`
 * header is accepted for either video or audio.
 */
export function matchesDeclaredKind(bytes, declaredKind) {
  const detected = sniff(bytes);
  if (!detected) return { ok: false, reason: 'unrecognized' };
  if (detected.kind === declaredKind) return { ok: true, detected };
  if (detected.subtype === 'mp4' && declaredKind === 'audio') {
    return { ok: true, detected };
  }
  return { ok: false, reason: 'kind-mismatch', detected };
}
