// Read-path helpers: content-type resolution, HTTP Range parsing, and the
// immutable cache policy for content-addressed media keys.
//
// Keys are `{folder}/{uid}/{uuid}.{ext}`: the uuid makes every object name
// unique and never reused, so a long, immutable cache lifetime is safe — a
// changed file is always a new key.

export const CONTENT_TYPE_BY_EXT = {
  jpg: 'image/jpeg',
  jpeg: 'image/jpeg',
  png: 'image/png',
  webp: 'image/webp',
  gif: 'image/gif',
  mp4: 'video/mp4',
  webm: 'video/webm',
  mov: 'video/quicktime',
  mp3: 'audio/mpeg',
  aac: 'audio/aac',
  ogg: 'audio/ogg',
  m4a: 'audio/mp4',
};

export const IMMUTABLE_CACHE_CONTROL = 'public, max-age=31536000, immutable';

/** The best content type we can state for [key] given the stored [object]. */
export function contentTypeFor(key, object) {
  const fromMetadata = object?.httpMetadata?.contentType;
  if (fromMetadata && fromMetadata !== 'application/octet-stream') {
    return fromMetadata;
  }
  const dot = key.lastIndexOf('.');
  const ext = dot >= 0 ? key.slice(dot + 1).toLowerCase() : '';
  return CONTENT_TYPE_BY_EXT[ext] || fromMetadata || 'application/octet-stream';
}

/**
 * Parses a single-range `Range: bytes=…` header against a known [size].
 *
 * Returns:
 *   null                     — no header, or a form we ignore (serve full body)
 *   { unsatisfiable: true }  — syntactically valid but outside the object (416)
 *   { offset, length, end }  — a satisfiable byte range (206)
 */
export function parseRange(header, size) {
  if (typeof header !== 'string' || header.trim() === '') return null;
  const match = /^bytes=(\d*)-(\d*)$/.exec(header.trim());
  if (!match) return null;
  const [, startRaw, endRaw] = match;
  if (startRaw === '' && endRaw === '') return null;

  let start;
  let end;
  if (startRaw === '') {
    const suffix = Number.parseInt(endRaw, 10);
    if (!Number.isFinite(suffix) || suffix <= 0) return null;
    start = Math.max(0, size - suffix);
    end = size - 1;
  } else {
    start = Number.parseInt(startRaw, 10);
    end = endRaw === '' ? size - 1 : Number.parseInt(endRaw, 10);
  }
  if (!Number.isFinite(start) || !Number.isFinite(end)) return null;
  if (start >= size || start > end) return { unsatisfiable: true };
  end = Math.min(end, size - 1);
  return { offset: start, length: end - start + 1, end };
}
