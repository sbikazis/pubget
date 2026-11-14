# Identity & Account Core — implementation record

This record covers the first foundational system selected for Pubget. It does not claim that unrelated profile, social-graph, or media-migration axes are complete.

## Implemented in the current branch

- Email/password accounts send Firebase email verification. Unverified sessions are routed through the splash policy and cannot reach onboarding or the app until verification is refreshed.
- Google sign-in remains supported; Firebase's verified state is read from the authenticated user.
- Username availability is case-normalized and owner-aware. A user may revalidate their own reservation; a different user's reservation remains unavailable.
- New profile documents require a server-reserved username, non-empty display name, non-empty avatar reference, and completed onboarding. Client writes cannot change usernames or set the legacy onboarding-skip flag to bypass completion.
- Profile completion is validated server-side by `updateSocialProfile`. Username changes go through the reservation transaction rather than direct client writes.
- Offline onboarding can no longer skip required identity fields. Optional steps can be skipped without marking the account complete.
- Onboarding resumes from saved profile values and persists optional age, gender, country, bio, and Anime Hub selections (canonical anime IDs plus display titles).
- Favorite anime selection now searches the existing Anime Hub repository instead of saving genre labels as if they were anime titles.
- Profile updates use the server callable. R2 avatar references remain intact when a profile becomes private; legacy Firebase Storage token rotation is limited to legacy Firebase Storage URLs.
- Splash checks Firebase Remote Config before routing. It supports minimum-version blocking and optional updates for Android and iOS, with numeric version comparison.

## Firebase Remote Config parameters

Set these parameters in Firebase Console before production rollout:

| Parameter | Purpose |
| --- | --- |
| `min_version_android` | Minimum supported Android version; lower versions are blocked |
| `latest_version_android` | Latest Android version; lower versions receive an optional update prompt |
| `update_url_android` | Android store/update URL |
| `min_version_ios` | Minimum supported iOS version |
| `latest_version_ios` | Latest iOS version |
| `update_url_ios` | iOS App Store/update URL |

Empty values mean no version restriction or prompt. The client fails open if Remote Config is unreachable, so the Console values are required for an actual production gate.

## Verification still required

- Run `flutter pub get` to refresh the tracked `pubspec.lock` for the two justified additions: `firebase_remote_config` and `package_info_plus`.
- Run the complete PR CI against the latest branch head: Flutter analyze/tests/build, Functions tests, Firestore/Storage rules emulator tests, and repository hygiene.
- Verify the Firebase Auth email-verification template and authorized domains in Firebase Console.
- Verify Remote Config parameters and update URLs in Firebase Console.
- Perform one end-to-end device test for email verification, onboarding completion, R2 avatar privacy transitions, and forced/optional update behavior.

No files under `lib_legacy/` were edited. No production Firebase or Cloudflare deployment is performed by this code change.
