# Cloudflare media migration

## Target architecture

- Cloudflare R2 is the only destination for new media bytes.
- The R2 bucket remains private; clients receive short-lived URLs from the
  `pubget-media` Worker only after Firebase Authentication and Firestore
  authorization checks.
- Firebase Authentication and Firestore remain in use for identity and
  metadata. Firebase Storage is not a new-upload backend.
- The Worker validates declared type, extension, byte limit, and file
  signature. Video playback supports HTTP byte ranges.

## Migrated in this change set

- Shared media repository selects Cloudflare R2 by default and has no silent
  Firebase Storage write fallback.
- Group and private-chat image, video, and audio uploads use conversation-scoped
  R2 object keys. The Worker checks group membership or private-chat
  participation before upload and URL resolution.
- Chat image/video/audio rendering resolves R2 object keys through the Worker;
  video uses byte-range playback and voice notes use the audio player.
- Group images, event option images, and profile avatar/cover uploads use R2.
- Signed media URL query strings are redacted from Worker observability logs.

## Remaining migration blockers

The app is not yet Firebase-Storage-free.

1. Kirari's upload, audio library, rendition and cover paths have been
   migrated to R2. The FFmpeg pipeline is triggered by Firestore state
   transitions and uses an authenticated Worker R2 bridge.
2. The Edits/Reels upload and FFmpeg rendition pipeline also uses Firebase
   Storage as its source and output store.
3. Legacy storage helpers (including sticker and chat-background services)
   still contain direct Firebase Storage calls and need to be migrated or
   removed after confirming they are not referenced by active screens.
4. Existing Firebase Storage URLs/objects need an explicit legacy policy. Do
   not delete them or break their readers until a migration/retention decision
   is made.

Cloudflare Stream is not enabled for this account (Cloudflare API returned
`Stream not enabled`). The current plan therefore cannot rely on Stream for
video transcoding. Kirari now uses an R2-backed processing adapter for the existing FFmpeg
Functions pipeline. Edits still needs a separate processing migration. Do not
switch the Edits uploader to raw R2 while leaving its Storage-triggered
processor in place: that would strand uploads in a non-published state.

## Operational safety

- Do not make the R2 bucket public.
- Do not put Cloudflare secrets in Flutter builds, source control, or Firestore.
- Signed playback URLs are bearer credentials with a short expiry; query
  strings are redacted in Worker observability.
- No live Worker code deployment or Firebase Functions deployment is part of
  this source change. Deploy only after the processing migration and CI pass.


## Kirari R2 migration (Cloudflare Worker + Firebase Functions)

Kirari source uploads now use authenticated R2 multipart uploads rather than
Firebase Storage. Flutter sends 8 MiB chunks to
`/kirari/multipart/{reelId}`; the Worker verifies the Firebase ID token and
reads the reel document through Firestore REST before accepting any part. The
client cannot choose an object key. Finalization changes the reel state to
`processing`, which wakes the Firestore-triggered FFmpeg pipeline. The
pipeline downloads the source from R2, creates the 360p/540p/720p renditions
and cover, and writes the resulting paths to Firestore.

Playback and cover URLs are resolved through `/kirari/resolve`. The Worker
checks the published reel (or approved reusable audio track) before issuing a
five-minute signed URL. The media endpoint supports HTTP byte ranges for video
seeking. Kirari deletion and retry operations use the same authenticated
server-side R2 adapter.

### Kirari service-to-service authentication

Kirari Functions Gen 2 obtains a short-lived Google-signed ID token from the
Cloud Run metadata server using the fixed Worker audience and `format=full`.
The Worker validates the Google signature, issuer, exact audience, verified
service-account email, and token lifetime before allowing access to the
private R2 bridge. The current Worker configuration allowlists the default
Gen 2 runtime account
`452313838148-compute@developer.gserviceaccount.com`; verify that the
deployed Functions runtime has not been manually assigned a different account
before production rollout.

This removes the shared `KIRARI_R2_SERVICE_SECRET` dependency and does not
require Firebase Secret Manager. The existing `MEDIA_SIGNING_SECRET` remains
required for signed media URLs and is separate from service identity.

The automated tests cover token issuance configuration, valid identity
acceptance, and rejection of missing or mismatched credentials. A
production-like end-to-end smoke test is still required for multipart source
upload, Firestore-triggered FFmpeg processing, signed playback/seek, retry,
moderation preview, and deletion. Do not deploy until CI and that runtime
smoke test pass.
