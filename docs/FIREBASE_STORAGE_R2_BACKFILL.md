# Firebase Storage → Cloudflare R2 backfill

Status: source implementation only. No Cloudflare Worker deployment, new binding,
IAM change, KV namespace, or source-object deletion is performed by this PR.

## Architecture

- Source inventory uses the Google Cloud Storage JSON API against the existing
  private Firebase bucket `pubget-aaf27.firebasestorage.app`.
- The existing Worker service-account key is used only inside Worker runtime.
  OAuth scopes are separated: Firestore datastore access for the manifest and
  `devstorage.read_only` for listing/downloading source objects.
- The durable manifest and control cursor live in Firestore collections
  `storageMigrationManifest` and document `storageMigration/control`.
  No KV namespace is needed.
- R2 objects are written to the exact original object key in the private
  `MEDIA_BUCKET`; existing R2 keys not created by this migration are treated
  as conflicts and are never overwritten.
- Each manifest record stores source bucket/path, GCS generation and
  metageneration, size, MIME type, MD5/CRC32C when supplied, source timestamps,
  sanitized custom metadata, content metadata, status, attempts, source and
  destination SHA-256, verification timestamp, and last error.
- Source and R2 destination bytes are hashed with streaming SHA-256. The
  manifest becomes `verified` only when both hashes and byte counts match.
  Hashing is streaming; the Worker does not buffer an entire video/PDF in RAM.
- Firebase Storage download-token metadata is intentionally not copied into
  R2 metadata or the manifest because it is a bearer credential.
- The source GCS generation and metageneration are checked before download;
  download uses `ifGenerationMatch` to avoid copying a concurrently replaced
  object.
- A Firestore transaction lease serializes mutating inventory/copy/retry jobs.
  Expired `copying` records are recovered after 15 minutes and count against
  the five-attempt retry budget.

## Required setup (manual, not performed by this PR)

1. Confirm the Worker secret
   `FIRESTORE_SERVICE_ACCOUNT_EMAIL` is the intended service identity
   `pubget-identity-worker@pubget-aaf27.iam.gserviceaccount.com`. The existing
   private key remains a Cloudflare secret and must never be pasted into chat,
   GitHub, Flutter, or this document.
2. Grant that service account bucket-level read-only access to
   `pubget-aaf27.firebasestorage.app`: `storage.objects.list` and
   `storage.objects.get` (the predefined `roles/storage.objectViewer` role
   is an acceptable narrow bucket-scoped role). Do not grant object create,
   update, or delete permissions on Firebase Storage.
3. Configure the non-secret Worker variable
   `FIREBASE_STORAGE_BUCKET=pubget-aaf27.firebasestorage.app` only after
   reviewing the PR and confirming the exact bucket. This is deliberately not
   added to `wrangler.toml` in this PR.
4. The operator must sign in with a verified Firebase account carrying the
   `admin: true` custom claim and reauthenticate within the previous five
   minutes. The API does not accept a static admin token or expose one.
5. Deploy only the reviewed Worker version through the existing release
   process. This PR does not deploy or create bindings.

## Admin API

All routes require a Firebase ID token in the Authorization header. The Worker
validates the token signature/issuer/audience/expiry, verified email, admin
custom claim, and a maximum five-minute auth age. The Firestore service
credential is never returned.

- `GET /_admin/storage-migration/status` — persisted progress and cursors.
- `POST /_admin/storage-migration/inventory` — lists one GCS page (up to
  1,000 objects), upserts the manifest idempotently, and persists the next page
  token. Repeat until `inventoryComplete: true`.
- Inventory dry-run: send `{"dryRun":true,"pageSize":1000}`. Follow the
  returned `nextPageToken` in the next dry-run request's `pageToken`.
  Dry-run does not write manifest or progress state.
- `POST /_admin/storage-migration/copy` — processes one pending
  records per call; repeat until `processed: 0`.
- Copy dry-run: `{"dryRun":true,"limit":8}`.
- `POST /_admin/storage-migration/retry` — retries failed records only while
  attempts are below five. Conflicts and exhausted records are not retried.
- `POST /_admin/storage-migration/reset-copy-cursor` — resets the pending
  scan cursor when a new inventory pass adds earlier-sorted manifest IDs.

The control cursor is durable. If an operator or Worker execution stops, query
status and continue inventory/copy from the saved cursor. Stale in-progress
records are returned to pending after the lease recovery window. The retry
endpoint is intentionally bounded.

## Dual-read behavior

- Existing full HTTPS Firebase Storage download URLs remain unchanged.
- For supported R2 key formats, Flutter asks the Worker first. The Worker
  serves a migrated object only when its R2 object carries the migration marker
  and its Firestore manifest record is `verified`.
- If the Worker returns 404 (not copied or not verified), Flutter reads the
  original object from Firebase Storage using the signed-in Firebase SDK. The
  existing Storage Rules remain authoritative for that fallback.
- Legacy Firebase paths outside the current Worker key grammar continue to use
  Firebase Storage directly. Inventory/copy does not rewrite Firestore media
  references; path rewrites require a separate feature-by-feature authorization
  audit.

## Safety / rollback

- No source Firebase Storage object is modified, renamed, deleted, or disabled.
- R2 remains private. No public bucket, public ACL, or permanent R2 download
  token is created.
- If verification fails, the partial R2 object is deleted; the source remains
  untouched and the manifest records a bounded failure.
- If an R2 key already exists without this migration's generation marker, the
  record becomes `conflict`; the existing R2 object is not overwritten.
- To roll back reads, remove/disable the new Worker migration release and
  restore the previous Flutter build. Firebase originals and URLs remain
  available. Do not delete R2 or Firebase objects as part of rollback.
- There is deliberately no cleanup endpoint in this migration.

## Limits and operational caveats

- Objects larger than 500 MiB are marked failed and require a separate
  multipart/server-side migration design.
- A single request processes one inventory page or one copy record;
  operators should monitor Worker execution limits and resume between calls.
- Source inventory requires GCS list/get IAM. Without that manual grant, the
  API returns a permission error and no inventory progress is committed.
- The implementation does not alter Firebase Spark, Firebase Rules, Cloudflare
  production bindings, or existing Functions triggers.
