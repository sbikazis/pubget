# Permission alignment: Firebase rules vs. client writes

Audit of the divergence between what the Flutter client writes/reads and what
`firestore.rules` / `storage.rules` authorise. Every finding below was confirmed
by reading the rule and the calling code, and then by an emulator test.

## Summary

| # | Area | Symptom | Kind |
|---|------|---------|------|
| 1 | `users/{uid}` create/update | Signup, profile save and cover save fail with `permission-denied` | client/rules drift |
| 2 | `groups/*/media`, `privateChats/*/media`, `fanWorks/*/*` | Every real upload fails with `storage/unauthorized` | client/rules drift |
| 3 | Group member list | No names/avatars for anyone but the viewer | client/rules drift |
| 4 | Invite candidate search | Returns nothing for every query | client/rules drift |
| 5 | `test:rules` | 2 failures, 1 of them order-dependent | test defect |
| 6 | `game_history` | Rule evaluation error on every read | test defect |

Findings 5 and 6 were failing before this branch and are fixed here. The
production rules for both were already correct.

## 1. `users/{uid}` allow-lists were missing five self-owned fields

`firestore.rules` allow-listed a subset of the fields the app actually writes.
`PubgetUser.toMap()` (`lib/features/authentication/models/pubget_user.dart`)
emits `coverUrl`, `favoriteQuote`, `animeTwin`, `socialLinks` and
`sectionPrivacy`, and `profileVisibility` is emitted on every save.

- **Create** used `hasOnly([...])` without those five keys, so
  `OnboardingProvider.saveProfile` → `createUserProfile` was rejected outright.
  Signup could not complete.
- **Update** used `changedOnly([...])` without `coverUrl` and the others, so
  `updateUserProfile` and the cover upload were rejected.

### Fix

The five fields were added to the create allow-list, and to the update
allow-list alongside the existing presentation fields. `profileVisibility` was
deliberately **left out** of the update allow-list: flipping privacy has a side
effect (avatar download-token rotation) that belongs to the
`updateSocialProfile` callable, and `firestore.rules.test.js` already asserts
the direct path is closed.

Validation was added in `validSelfProfilePresentation(...)` and mirrors
`functions/src/avatarPrivacy.js` exactly, so the direct-write path is never
laxer than the server-authorized one:

- `favoriteQuote` ≤ 200 chars, `animeTwin` ≤ 80 chars
- `coverUrl` ≤ 1024 chars and `http(s)://` or empty/null
- `socialLinks` ≤ 20 entries
- `sectionPrivacy` must be a map with exactly the nine boolean toggles the
  client model emits (`favorites`, `activity`, `friends`, `fans`, `works`,
  `groups`, `ratings`, `achievements`, `lists`)

### Related: the cover URL now goes through the callable

`coverUrl` is kept in the allow-list for tolerance, but the client no longer
relies on it. `FirebaseProfileRepository.uploadCover` uploads the bytes, then
persists the URL via the `updateSocialProfile` callable — the same validated
path `updateProfile` already used. The previous code wrote `users/{uid}` with
`{coverUrl: url}` directly, which orphaned a successfully uploaded object on
every failure. `uploadAvatar` still writes `avatarUrl` directly, because that
field *is* allow-listed.

## 2. Resumable uploads were denied by `allow update: if false`

`putData`/`putFile` use a resumable protocol: a `CREATE` followed by one or more
`UPDATE`s on the same object. Three media paths denied `update` outright, so the
first chunk landed and the second was rejected — surfacing as
`storage/unauthorized` on a request the user had every right to make.

This is the same root cause already diagnosed and fixed for `/edits` (see
`docs/EDITS_PLATFORM_DIAGNOSTIC.md`); the three paths below were simply missed.

### Fix

`allow update` is now open to the original uploader only:

- `groups/{groupId}/media/*_original.*` — group member **and**
  `isExistingUploader() && isNewUploader()`
- `privateChats/{chatId}/media/*_original.*` — chat participant, same two checks
- `fanWorks/{workId}/*` — draft owner only, same two checks

`isNewUploader()` pins `request.resource.metadata.uploadedBy` to the caller, so
an uploader cannot reassign ownership to another uid, and `isExistingUploader()`
requires the existing object to already belong to them. Cross-user overwrite
stays denied, and the `*_thumb.*` / `*_medium.*` pipeline variants remain
server-written only.

### Testing caveat

The Storage emulator exposes every `ref.put()` as a **create**-shaped
operation, so an `allow update` branch cannot be exercised from
`@firebase/rules-unit-testing`: re-uploading an existing object is evaluated
against `create` and fails the `resource == null` guard, not the update rule.
The tests therefore cover the guarantees that *are* reachable — owner upload
succeeds, other members are denied, ownership cannot be reassigned, pipeline
variants stay closed — and the `update` branches are justified by the
production resumable protocol. This limitation is documented in the test file.

## 3 & 4. Group member hydration and invite search read the wrong collection

`firestore.rules` restricts `users/{uid}` to its owner; display data for other
users lives in `public_profiles/{uid}`. Two client paths read `users` anyway:

- `FirebaseGroupMembersRepository._hydrateMemberProfiles` fetched
  `users/{member.uid}` for every member. Because the reads were inside a
  `Future.wait`, a single denial failed the whole batch, leaving the member list
  without names or avatars for anyone but the viewer.
- `lookupInviteCandidates` did a direct `users/{id}` lookup and then a
  `users.where('username', isEqualTo: handle)` query. `users` has no `list`
  rule at all, so the search always returned nothing.

### Fix

Both now use the client-readable projections: `public_profiles/{uid}` for
display data, and the `usernames/{normalized}` registry to resolve a handle to
a uid before reading the profile. A private profile is simply not a candidate,
which is the intended privacy behaviour rather than a new denial.

The `limit` parameter is retained for interface compatibility; the lookup is an
exact match and no longer applies a limit.

## 5. `test:rules` had an order-dependent failure

`test:rules` ran `firestore.rules.test.js` and `storage.rules.test.js` in one
`node --test` invocation, which executes files **concurrently** against the same
Firestore emulator. `firestore.rules.test.js` calls `env.clearFirestore()` in
`afterEach`, which wiped the `users/*` documents that the storage test had
seeded — so `profile covers require owner writes and mirror avatar privacy on
reads` failed on a public cover read while the private and owner cases passed.

Confirmed by reproducing the scenario in isolation, where it passes. Fixed with
`--test-concurrency=1` in `functions/package.json`.

## 6. `game_history` read rule errored on every document

`game history is readable only by the players who played it` failed with
`Property participants is undefined on object`. The rule is correct — the
server writes `participants: Object.keys(scores)`
(`functions/src/gamesDomain.js`). The fixture was not: the `before` hook
`.set()`-ed `game_history/game1` twice, and the second payload omitted
`participants`, wiping the field the assertions depend on. Removed the duplicate.

The rule itself was left as-is: it fails closed on a malformed document, which
is the right posture.

## Verified correct, no change

- **Custom roles.** `getMembership` reads `groups/{groupId}/roles/{role}` and
  populates `effectivePermissions`, so the client authority, the server
  callables and the rules agree. There is no role system to align.
- **Joined groups.** An earlier suspicion that the collection-group `members`
  query was broken was wrong: membership documents carry `uid`, the query
  filters on `uid`, and the `allow list` rule matches the same field.
- **Anime subcollections** (`anime_lists`, `anime_ratings`,
  `character_favorites`) are `signedIn()`-readable, matching client usage.
- **Notifications** and the anime cache are scoped to the caller's own uid.
- **`group_image` / `group_cover`** follow the Firestore owner gate correctly.

## Known gaps left in place

These are real but were not changed, because each is a behavioural decision
rather than a clear client/rules mismatch. Flagging for follow-up:

- `functions/src/avatarPrivacy.js` handles eight `sectionPrivacy` toggles and
  silently drops `lists`, while `ProfileSectionPrivacy.toMap()` sends nine. The
  rules-side validation added here requires all nine, so the callable path can
  still drop the `lists` toggle.
- `isApexOwner` in `functions/src/pubgetRanks.js` resolves
  `member.role || member.rankV2`, while every other path uses
  `rankV2 || role`. A member demoted from a legacy `role` to `rankV2` would be
  treated as apex by this one function.
- `GroupAuthority` does not apply a founder fallback in every helper, while the
  server and the rules do. Only reachable for a corrupted founder membership
  document, since legacy `role: 'founder'` already maps to `mikado`.

## Verification

```
# rules (Firestore + Storage emulators)
firebase emulators:exec --only firestore,storage --project demo-pubget-security \
  "cd functions && npm run test:rules"
  69 tests, 69 pass, 0 fail

# Cloud Functions unit tests
cd functions && npm test
  328 tests, 328 pass, 0 fail

# Flutter
dart analyze lib/features/groups/repositories/firebase_group_repositories.dart \
          lib/features/social/repositories/firebase_profile_repository.dart
  No issues found!
flutter test <11 group/social/profile test files>
  All tests passed!
```

Baseline on this branch before any change was 66 tests / 64 pass / 2 fail; the
two failures are #5 and #6 above.
