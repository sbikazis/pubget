"use strict";

/**
 * Fan Works media path and size contract.
 *
 * The GCS signer that used to live here is gone: Fan Works bytes now go to R2
 * through `r2FanWorksSigner.js`. These pure helpers remain because the R2
 * signer and the domain still need the exact same path grammar and limits,
 * and changing that grammar would orphan media published before the rebuild.
 */

/** Path tree that `storage.rules` gates for legacy objects. */
const MEDIA_ROOT = "fan_works";
const UPLOAD_SESSION_TTL_MS = 15 * 60 * 1000;
const READ_URL_TTL_MS = 3 * 60 * 1000;

/** Media roles that may hold a PDF, and therefore need the strictest path. */
const DOCUMENT_ROLES = Object.freeze(["document"]);

const ALLOWED_IMAGE_MIME = Object.freeze({
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
  "image/gif": "gif",
});

const DOCUMENT_MIME = "application/pdf";

const IMAGE_MAX_BYTES = 12 * 1024 * 1024;
const DOCUMENT_MAX_BYTES = 50 * 1024 * 1024;

function extensionFor(mime) {
  if (mime === DOCUMENT_MIME) return "pdf";
  return ALLOWED_IMAGE_MIME[mime] || null;
}

function maxBytesFor(mime) {
  return mime === DOCUMENT_MIME ? DOCUMENT_MAX_BYTES : IMAGE_MAX_BYTES;
}

/**
 * Builds the object path. The nonce makes every attempt a new object so a
 * retried upload can never overwrite a half-finished or already-published file.
 */
function buildMediaPath({ userId, workId, mediaId, mime, nonce }) {
  const ext = extensionFor(mime);
  if (!ext) return null;
  const safeUser = String(userId || "").replace(/[^A-Za-z0-9_-]/g, "");
  const safeWork = String(workId || "").replace(/[^A-Za-z0-9_-]/g, "");
  const safeMedia = String(mediaId || "").replace(/[^A-Za-z0-9_-]/g, "");
  const safeNonce = String(nonce || "").replace(/[^A-Za-z0-9]/g, "");
  if (!safeUser || !safeWork || !safeMedia || !safeNonce) return null;
  return `${MEDIA_ROOT}/${safeUser}/${safeWork}/${safeNonce}_${safeMedia}.${ext}`;
}

module.exports = Object.freeze({
  buildMediaPath,
  maxBytesFor,
  extensionFor,
  MEDIA_ROOT,
  UPLOAD_SESSION_TTL_MS,
  READ_URL_TTL_MS,
  DOCUMENT_ROLES,
  ALLOWED_IMAGE_MIME,
  DOCUMENT_MIME,
  IMAGE_MAX_BYTES,
  DOCUMENT_MAX_BYTES,
});
