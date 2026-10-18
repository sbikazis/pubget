import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  validateUploadRequest,
  validateStoredObject,
  validReelsDuration,
  MIN_REELS_SECONDS,
  MAX_REELS_SECONDS,
} from '../src/validation.js';

test('accepts an allowed image upload', () => {
  const result = validateUploadRequest({
    kind: 'image',
    contentType: 'image/jpeg',
    ext: 'jpg',
    sizeBytes: 1024,
    requireSize: true,
  });
  assert.equal(result.ok, true);
  assert.equal(result.contentType, 'image/jpeg');
  assert.equal(result.ext, 'jpg');
});

test('rejects a disallowed content type', () => {
  const result = validateUploadRequest({
    kind: 'image',
    contentType: 'image/svg+xml',
    ext: 'svg',
  });
  assert.equal(result.ok, false);
  assert.equal(result.status, 415);
});

test('rejects a mismatched extension for the kind', () => {
  const result = validateUploadRequest({
    kind: 'image',
    contentType: 'image/png',
    ext: 'mp4',
  });
  assert.equal(result.ok, false);
  assert.equal(result.status, 400);
});

test('enforces the reels size ceiling', () => {
  const ok = validateUploadRequest({
    kind: 'reels',
    contentType: 'video/mp4',
    ext: 'mp4',
    sizeBytes: 5 * 1024 * 1024,
    requireSize: true,
  });
  assert.equal(ok.ok, true);

  const tooBig = validateUploadRequest({
    kind: 'reels',
    contentType: 'video/mp4',
    ext: 'mp4',
    sizeBytes: 5 * 1024 * 1024 + 1,
    requireSize: true,
  });
  assert.equal(tooBig.ok, false);
  assert.equal(tooBig.status, 413);
});

test('requires a positive size when asked', () => {
  const result = validateUploadRequest({
    kind: 'image',
    contentType: 'image/png',
    ext: 'png',
    requireSize: true,
  });
  assert.equal(result.ok, false);
});

test('env overrides replace the default ceilings', () => {
  const result = validateUploadRequest({
    kind: 'image',
    contentType: 'image/png',
    ext: 'png',
    sizeBytes: 2048,
    requireSize: true,
    env: { IMAGES_MAX_BYTES: '1024' },
  });
  assert.equal(result.ok, false);
  assert.equal(result.status, 413);
});

test('validateStoredObject rejects an empty body', () => {
  const result = validateStoredObject({
    kind: 'image',
    contentType: 'image/png',
    sizeBytes: 0,
  });
  assert.equal(result.ok, false);
});

test('reels duration window is 3..60 seconds', () => {
  assert.equal(validReelsDuration(MIN_REELS_SECONDS), true);
  assert.equal(validReelsDuration(MAX_REELS_SECONDS), true);
  assert.equal(validReelsDuration(2.9), false);
  assert.equal(validReelsDuration(61), false);
  assert.equal(validReelsDuration(NaN), false);
});
