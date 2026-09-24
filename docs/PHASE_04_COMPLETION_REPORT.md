# PHASE 04 COMPLETION REPORT — Social Graph + Group Chat + Private Chat

Branch: `codex/pubget-phase-04-social-chat` (commit `7df5258`)
PR: https://github.com/sbikazis/pubget/pull/114 (open, not merged)
Base: `origin/main` (`5294de2`)

## A. Objective

Complete Phase 04 deliverables per `docs/PUBGET_MASTER_SPEC.md`: audit the real
implementation of the social graph (fans/friends/requests), group chat, and
private chat against the spec, close only the gaps that are real, and prove the
result with tests and builds. No Phase 05 work was started.

## B. Result / Verdict

**SHIPPABLE — all real Phase 04 gaps found by the audit were closed.** Private
chat now enforces the spec's Mutual-Fan-or-Friend gate on both server and
client, and friend-request cancellation is a first-class, security-checked
callable with a complete client UI path. All gates that this machine can run
pass (see G). One pre-existing Storage-rules test failure is tracked separately
(see J) and is unrelated to this branch.

## C. Spec sections audited against

- Master Spec §10.1 — Friendship + Fan system («علاقة معجبين متبادلة»، «إلغاء»).
- Master Spec §10.2 — Private chat gating.
- Firestore rules / Storage rules — server-authoritative model for
  groups/messages/media/privateChats/respects/friendships.
- Notification surface — push types and unread counters used by chat.

## D. Surfaces audited

- Server: `functions/src/socialGraph.js`, `functions/src/privateChat.js`,
  `functions/src/groupChat.js`, `functions/src/notificationBuilder.js`,
  `functions/src/notificationCallables.js`, `functions/src/notificationTriggers.js`,
  `functions/index.js`.
- Client: `lib/features/social/**` (models, repositories, provider, screens),
  group + private chat providers/repos, `AppStrings` l10n.
- Security: `firestore.rules` (chat + social write gates), `storage.rules`.

## E. Gaps found and their verdicts

| # | Gap | Verdict | Resolution |
|---|-----|---------|-----------|
| 1 | Server private-chat gate used `isFanEitherDirection` (one-way fan passed) instead of the spec's mutual-fan test | **Real** | `isFanMutual`: forward AND reverse ≥ FAN_THRESHOLD; message now "A Mutual Fan or Friend relationship is required to start a private chat." |
| 2 | Client `canStartPrivateChat` used `given \|\| received` (one-way fan passed) | **Real** | Now `given && received`; doc comment cites §10.1. |
| 3 | No dedicated `cancelFriendRequest`; the only cancel path was repurposing `respondToFriendRequest('reject')` when `requestedBy === uid`, and the friend-requests page had no outgoing section | **Real** | New transactional `cancelFriendRequest` callable (pending-only, requester-only, deletes canonical + legacy docs); page rewritten with Incoming/Outgoing sections, cancel action, loading/empty/error states, full EN/AR l10n. |
| 4 | Group chat 4000-char limit, system messages, receipts batching, welcome/admin activity cards | **Already correct** | Verified server-side; no change. |
| 5 | Firestore chat writes lacked server authority | **Not a gap** | Rules are already server-authoritative (`write: false` for messages/media/privateChats, server-only for respects/friendships); `cancelFriendRequest` only removes `friendships` docs already covered. |
| 6 | Notification push types / unread counters | **Already correct** | Verified `notificationBuilder/Triggers/Callables`; no change. |

## F. Files changed (17)

- `functions/src/privateChat.js` — Mutual-Fan-or-Friend gate.
- `functions/src/socialGraph.js` — `cancelFriendRequest` callable.
- `functions/index.js` — export wiring.
- `functions/test/privateChat.test.js`, `functions/test/socialGraph.test.js` — updated/added tests.
- `lib/features/social/models/social_models.dart` — mutual `canStartPrivateChat`, `userIdKey`.
- `lib/features/social/repositories/{social_repository,firebase_social_repository,unavailable_social_repository}.dart` — `cancelFriendRequest`.
- `lib/features/social/providers/social_provider.dart` — `cancelFriendRequest`.
- `lib/features/social/screens/{profile_page,friend_requests_page}.dart` — cancel wiring + rewritten requests page.
- `lib/core/l10n/app_strings.dart` — new EN/AR copy.
- `test/{social_test_support,social_provider_test,social_screens_test,edits_integration_test}.dart` — fakes + tests.

No changes to `firestore.rules`, `storage.rules`, or `firestore.indexes.json`.

## G. Gates

| Gate | Result |
|------|--------|
| `flutter analyze` | PASS — "No issues found!" |
| `npm run check` (functions) | PASS |
| `npm test` (functions, 251 tests) | PASS — 251/251 |
| Targeted Flutter (social/private-chat suites) | PASS — 26/26 |
| Broader Flutter (chat/group/notifications) | PASS |
| `flutter test` (full suite) | PASS — 611/611 |
| `npm run test:rules` (Firestore+Storage emulator) | **64/65** — see J |
| `flutter build apk --debug` | PASS — `app-debug.apk` built (Gradle 393.8s) |

Note: the emulator-based rules suite required a JDK 21. Only Temurin 17 was
installed, so Temurin 21.0.12.1 (x64 macOS) was downloaded to the session temp
dir and used via `JAVA_HOME` for the rules run.

## H. Out of scope (not started)

Phase 05 surfaces per the operating prompt: Anime Hub, Fan Works, Events, Games,
Mafia, Economy, Kirari, Reels. Nothing from Phase 05 was modified or tested.

## I. Notes

- Pending/uncommitted artifacts from prior phases (`.p01_*`, `.p02_*`,
  `.tmp_*`, `android/build/`) remain untracked and were deliberately not
  committed; the commit contains only the 17 intended files.
- The 4000-char group-message limit is enforced server-side; clients may keep
  their own soft limits.

## J. Known issue (pre-existing, NOT introduced by this branch)

`functions/test/storage.rules.test.js` #65 — "profile covers require owner writes
and mirror avatar privacy on reads" — fails with `storage/unauthorized` for
`users/cover-public/cover.jpg`. This branch touches no storage code: the rules
under test are byte-identical to `origin/main`. The failure lives in the
profile-cover/avatar-privacy surface (Phase 02 scope) and should be tracked as a
follow-up.

## K. Risks

- **Rules visibility**: this branch is un-merged and un-deployed; the
  pre-existing Storage cover failure will not block this PR but blocks a fully
  clean `test:rules` run until fixed.
- **Behavior change**: one-way fans can no longer start private chats. This is a
  deliberate spec alignment; any deployment note should call it out.
- **JDK**: the Firestore/Storage emulator now requires JDK 21+ (firebase-tools);
  that JDK was provisioned only into the session temp dir, not the system.

## L. How this was verified

- Server behavior proven via updated `privateChat.test.js` (one-way rejected,
  mutual accepted, friends-only re-checked per send) and new `socialGraph.test.js`
  (cancel deletes caller's pending; rejects unauthenticated/self/non-requester/
  non-pending).
- Client behavior proven via provider tests (mutual vs one-way gating; cancel
  removes outgoing request) and widget tests (outgoing section renders, cancel
  button triggers the callable).
- Full suites run, not sampled: functions 251/251, Flutter 611/611.

## M. Next phase readiness

Authorized to begin Phase 05 per the operating prompt (Anime Hub, Fan Works,
Events, Games, Mafia, Economy, Kirari, Reels) once #114 is reviewed/merged and
the Storage cover rule issue in J is scheduled for a fix.