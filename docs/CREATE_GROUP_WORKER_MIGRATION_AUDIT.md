# createGroup Worker migration audit

Status: implementation contract review; no production behavior changed.

## Current call path

- Create wizard: `lib/features/groups/presentation/pages/create_group_wizard/create_group_wizard_page.dart`
- Provider: `lib/features/groups/providers/group_provider.dart`
- Repository: `lib/features/groups/repositories/firebase_group_repositories.dart`
- Current backend: `functions/index.js` exports `createGroup` as a Firebase callable in `us-central1`.
- Domain implementation: `functions/src/groupsDomain.js`.

The reported `UNAVAILABLE` is consistent with a callable/backend availability failure, but source inspection alone does not prove whether the deployed callable is missing, unhealthy, misconfigured, or failing downstream. Do not present a root cause until logs or a controlled request establish it.

## Existing input contract

The server validates:
- authenticated UID;
- name (non-empty, max 80), description (max 500), rules (max 4000);
- type: `public`, `animeRoleplay`, `openRoleplay`;
- join policy: `open`, `approval`, `inviteOnly`;
- boolean `isSearchable`;
- optional anime ID (required for `animeRoleplay`);
- optional HTTP(S) image, cover and chat-background URLs;
- optional welcome message (max 500);
- founder character for roleplay groups; no character for public groups;
- optional idempotency key (max 80).

The client wizard currently creates a per-wizard idempotency key and sends it in `GroupDraft.toMap()`.

## Atomic write contract to preserve

The existing Admin SDK transaction:
1. Reads `users/{uid}` to derive the server-entitled member ceiling from `customMaxMembersLimit`; the requested value can only reduce that ceiling (default 100, hard maximum 500).
2. Creates `groups/{groupId}` with normalized name/searchName, description, image/cover, type/anime, founder, migrationVersion=2, membersCount=1, maxMembers, join policy, searchable flag, timestamps, chat background, welcome message, rules, activityScore=0 and risingEligible=false.
3. Creates `groups/{groupId}/members/{uid}` as the founder with mikado rank, manual seat, timestamps, zero invite counts, and optional roleplay character.
4. For roleplay, atomically reserves `groups/{groupId}/characters/{characterKey}` with founder UID and character metadata.
5. Creates every canonical role document from `ROLES` using `roleDefinition(role)`.
6. When supplied, creates `users/{uid}/groupCreateKeys/{idempotencyKey}` pointing to the created group.

These writes must remain atomic. The Worker must verify the Firebase ID token signature and project claims before deriving UID; it must never accept a caller-supplied UID or entitlement limit. Firestore writes must use the existing private service-account secret and least-privilege Firestore access.

## Post-commit behavior and risks

- After the transaction, the callable reads the created group and invokes `achievements.evaluate({type: 'group_created', ...})`. This is a real side effect: account/threshold/keeper progress plus Shogun and Crown evaluation. A Worker migration must not silently discard it. Design a durable, idempotent event handoff or an explicitly reviewed replacement before claiming parity.
- If no idempotency key is supplied, current code takes a non-idempotent path. The active wizard supplies a key, but the backend should safely handle absent/invalid keys or the contract should make them required.
- The current callable's post-transaction achievement work can fail after the group has already committed. The client may see an error even though creation succeeded; idempotent replay must return the original group and must not create another.
- The `reused` local is set but not used. A replay should verify that the referenced group still exists and return a clear conflict/not-found result if not.
- Firestore rules intentionally do not authorize the client to create the modern group schema directly; do not work around the callable failure by allowing broad client writes.

## Regression coverage required before PR review

- all validation cases above, including invalid type/policy/URLs and roleplay character requirements;
- atomic founder membership, group document, all role documents and character reservation;
- entitlement-derived maxMembers (default, custom, upper bound, and lower requested value);
- idempotent retry returns the same group without duplicate writes;
- concurrent same-key requests cannot create two groups;
- character collision and partial transaction failure leave no partial group;
- Firebase token missing/invalid/wrong-project rejected before Firestore access;
- achievement handoff is durable and idempotent;
- Worker route and Flutter repository mapping preserve current Group model response;
- client error mapping distinguishes authentication, validation, conflict, service unavailable and genuine offline connectivity.

## Release boundary

This branch is isolated from `main`. No Worker deployment, Firebase deployment, production data mutation, Firebase billing upgrade, Firebase Storage deletion, or relaxation of Firestore rules is part of this audit.
