# Kirari audio catalog operations

Kirari only exposes audio tracks that are approved, reusable, and marked `rightsVerified: true`. This is an admin-curated catalog; ordinary creators can select and reuse tracks, but cannot publish catalog entries.

## Required access

The operator must use an authenticated Firebase account with the custom claim `admin: true`. Do not grant this claim to normal users.

## Publish a reusable track

1. Choose a stable ID containing only letters, digits, underscores, or hyphens (for example `track_001`).
2. Upload the licensed audio asset to Firebase Storage at exactly:
   `kirari-audio/<audioId>/audio.mp3`
   Supported extensions are `mp3`, `m4a`, `aac`, and `ogg`. The maximum asset size is 25 MB.
3. Invoke the `publishKirariAudioTrack` callable as an admin with:
   - `audioId`: the same ID used in the Storage path
   - `title`, `artist`
   - `license` and `licenseUrl`
   - `sourceUrl` when the source is hosted elsewhere
   - `rightsHolder` and a clear `attribution` string
   - `sourceCreatorId` when the rights holder has a Pubget profile
   - `audioPath`: the exact Storage path
   - `allowReuse: true` and `rightsVerified: true` only after the license or written permission has been checked
4. The callable verifies that the object exists, is an audio asset, and is no larger than 25 MB. It records the verifying admin and timestamp.
5. The track appears in the creator upload audio picker. When a Reel is processed, its audio ID, title, artist, license, license URL, source URL, rights holder, attribution, and source creator are copied into immutable Reel attribution metadata.

## Do not publish for reuse

If the license or permission is uncertain, publish with `allowReuse: false` and `rightsVerified: false`, or do not publish the track. Such a track is not returned by the reusable-audio catalog and its Storage asset is not readable through the public audio path.

## Security model

- Clients cannot create or edit `kirariAudio` documents.
- Clients cannot write the server-side rights-verification fields.
- Firestore and Storage reads require approved status, `allowReuse: true`, and `rightsVerified: true`.
- The video processing pipeline independently rechecks those fields before mixing an audio track.
