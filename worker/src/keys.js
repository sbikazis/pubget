// Key minting and parsing for `{folder}/{uid}/{uuid}.{ext}` keys.
//
// The client never supplies a path or a file name: the worker always builds
// the key, so a raw user file name can never reach the bucket, and the owner
// segment is always the authenticated uid.

import { FOLDER_TO_KIND, KINDS, normalizeExtension } from './kinds.js';

const SEGMENT_RE = /^[A-Za-z0-9_-]+$/;
const NAME_RE = /^[A-Za-z0-9_-]+\.[A-Za-z0-9]+$/;

export function buildKey({ kind, uid, extension, uuid }) {
  const spec = KINDS[kind];
  if (!spec) throw new Error(`unsupported kind: ${kind}`);
  const ext = normalizeExtension(extension);
  return `${spec.folder}/${uid}/${uuid}.${ext}`;
}

/** Parses a key into its parts, or null when it is malformed. */
export function parseKey(key) {
  if (typeof key !== 'string') return null;
  const parts = key.split('/');
  if (parts.length !== 3) return null;
  const [folder, uid, name] = parts;
  const kind = FOLDER_TO_KIND[folder];
  if (!kind) return null;
  if (!SEGMENT_RE.test(uid)) return null;
  if (!NAME_RE.test(name)) return null;
  return { kind, folder, uid, name };
}

export function keyOwnedBy(key, uid) {
  const parsed = parseKey(key);
  return parsed !== null && parsed.uid === uid;
}

/** True when the key's extension is allowed for its kind. */
export function keyMatchesKindRules(key) {
  const parsed = parseKey(key);
  if (!parsed) return false;
  const spec = KINDS[parsed.kind];
  const dot = parsed.name.lastIndexOf('.');
  const ext = normalizeExtension(parsed.name.slice(dot + 1));
  return spec.extensions.includes(ext);
}
