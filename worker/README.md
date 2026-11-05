# Pubget media Worker

This Worker stores media bytes in the private Cloudflare R2 bucket `pubget-media`.
The deployed Worker name is `pubget-media` and the default app endpoint is
`https://pubget-media.pubget.workers.dev`.

## Endpoints

- `GET /health`: deployment health check.
- `POST /upload`: authenticated multipart upload for small and medium files.
- `GET /presign`: creates a 15-minute signed direct-upload URL.
- `PUT /upload/{key}`: validates and accepts the signed upload.
- `GET /resolve?key=...`: returns a 10-minute signed playback URL.
- `GET|HEAD /media/{key}`: streams a signed URL, including byte-range requests
  for video playback.
- `DELETE /media/{key}`: owner-only deletion.

## Required secret

Set a cryptographically random 32-byte hexadecimal secret. Do not commit it,
add it to Flutter defines, or place it in source control:

```sh
openssl rand -hex 32 | npx wrangler secret put MEDIA_SIGNING_SECRET
```

The Worker needs the R2 bucket binding and
`FIREBASE_PROJECT_ID=pubget-aaf27`. Firebase Authentication remains the
identity provider; Firebase Storage is not the media-byte destination.

## Deploy

```sh
npx wrangler deploy --config worker/wrangler.toml
```

## Security and rollout notes

- The bucket is private; do not enable public bucket access.
- Firebase ID tokens are verified against Google's Secure Token signing keys.
- The Worker enforces content-type, extension, size, owner, expiry, and
  leading-byte file-signature checks for multipart and streamed direct uploads.
- Signed playback URLs are bearer URLs and expire after ten minutes. Avoid
  logging their query strings.
- **Current authorization boundary:** generic media keys are owner-scoped.
  The current `/resolve` endpoint intentionally refuses cross-owner access.
  Group/private-chat media must not be switched to this generic path until
  membership-aware upload, resolve, and delete authorization is implemented
  and covered by tests. A sender-only URL is not a valid chat-media solution.
- Existing Firebase Storage objects are legacy data. Do not delete or migrate
  source objects as part of a copy operation.
- The Flutter media backend now selects Cloudflare R2 by default and never
  silently falls back to Firebase Storage. Feature-specific Firebase Storage
  call sites still require migration before the app can claim complete
  Cloudflare-only media support.
