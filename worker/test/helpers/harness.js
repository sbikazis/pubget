// Test-only helpers: mint a Firebase-shaped ID token and an in-memory R2 fake.

import { FIREBASE_JWKS_URL } from '../../src/auth.js';

function base64Url(bytes) {
  return Buffer.from(bytes).toString('base64').replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
}

/** Generates an RS256 key pair and exposes the public JWK for the JWKS mock. */
export async function createSigner() {
  const kid = 'test-kid-1';
  const keyPair = await crypto.subtle.generateKey(
    {
      name: 'RSASSA-PKCS1-v1_5',
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: 'SHA-256',
    },
    true,
    ['sign', 'verify'],
  );
  const publicJwk = await crypto.subtle.exportKey('jwk', keyPair.publicKey);
  const jwk = { ...publicJwk, kid, alg: 'RS256', use: 'sig' };

  async function signToken(payloadOverrides = {}, { kid: headerKid = kid } = {}) {
    const nowSeconds = Math.floor(Date.now() / 1000);
    const payload = {
      aud: 'pubget-aaf27',
      iss: 'https://securetoken.google.com/pubget-aaf27',
      sub: 'user123',
      iat: nowSeconds - 10,
      exp: nowSeconds + 3600,
      ...payloadOverrides,
    };
    const header = { alg: 'RS256', typ: 'JWT', kid: headerKid };
    const encodedHeader = base64Url(new TextEncoder().encode(JSON.stringify(header)));
    const encodedPayload = base64Url(new TextEncoder().encode(JSON.stringify(payload)));
    const signingInput = `${encodedHeader}.${encodedPayload}`;
    const signature = await crypto.subtle.sign(
      'RSASSA-PKCS1-v1_5',
      keyPair.privateKey,
      new TextEncoder().encode(signingInput),
    );
    return `${signingInput}.${base64Url(new Uint8Array(signature))}`;
  }

  return { kid, jwk, signToken };
}

/** A fetch stand-in that serves the signer's JWK for the Firebase JWKS URL. */
export function jwksFetcher(jwk) {
  return async (url) => {
    if (url !== FIREBASE_JWKS_URL) {
      throw new Error(`unexpected fetch: ${url}`);
    }
    return new Response(JSON.stringify({ keys: [jwk] }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  };
}

/** Minimal in-memory stand-in for a Cloudflare R2 bucket binding. */
export function createFakeBucket() {
  const store = new Map();
  return {
    objects: store,
    async put(key, body, options = {}) {
      const chunks = [];
      if (body && typeof body.getReader === 'function') {
        const reader = body.getReader();
        for (;;) {
          const { done, value } = await reader.read();
          if (done) break;
          chunks.push(value);
        }
      } else if (body instanceof ArrayBuffer) {
        chunks.push(new Uint8Array(body));
      } else if (typeof body === 'string') {
        chunks.push(new TextEncoder().encode(body));
      } else if (body instanceof Uint8Array) {
        chunks.push(body);
      }
      let size = 0;
      for (const chunk of chunks) size += chunk.length;
      const bytes = new Uint8Array(size);
      let offset = 0;
      for (const chunk of chunks) {
        bytes.set(chunk, offset);
        offset += chunk.length;
      }
      store.set(key, {
        key,
        size,
        bytes,
        httpMetadata: options.httpMetadata || {},
        customMetadata: options.customMetadata || {},
        uploaded: new Date('2026-10-17T00:00:00.000Z'),
        etag: `etag-${store.size}`,
      });
      return null;
    },
    async head(key) {
      return store.get(key) || null;
    },
    async get(key, options = {}) {
      const record = store.get(key);
      if (!record) return null;
      let bytes = record.bytes;
      if (options.range && typeof options.range.offset === 'number') {
        const start = options.range.offset;
        const length = options.range.length ?? bytes.length - start;
        bytes = bytes.slice(start, start + length);
      }
      return {
        ...record,
        size: bytes.length,
        httpEtag: `"${record.etag}"`,
        body: new Response(bytes).body,
      };
    },
    async delete(key) {
      store.delete(key);
    },
    async list({ prefix = '', limit = 1000, cursor } = {}) {
      const all = [...store.values()]
        .filter((object) => object.key.startsWith(prefix))
        .sort((a, b) => (a.key < b.key ? -1 : 1));
      const start = cursor ? Number.parseInt(cursor, 10) : 0;
      const page = all.slice(start, start + limit);
      const next = start + limit;
      return {
        objects: page,
        truncated: next < all.length,
        cursor: next < all.length ? String(next) : undefined,
      };
    },
  };
}

export function fileFrom(bytes, name, type) {
  return new File([bytes], name, { type });
}

export const JPEG_HEAD = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46]);
