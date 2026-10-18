// Request validation for the worker.
//
// Everything here is pure and testable: it takes what the client claims and
// returns whether the operation may proceed. The size/type values are the
// same numbers as lib/core/media/media_limits.dart, storage.rules and
// lib/core/constants/limits.dart.

import { KINDS, normalizeContentType, normalizeExtension } from './kinds.js';

export const MIN_REELS_SECONDS = 3;
export const MAX_REELS_SECONDS = 60;

/** 400/413/415-style outcome: { ok: true } or { ok: false, status, error }. */
function reject(status, error) {
  return { ok: false, status, error };
}

function limitsFromEnv(env) {
  return {
    images: toInt(env?.IMAGES_MAX_BYTES, 10 * 1024 * 1024),
    reels: toInt(env?.REELS_MAX_BYTES, 5 * 1024 * 1024),
    audio: toInt(env?.AUDIO_MAX_BYTES, 50 * 1024 * 1024),
  };
}

function toInt(value, fallback) {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

/**
 * Validates a request to upload (proxied or presigned).
 *
 * @param {object} input
 * @param {string} input.kind        one of image | reels | audio
 * @param {string} input.contentType client-declared MIME (never trusted alone)
 * @param {string} input.ext         client-declared extension
 * @param {number} input.sizeBytes   declared size, required for presign
 * @param {object} [input.env]       worker env for limit overrides
 * @param {boolean} [input.requireSize]
 */
export function validateUploadRequest({
  kind,
  contentType,
  ext,
  sizeBytes,
  env,
  requireSize = false,
}) {
  const spec = KINDS[kind];
  if (!spec) return reject(400, 'Unknown media kind.');

  const normalizedType = normalizeContentType(contentType);
  if (!spec.contentTypes.includes(normalizedType)) {
    return reject(415, 'This file type is not allowed.');
  }

  const normalizedExt = normalizeExtension(ext);
  if (!spec.extensions.includes(normalizedExt)) {
    return reject(400, 'This file extension is not allowed.');
  }

  const limits = limitsFromEnv(env);
  const maxBytes = limits[spec.limitKey];

  if (requireSize || sizeBytes !== undefined) {
    if (!Number.isFinite(sizeBytes) || sizeBytes <= 0) {
      return reject(400, 'A positive sizeBytes is required.');
    }
    if (sizeBytes > maxBytes) {
      return reject(
        413,
        `The limit for ${spec.folder} is ${Math.floor(maxBytes / (1024 * 1024))} MB.`,
      );
    }
  }

  return { ok: true, kind, contentType: normalizedType, ext: normalizedExt, maxBytes };
}

/**
 * Validates the metadata of an object that is about to be stored through the
 * binding (proxied upload), where the real body is available to measure.
 */
export function validateStoredObject({ kind, contentType, sizeBytes, env }) {
  const spec = KINDS[kind];
  if (!spec) return reject(400, 'Unknown media kind.');
  const normalizedType = normalizeContentType(contentType);
  if (!spec.contentTypes.includes(normalizedType)) {
    return reject(415, 'This file type is not allowed.');
  }
  const limits = limitsFromEnv(env);
  const maxBytes = limits[spec.limitKey];
  if (!Number.isFinite(sizeBytes) || sizeBytes <= 0) {
    return reject(400, 'The uploaded file is empty.');
  }
  if (sizeBytes > maxBytes) {
    return reject(
      413,
      `The limit for ${spec.folder} is ${Math.floor(maxBytes / (1024 * 1024))} MB.`,
    );
  }
  return { ok: true, contentType: normalizedType, maxBytes };
}

/** True when a duration (seconds) sits inside the Reels window. */
export function validReelsDuration(seconds) {
  return (
    Number.isFinite(seconds) &&
    seconds >= MIN_REELS_SECONDS &&
    seconds <= MAX_REELS_SECONDS
  );
}
