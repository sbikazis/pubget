# Kirari 1.0 — Operations and verification

## Product surfaces

- The Reels tab opens the independent Kirari feed and upload flow.
- Home includes a trending Kirari discovery rail.
- Creator profiles show published Kirari videos only when the profile's Works section is visible to the viewer.
- Canonical `/reel/:id` links resolve to the legacy Edits detail page when the ID belongs to Edits, otherwise to Kirari.
- Canonical `/audio/:id` pages include Kirari reuse attribution and videos using that track.
- Canonical `/hashtag/:tag` pages include Kirari videos.
- Feed and detail surfaces link to creator profiles, audio pages and shareable reel URLs.

## Editor and processing

The Flutter editor stores trim start/end, speed (0.5×–2×), one of five color looks, optional text overlay (80 characters maximum), cover timestamp, caption, hashtags and an optional licensed audio track. The server revalidates editor settings and renders 360p, 540p and 720p vertical MP4 renditions with FFmpeg. It generates the cover frame server-side.

When a track is selected, the server mixes it with source audio (source at 25%, selected track at 85%) when the source contains audio; otherwise the selected track becomes the output audio. Speed changes are applied to both audio streams. The selected track's title, artist, license, attribution and source creator are copied into the published reel's `audioAttribution` field.

## Curated audio catalog

Audio is admin-curated. Store each approved file at `kirari-audio/{audioId}/audio.mp3` (the Storage rule also accepts m4a, aac and ogg). The file must be audio MIME and no larger than 25 MB. Then call `publishKirariAudioTrack` with an authenticated Firebase user carrying the `admin: true` custom claim and the fields:
- `audioId`, `title`, `artist`, `license`, `attribution`, `audioPath`
- optional `creatorId`
- `allowReuse: true`
- `approved: true` only after confirming the license permits reuse and the attribution is accurate.

The callable verifies the object exists and its MIME/size. The public catalog returns only approved tracks with reuse enabled. Client writes to the catalog are denied. Storage writes are admin-only; reads are available only for approved, reusable tracks.

## Moderation and abuse controls

- Caption and comment text pass the existing text moderation filter.
- A creator cannot create more than one active upload session; upload quota is 10 sessions per UTC day and source file size is capped at 500 MB.
- Upload idempotency keys are format-validated. Canceling an upload releases its active lock, idempotency key and quota slot.
- Duplicate storage-finalize processing is guarded by a ten-minute processing lease.
- Comments are rate-limited to one every two seconds per account.
- Interactions and counters are server-authoritative. A playback session is bound to the authenticated viewer; heartbeat credit is capped by elapsed server time. A qualified view requires at least three seconds; completion is recorded at 95%.
- A user can mute creators or mark videos not interested. Blocked creators, muted creators and negative-feedback videos are excluded from For You.
- Three unique reports queue a reel or comment for review. Admin-only `getKirariModerationQueue` and `reviewKirariContent` support approve/reject decisions. Storage playback is gated on approved publication.

**Moderation limitation:** the current automated moderation is text-based. The admin route provides a basic manual review queue, but there is not yet automated visual/audio classification or a creator appeal workflow.

## Playback and upload recovery

- Feed playback measures a small HTTP byte-range sample, chooses 360p/540p/720p using measured throughput, and caches the estimate for five minutes.
- At most one next-video controller is prefetched; it is disposed when the active item changes.
- Upload source files are copied into application support storage. The app persists the local path, idempotency key, session ID, storage path and editor settings. Reopening the upload screen restores the draft and lets the user retry against the same server session.

**Recovery limitation:** after process death, the app restarts the upload from the persisted local file to the same object path. This is idempotent recovery, not byte-offset continuation or background upload while the app remains closed.

## Server-managed moderation and audio operations

The `/admin/kirari-moderation` route provides the review screen. Queue previews use five-minute signed URLs returned only to an admin caller. Both `publishKirariAudioTrack`, `getKirariModerationQueue` and `reviewKirariContent` require the Firebase Auth custom claim `admin: true`. Grant that claim only to trusted operators. The functions do not grant admin privileges themselves.

## Verification commands

From the repository root:

```bash
cd functions
npm ci
npm run check
npm test
```

With Java available and Firebase emulators running for Firestore + Storage:

```bash
cd functions
npm run test:rules
npm run test:storage-rules
```

From the Flutter repository root:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Do not mark Kirari production-ready until all commands pass in CI and the deployed Firebase project has the matching Firestore indexes and Storage/Firestore rules. The PR workflow is intended to run the same checks without deploying production services.
