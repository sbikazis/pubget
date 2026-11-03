# Pubget media Worker

This Worker stores media bytes in the Cloudflare R2 bucket `pubget-media`.

## Endpoints

- `GET /health`: deployment health check.
- `POST /upload`: authenticated multipart upload for small and medium files.
- `GET /presign`: creates a 15-minute signed direct-upload URL.
- `PUT /upload/{key}`: validates and accepts the signed upload.
- `GET /resolve?key=...`: returns a 10-minute signed playback URL. All objects are owner-only until public Reel visibility and group/private-chat membership checks are implemented against Firestore.
- `GET|HEAD /media/{key}`: streams a signed URL, including byte-range requests for video playback.
- `DELETE /media/{key}`: owner-only deletion.

## Required secret

Set a cryptographically random 32-byte hexadecimal secret. Do not commit it, add it to Flutter defines, or place it in source control:

```sh
openssl rand -hex 32 | npx wrangler secret put MEDIA_SIGNING_SECRET
```

The production Worker also needs the R2 bucket binding and `FIREBASE_PROJECT_ID=pubget-aaf27`. The current Cloudflare deployment has these bindings and a generated secret configured.

## Deploy

```sh
npx wrangler deploy --config worker/wrangler.toml
```

## Security and rollout notes

- The bucket is private; do not enable public bucket access.
- Firebase ID tokens are verified against Google's Secure Token signing keys.
- The Worker enforces content-type, extension, size, owner, expiry, and leading-byte file-signature checks for both multipart and streamed direct uploads.
- Signed playback URLs are bearer URLs and expire after ten minutes. Avoid logging their query strings.
- The initial generic media key layout does not replace group/private-chat membership checks or per-record publication visibility checks. Those feature-specific paths must remain on Firebase until an equivalent membership-aware authorization policy is implemented and tested.
- Keep Firebase Storage as the app default until every feature repository, media renderer, migration path, and CI test is switched and verified. Never delete the Firebase source objects as part of a copy operation.
