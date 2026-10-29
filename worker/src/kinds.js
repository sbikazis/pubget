// Media kinds, their folder prefixes, and the exact types/extensions allowed.
//
// This mirrors lib/core/media/media_kind.dart. A video may never be stored
// under the images folder to dodge a size ceiling, which is why the folder is
// derived from the kind rather than supplied by the client.

export const DEFAULT_LIMITS = {
  images: 10 * 1024 * 1024, // 10 MB
  reels: 5 * 1024 * 1024, // 5 MB
  audio: 50 * 1024 * 1024, // 50 MB
};

export const KINDS = {
  image: {
    folder: 'images',
    contentTypes: ['image/jpeg', 'image/png', 'image/webp', 'image/gif'],
    extensions: ['jpg', 'jpeg', 'png', 'webp', 'gif'],
    limitKey: 'images',
  },
  reels: {
    folder: 'reels',
    contentTypes: ['video/mp4', 'video/webm', 'video/quicktime'],
    extensions: ['mp4', 'webm', 'mov'],
    limitKey: 'reels',
  },
  audio: {
    folder: 'audio',
    contentTypes: ['audio/mpeg', 'audio/aac', 'audio/ogg', 'audio/mp4'],
    extensions: ['mp3', 'aac', 'ogg', 'm4a'],
    limitKey: 'audio',
  },
};

export const FOLDER_TO_KIND = Object.fromEntries(
  Object.entries(KINDS).map(([kind, spec]) => [spec.folder, kind]),
);

// Normalizes aliases so `jpeg`/`jpg` and `audio/x-m4a`/`audio/mp4` agree
// without loosening the allowlist.
export function normalizeContentType(value) {
  if (typeof value !== 'string') return '';
  return value.split(';')[0].trim().toLowerCase();
}

export function normalizeExtension(value) {
  if (typeof value !== 'string') return '';
  const clean = value.replace(/^\./, '').trim().toLowerCase();
  if (clean === 'jpeg') return 'jpg';
  if (clean === 'x-m4a') return 'm4a';
  return clean;
}
