# Media pipeline failure — diagnosis and manual verification

Status: **investigation only. No fix applied.** This document records what is
proven from the repository and from unauthenticated probes, then lists the
remaining root-cause hypotheses together with the exact checks needed to confirm
or eliminate each one. Nothing here should be treated as a confirmed root cause
until the corresponding verification step has been run against production.

Incident project: `pubget-aaf27`. Report date: 2026-10-14.

## 1. Reported symptoms

- Profile pictures, group/community images and video thumbnails do not appear
  across many unrelated screens.
- Image upload in Fan Works / Create Fan Work fails.
- An Arabic error is shown: `فشل الرفع. تم الاحتفاظ بمسودتك.`
  ("Upload failed. Your draft was kept.").
- The upload screen shows an `UNAVAILABLE`-class status at the bottom.

The breadth (several unrelated features, reads *and* writes) is the most
important clue: it points at something shared — Firebase initialization, the
Storage bucket, Authentication, or the deployed Storage rules — rather than a
single screen.

## 2. Proven facts (verified against this repository and live endpoints)

### 2.1 Firebase project and bucket are consistent and the bucket exists

`android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist`
both target project `pubget-aaf27` with bucket
`pubget-aaf27.firebasestorage.app`.

Unauthenticated HTTP probe of the Storage REST endpoint (a 403 means the bucket
exists but requires auth; a 404 means it does not exist):

| Bucket | HTTP |
|---|---|
| `pubget-aaf27.firebasestorage.app` | **403** (exists, private) |
| `pubget-aaf27.appspot.com` | **404** (does not exist) |
| `pubget-817cf.firebasestorage.app` | 404 |
| `pubget-817cf.appspot.com` | 404 |

Conclusion: the client configuration names the correct, existing bucket. The
legacy `.appspot.com` name for this project does **not** exist.

### 2.2 The shared image widget and URL helpers are correct

- `lib/core/widgets/app_image_loader.dart` renders `http(s)` values with
  `Image.network` and bare object paths with `FirebaseStorage.instance.ref(path)
  .getData()`; failures fall back to a placeholder rather than crashing.
- `lib/core/media/media_reference.dart` (`isRemoteMediaUrl`,
  `isOpaqueMediaReference`, `resolveMediaDownloadUrl`) correctly separates the
  two reference shapes.

These are not the defect. (One caveat is recorded in hypothesis H4.)

### 2.3 Android build wiring is correct

`android/app/build.gradle.kts` applies `com.google.gms.google-services`; the
root Gradle file pins the plugin to `4.4.4`; `AndroidManifest.xml` requests
`INTERNET` and `ACCESS_NETWORK_STATE`. So `google-services.json` is processed
and the SDK can reach the network.

### 2.4 The deployed Storage rules hash is stale relative to the repo

- Local `storage.rules` SHA-256 (today) = `033d3b3106102728869fa8e1455bd4ce3e7c1c3330c1a668e13a88b94ea2b6e6`
- Documented **deployed** Storage ruleset SHA-256 (2026-08-31,
  `PRODUCTION_EVIDENCE_20260831.md`) = `7a497a1f7daa56e6ef1aa97a84241ff354266cd24c83ba9166d0855ed1937bbf`
- `storage.rules` was last modified in git by `f6f1150` on **2026-10-10**,
  i.e. **after** that deployment.

This proves the file changed after the last documented deployment. It does
**not** by itself prove that the currently deployed ruleset is the 2026-08-31
one — that must be checked (H3). Deployment is automated by
`.github/workflows/deploy-storage-rules.yml` (`--project pubget-aaf27`).

### 2.5 The current Storage rules require authentication for every read

`storage.rules` opens `match /b/{bucket}/o` and, deliberately, has **no
catch-all**: every read rule begins with `signedIn()`
(`request.auth != null`). Fan Work PDFs are the one exception — they are read
through short-lived V4 signed URLs, not through the rules.

### 2.6 The Firebase-init workaround is a swallow, not a fix

`lib/app/firebase_bootstrap.dart:97-104` documents a production Android failure:

> `RangeError (length): Invalid value: Not in inclusive range 0..13: 14` while
> decoding native `CoreFirebaseOptions` (14 fields, Dart expected 15).

`userFacingInitializationMessage` returns the same generic "could not start"
string in every case, and the app proceeds with
`FirebaseInitializationStatus.unavailable`. When that happens,
`lib/app/pubget_app.dart` injects `Unavailable*Repository` for every feature, so
uploads fail and reads return "unavailable" everywhere. The `RangeError` is a
native-vs-Dart `firebase_core` version mismatch; catching it hides the cause but
does not restore Firebase.

### 2.7 Fan Work uploads depend entirely on server-minted signed URLs

- Client: `lib/features/fan_works/repositories/firebase_fan_work_repository.dart`
  calls the `startFanWorkMediaUpload` callable (region `us-central1`) and then
  uploads bytes with `FanWorkUploadClient.upload(sessionUrl: ticket.uploadUrl,
  ...)` — **not** through the Storage SDK.
- Server: `functions/src/fanWorksStorage.js` mints the URL via
  `bucket.file(path).createResumableUpload(...)` (documents) and
  `bucket.file(path).getSignedUrl({version: 'v4', ...})` (images).
- Error mapping: a callable `internal`/`unknown`/`aborted`/`data-loss` maps to
  `UnavailableError` (`lib/core/errors/firebase_failure_mapper.dart`), which is
  what surfaces as the `UNAVAILABLE` status. A callable that throws also spends
  up to three `runWithRetry` attempts first.

So any server-side failure to **mint** the URL (bucket handle wrong, signing
permission missing, function not deployed) shows up to the user as the exact
"upload failed / draft kept / unavailable" experience described.

### 2.8 Cloud Functions use the Admin default bucket

`functions/index.js` passes `getStorage().bucket()` (no explicit name) to every
domain (lines 65, 91, 146, 198, 206, 240, 252, 419, 846, 1053). If the runtime
environment does not set `FIREBASE_CONFIG.storageBucket`, the Admin SDK falls
back to `<projectId>.appspot.com` — a bucket that **does not exist** for this
project (§2.1). This is the classic `.firebasestorage.app` migration trap.

### 2.9 Things that are *not* the cause

- **App Check is not enforced.** `APP_CHECK_ROLLOUT.md` states the rollout was
  "Not completed"; no token enforcement is live.
- **No stale old-project URLs** are stored in the repo (`pubget-817cf` appears
  only in the git history/changelog, not in tracked source or fixtures).

### 2.10 Environment versions

`firebase_core` 4.11.0, `firebase_auth` 6.5.1, `cloud_firestore` 6.4.1,
`firebase_storage` 13.4.1, `cloud_functions` 6.3.1, `firebase_messaging`
16.2.2; Android `firebase-bom:34.11.0`; `functions` uses
`firebase-admin ^13.8.0` and `firebase-functions ^7.2.5` on Node 20.
`processEditVideo` is deployed in `europe-west3` (`functions/index.js:431`),
which conflicts with the note in `docs/EDITS_PLATFORM_DIAGNOSTIC.md` that
recommends `us-central1`.

## 3. Ranked hypotheses and how to verify each

Run the checks in §4; each hypothesis states the observation that confirms it.

### H1 — Cloud Functions resolve to a non-existent default bucket (highest)

If `getStorage().bucket()` returns `pubget-aaf27.appspot.com`,
`createResumableUpload` / `getSignedUrl` / `setMetadata` either fail or produce
URLs to a bucket that 404s. This breaks every server-mediated media path:
Fan Work upload, avatar privacy sync (`functions/src/avatarPrivacy.js`),
group-media pipeline, reader signed URLs.

- Confirm: `gcloud functions logs read startFanWorkMediaUpload --project
  pubget-aaf27` shows `internal` / "not found" / "does not exist"; and
  `gcloud storage buckets list --project pubget-aaf27` shows only
  `...firebasestorage.app`.
- Fix if confirmed: resolve the bucket **once**, from
  `process.env.FIREBASE_STORAGE_BUCKET || 'pubget-aaf27.firebasestorage.app'`,
  and pass that handle to every domain instead of `getStorage().bucket()`.

### H2 — `getSignedUrl` lacks `iam.serviceAccounts.signBlob`

`getSignedUrl` needs the runtime service account to be able to sign, i.e. have
`roles/iam.serviceAccountTokenCreator` on itself. Without it, V4 signing throws
"Permission 'iam.serviceAccounts.signBlob' denied" → `internal` → the observed
`UNAVAILABLE`.

- Confirm: function logs contain `signBlob` / `signJwt` / "Permission denied"
  for `startFanWorkMediaUpload` or `getFanWorkDocumentAccess`.
- Fix if confirmed: grant the runtime SA Token Creator on itself, and/or mint
  upload grants with `createResumableUpload` (already used for PDFs) rather than
  `getSignedUrl`.

### H3 — The deployed Storage ruleset is stale (repo ≠ deployed)

If production runs an older ruleset, reads/writes the current client expects are
denied. This fits "broken everywhere" and "upload fails".

- Confirm: compare the deployed ruleset to `storage.rules` using the Firebase
  Rules API (see §4.3). There is now a known drift (§2.4): repo changed
  2026-10-10, deployment last documented 2026-08-31.
- Fix if confirmed: run the `Deploy Storage Rules` workflow (or
  `firebase deploy --only storage --project pubget-aaf27`) and re-verify the
  hash.

### H4 — Firebase never initializes on the device (unavailable mode)

If the `CoreFirebaseOptions` `RangeError` (§2.6) still fires, no Firebase service
works: no auth (so `signedIn()` is false and every Storage rule denies reads),
no Firestore, no callables.

- Confirm: device logcat contains "Firebase initialization failed" /
  "Pubget could not start Firebase"; the app shows the unavailable shell.
- Secondary client hardening (do after confirming): make
  `AppImageLoader`/`AppImageLoader._bytesForStorageUrl` tolerate an
  uninitialized Firebase without throwing during `build`.
- Fix if confirmed: align the native vs Dart `firebase_core` version
  (`flutter clean`, refresh Android plugin resolution / iOS `Podfile.lock`) so
  the pigeon `CoreFirebaseOptions` list lengths match.

### H5 — The Fan Work media callables are not (or wrongly) deployed

The 2026-08-31 function inventory lists nine functions and does **not** include
`startFanWorkMediaUpload`, `confirmFanWorkMedia`, or
`getFanWorkDocumentAccess`. If those are missing, the callable returns
`not-found`/`internal`.

- Confirm: `firebase functions:list --project pubget-aaf27 --json` shows the
  three callables and their regions (client uses `us-central1`).
- Fix if confirmed: deploy the current `functions` directory.

### H6 — Authentication state

Every Storage read rule requires `signedIn()`. If users can reach media screens
without a completed sign-in (or tokens are failing), every Storage read that
needs auth is denied.

- Confirm: capture an authenticated user's `request.auth` state; reproduce a
  single failed image fetch and read the error (`permission-denied` vs
  `unauthenticated`).

## 4. Manual verification runbook

Prerequisites: an authorized `firebase`/`gcloud` session for `pubget-aaf27`, and
a test device or emulator with the app installed.

### 4.1 Firebase init on device

```bash
adb logcat -c
# launch the app, sign in, open a profile with an avatar
adb logcat | grep -iE "Firebase initialization failed|could not start Firebase|CoreFirebaseOptions|RangeError"
```

If either string appears, H4 is confirmed.

### 4.2 Function deployment + regions

```bash
firebase functions:list --project pubget-aaf27 --json \
  | grep -E "startFanWorkMediaUpload|confirmFanWorkMedia|getFanWorkDocumentAccess|processEditVideo"
```

### 4.3 Storage rules drift

```bash
# local reference hash
shasum -a 256 storage.rules
# deployed rulesets for the project
TOKEN=$(gcloud auth print-access-token)
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://firebaserules.googleapis.com/v1/projects/pubget-aaf27/releases" \
  | grep -E "name|rulesetName"
```

Then fetch the released ruleset's `source` and compare its normalized content
(and SHA-256) with `storage.rules`. Alternatively compare visually in
Firebase Console → Storage → Rules. Expected local hash today:
`033d3b3106102728869fa8e1455bd4ce3e7c1c3330c1a668e13a88b94ea2b6e6`.

### 4.4 Server-side bucket and signing

```bash
gcloud storage buckets list --project pubget-aaf27 --format="value(name)"
firebase functions:log --project pubget-aaf27 --only startFanWorkMediaUpload,getFanWorkDocumentAccess \
  | grep -iE "appspot|does not exist|not found|signBlob|signJwt|permission|credentials"
```

### 4.5 Reproduce one upload and one read on the device

```bash
adb logcat -c
# (a) open a profile that has an avatar, (b) attempt a Fan Work image upload
adb logcat | grep -iE "Firebase|permission-denied|unauthenticated|unavailable|StorageException|403|404"
```

Record, for each action, whether the failure is `permission-denied`,
`unauthenticated`, `unavailable`/`internal`, or a client-side
"No host specified in URI".

## 5. Recommended fixes once a hypothesis is confirmed

Ordered by likelihood from the evidence above:

1. **Pin the Storage bucket explicitly in Cloud Functions** (H1). Resolve it
   once from `process.env.FIREBASE_STORAGE_BUCKET ||
   'pubget-aaf27.firebasestorage.app'` and thread that handle through every
   domain, replacing `getStorage().bucket()`.
2. **Grant the runtime service account Token Creator on itself** (H2), or use
   resumable-upload grants instead of `getSignedUrl` for signed writes.
3. **Redeploy Storage rules** so deployed == repo (H3).
4. **Fix the native `firebase_core` version mismatch** so init succeeds instead
   of degrading to `unavailable` (H4); add a client guard so image widgets do
   not throw when Firebase is uninitialized.
5. **Redeploy Cloud Functions** so the Fan Work callables and `processEditVideo`
   region match the client (H5).

## 6. What this document does not claim

- It does not claim a confirmed root cause. H1–H6 are ranked by evidence, not
  proven.
- It could not run the app on a device or read the Firebase Console / Cloud
  Logging, so no runtime error string or deployed-rules content is quoted here.
- No production deployment, rules change, or data change was performed.
