# Pubget identity Worker setup

The identity endpoints use the existing `pubget-media` Worker and the Firebase ID token supplied by the signed-in app. The Worker exchanges its dedicated service-account credentials for a short-lived Google OAuth token scoped only to Firestore Datastore access.

## Required Cloudflare secrets

Create a dedicated Google service account for this Worker. Grant it only:

- `roles/datastore.user` on Firebase project `pubget-aaf27`.

Do not grant project Editor, Owner, Firebase Admin, or Storage access for this phase. The current profile-privacy and username-reconciliation Firestore triggers remain deployed and unchanged.

From the repository root, configure the two secrets on the `pubget-media` Worker:

```sh
npx wrangler secret put FIRESTORE_SERVICE_ACCOUNT_EMAIL --config worker/wrangler.toml
npx wrangler secret put FIRESTORE_SERVICE_ACCOUNT_PRIVATE_KEY --config worker/wrangler.toml
```

Paste the service-account email and the PEM private key when Wrangler prompts. Do not put either value in `wrangler.toml`, GitHub, Flutter, or a committed environment file. Keep the key in a password manager and rotate it if it is ever exposed.

## Routes moved to Worker

- `POST /identity/username/check`
- `POST /identity/username/reserve`
- `POST /identity/profile/update`

All routes require a valid Firebase ID token. Username reservation and profile username changes use Firestore REST transactions so the profile document and `usernames` registry are changed together. The Worker only accepts the profile-field allowlist and enforces the existing validation bounds.

Flutter username checks/reservations, account-profile updates, social-profile updates, language updates, and cover-key persistence now call these Worker routes. Firebase Authentication and direct Firestore reads remain in the app.

## Compatibility and safety

- Existing Firebase callable exports `checkUsernameAvailable`, `reserveUsername`, and `updateSocialProfile` remain in `functions/index.js` as a temporary compatibility path.
- Existing `syncUsernameReservation`, `syncAvatarPrivacy`, and `syncPublicProfile` triggers are deliberately retained. No trigger is removed or disabled.
- Firestore and Storage rules are not loosened.
- No service-account private key is committed.
- Do not switch production traffic until secrets are configured, the Worker is deployed, and authenticated end-to-end checks pass for availability, reservation contention, profile update, rename/release, private/public visibility, and R2 cover resolution.

## Validation boundary

The PR CI validates Worker bundling, unit tests, and Flutter analysis/tests. It cannot prove that Cloudflare secrets/IAM are configured or that the live Firestore transaction succeeds. Those require a post-deploy environment check.
