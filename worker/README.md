# Pubget media worker

An authenticated gateway in front of the `pubget-media` Cloudflare R2 bucket.
It is the only component that ever touches R2 credentials; the Flutter app
never sees a key, a secret, or a bucket URL.

The app talks to it through `MediaStorageProvider` (`r2_media_storage_provider.dart`)
and it is **opt-in**: unless the app is built with both
`--dart-define=MEDIA_BACKEND=r2` and `--dart-define=R2_WORKER_URL=https://…`,
media keeps using Firebase Storage. See `lib/core/media/media_storage_provider.dart`.

## Routes

| Method | Path                | Auth | Purpose |
| ------ | ------------------- | ---- | ------- |
| `GET`  | `/healthz`          | no   | Liveness + whether presigning is configured |
| `GET`  | `/presign?kind=…`   | yes  | Short-lived (15 min) presigned `PUT` URL for direct-to-R2 upload |
| `POST` | `/upload?kind=…`    | yes  | Proxied upload (bytes pass through the worker) |
| `GET`  | `/media/<key>`      | no   | Redirect to `PUBLIC_BASE_URL`, or stream the object |
| `HEAD` | `/media/<key>`      | no   | Size + content type, no body |
| `DELETE` | `/media/<key>`    | yes  | Delete an object; owner only |
| `GET`  | `/list?kind=…`      | yes  | List the caller's objects (admin may pass `ownerUid`) |

`kind` is one of `image`, `reels`, `audio`. The client never supplies a path
or a file name: keys are always `{folder}/{uid}/{uuid}.{ext}`, built by the
worker, so ownership is provable from the key.

### Read / streaming behaviour (`/media/<key>`)

* **Byte ranges.** `Range: bytes=0-1023`, open ranges (`bytes=1024-`) and
  suffix ranges (`bytes=-1024`) return `206 Partial Content` with
  `Content-Range`; an unsatisfiable range returns `416`. `Accept-Ranges: bytes`
  is always set, so `<video>`/`<audio>` can seek and stream without downloading
  the whole file.
* **Immutable caching.** Keys are content-addressed (`uuid`), so responses
  carry `Cache-Control: public, max-age=31536000, immutable`. A changed file is
  always a new key — never reuse one.
* **Edge cache.** Full-body `GET`s (no `Range`) are stored in the Cloudflare
  Cache API, so repeat reads are served from the nearest edge without touching
  R2. CORS headers are (re)applied per request, so the cached copy never leaks
  another origin's policy.
* **Content type** comes from the stored object metadata, falling back to the
  key's extension (`read.js`).

## Authentication

Every authenticated route expects a Firebase ID token:
`Authorization: Bearer <idToken>`. The token is verified against Google's
public JWKS (`auth.js`) — signature, `alg`, `iss`, `aud`, `exp`, `iat`. No
Google secret is stored in the worker. The caller's uid is the token's `sub`;
an `admin: true` custom claim grants cross-user read/delete.

CORS is configured (`ALLOWED_ORIGINS`) but **CORS is not authentication** — it
only limits which web pages may call the worker from a browser. The token is
what actually authorizes a request.

## Configuration

`wrangler.toml` holds non-secret values. Secrets are set with
`wrangler secret put` and never committed.

Public vars (with defaults):

| Name | Default | Notes |
| ---- | ------- | ----- |
| `FIREBASE_PROJECT_ID` | `pubget-aaf27` | Token audience/issuer |
| `PUBLIC_BASE_URL` | *(empty)* | Absolute origin serving the bucket; when empty, `/media/:key` streams instead of redirecting |
| `ALLOWED_ORIGINS` | `https://pubget-aaf27.web.app,https://pubget-aaf27.firebaseapp.com` | Comma-separated |
| `R2_ACCOUNT_ID` | *(empty)* | **Set this.** Part of the S3 endpoint; not a secret |
| `IMAGES_MAX_BYTES` | `10485760` | Keep in sync with `media_limits.dart` / `storage.rules` |
| `REELS_MAX_BYTES` | `5242880` | |
| `AUDIO_MAX_BYTES` | `52428800` | |
| `PRESIGN_PER_MINUTE` | `10` | |
| `UPLOADS_PER_HOUR` | `20` | |
| `LIST_PER_MINUTE` | `60` | |

Secrets (server-side only):

| Name | Purpose |
| ---- | ------- |
| `R2_ACCESS_KEY_ID` | R2 API token access key id (for presigned PUTs) |
| `R2_SECRET_ACCESS_KEY` | R2 API token secret access key |

The R2 binding (`MEDIA`) needs no credentials; it powers proxied uploads,
reads, deletes and listing. The **S3 credentials above are only needed for
`/presign`** — without them `/presign` returns `501` and the app falls back to
proxied uploads.

## Values the operator must supply

Nothing here is guessed. Fill these in before deploying:

1. `R2_ACCOUNT_ID` — the Cloudflare account id for the R2 bucket.
2. `R2_ACCESS_KEY_ID` / `R2_SECRET_ACCESS_KEY` — an R2 API token with
   object read & write on `pubget-media` (Dashboard → R2 → Manage API tokens).
3. `PUBLIC_BASE_URL` — your custom domain for the bucket, **or** an
   `r2.dev` public URL, **or** leave empty to stream through the worker.
4. `ALLOWED_ORIGINS` — add any additional web origins you serve from.

The bucket name (`pubget-media`) is fixed in `wrangler.toml` and in
`readConfig`; change both together if you rename it.

## Deploy (manual, reviewed)

```sh
cd worker
npm install
npx wrangler login
npx wrangler secret put R2_ACCESS_KEY_ID
npx wrangler secret put R2_SECRET_ACCESS_KEY
npx wrangler deploy
```

Then point the app at it:

```sh
flutter build web \
  --dart-define=MEDIA_BACKEND=r2 \
  --dart-define=R2_WORKER_URL=https://pubget-media.<account>.workers.dev
```

Smoke test:

```sh
curl -s https://<worker-url>/healthz
# => {"ok":true,"presignConfigured":true}
```

## Tests

```sh
npm test          # node --test test/
```

Covers key minting/parsing, request validation, magic-byte sniffing, the rate
limiter, the SigV4 signer (cross-checked against an independent node:crypto
implementation), token verification (real RSA keys), and the full request
handler end-to-end with an in-memory bucket.

## Security notes & limitations

* **Presigned uploads are not content-inspected.** The bytes never reach the
  worker, so only the proxied `/upload` path can sniff magic bytes. Direct
  uploads are constrained by declared type, extension, signed `Content-Type`
  and signed `Content-Length` — document this if you rely on `/presign`.
* **Rate limiting is per-isolate** (`ratelimit.js`). It stops a single abusive
  client, not a distributed one. Back it with a Durable Object or KV for a
  strict global limit; the interface is the seam for that.
* Signed headers on a presigned URL are exactly
  `content-length;content-type;host;x-amz-meta-owner-uid`. The uploader must
  send `Content-Type` and `x-amz-meta-owner-uid` verbatim; `Content-Length` is
  set by the HTTP client and must match the signed value or R2 rejects the PUT.
* The worker never logs tokens or credentials.
