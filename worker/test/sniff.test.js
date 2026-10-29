import { test } from 'node:test';
import assert from 'node:assert/strict';
import { sniff, matchesDeclaredKind } from '../src/sniff.js';

const bytes = (...values) => new Uint8Array(values);

test('detects common image containers', () => {
  assert.equal(sniff(bytes(0xff, 0xd8, 0xff, 0xe0))?.subtype, 'jpeg');
  assert.equal(sniff(bytes(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a))?.subtype, 'png');
  assert.equal(sniff(bytes(0x47, 0x49, 0x46, 0x38, 0x39, 0x61))?.subtype, 'gif');
});

test('requires the WEBP marker, not just RIFF', () => {
  const riffOnly = bytes(0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00, 0x41, 0x56, 0x49);
  assert.equal(sniff(riffOnly), null);

  const webp = bytes(0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50);
  assert.equal(sniff(webp)?.subtype, 'webp');
});

test('detects ISO-BMFF (ftyp) and webm', () => {
  const ftyp = bytes(0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x69, 0x73, 0x6f, 0x6d);
  assert.equal(sniff(ftyp)?.subtype, 'mp4');
  assert.equal(sniff(bytes(0x1a, 0x45, 0xdf, 0xa3))?.subtype, 'webm');
});

test('HTML disguised as an image is rejected', () => {
  const html = new TextEncoder().encode('<html><body>hi</body></html>');
  assert.equal(sniff(html), null);

  const result = matchesDeclaredKind(html, 'image');
  assert.equal(result.ok, false);
  assert.equal(result.reason, 'unrecognized');
});

test('a video-named file carrying audio bytes is a kind mismatch', () => {
  const png = bytes(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a);
  const result = matchesDeclaredKind(png, 'reels');
  assert.equal(result.ok, false);
  assert.equal(result.reason, 'kind-mismatch');
});

test('an ftyp container is accepted for both reels and audio', () => {
  const ftyp = bytes(0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x69, 0x73, 0x6f, 0x6d);
  assert.equal(matchesDeclaredKind(ftyp, 'reels').ok, true);
  assert.equal(matchesDeclaredKind(ftyp, 'audio').ok, true);
});
