# Edits Platform Diagnostic (pre-implementation)

## 1. Authorization failure root cause
Exact Storage stock string: **"User is not authorized to perform the desired action."**

Primary causes in this codebase:
1. **Storage rules required exact `contentType == 'video/mp4'`** — many clients send `video/mp4; codecs=...` → rule deny on create/update (resumable upload needs UPDATE).
2. Client showed the raw Firebase message via `UnknownError(error.message)` with no mapping.
3. Historical deny of Storage UPDATE (documented in `storage.rules`) — already partially fixed, now hardened for codec suffixes.

## 2. Why failed state persists after reopen
`EditUploadPage._restoreDraft` restored local `phase=failed` from SharedPreferences and **did not clear stale errors** against server truth. If upload never finalized, server stays `uploading`; UI could remain failed with the old auth string. `retryProcessing` also rejected status `processing` (stuck jobs had no recovery).

## 3. State machine (server)
`uploading → processing → published | failed | rejected` (+ `deleted`)

## 4. Pipeline
`startEditUpload` → client Storage put → (missable) `onObjectFinalized processEditVideo` → ffmpeg → publish

Gap: no client `finalize` kick; trigger was `europe-west3` while callables/bucket are US-aligned → stuck `uploading`.

## 5–11. Implemented in this branch
- Storage rules: `video/mp4.*` + update fallback to existing contentType
- `finalizeEditUpload` callable + post-upload client call
- `retryProcessing` allows stuck `processing`
- `processEditVideo` region → `us-central1`
- Friendly error mapping (never leak raw unauthorized text)
- Composer rebuilt: video-first preview, server reconcile on open/resume
- Draft stores `localPath`; Arabic copy
- Tests: domain finalize/retry, Flutter hardening suite
