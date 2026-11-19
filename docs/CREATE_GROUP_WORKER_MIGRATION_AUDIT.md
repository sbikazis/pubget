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

## Achievement delivery design (required before Worker cutover)

### What the existing evaluator actually does

For `group_created`, `achievements.evaluate` runs these effects in order:

1. `ensureAccountCreated(uid)` writes `user_achievement_stats/{uid}.accountCreatedAt` when absent.
2. `evaluateThreshold(uid, "group_created")` sets first-action progress and may unlock `the_threshold`.
3. `evaluateKeeper(uid)` marks the current UTC day active, updates keeper progress, and may unlock `keeper_of_time`.
4. `evaluateShogun(uid, metadata)` updates Shogun progress. The createGroup caller currently supplies only `groupId`, so it does not establish the 50-member, age, message, or seven-day conditions.
5. `evaluateCrown(uid, metadata)` updates Crown progress from existing stats; group creation itself does not prove the 90-day conditions.

The unlock document is protected by a Firestore transaction and an existing unlock is not re-awarded in the normal sequential path. However, the evaluator as a whole is **not an exactly-once event processor**: progress/stats writes happen separately, and reward/notification side effects occur after the unlock transaction. Therefore a generic retry-safe outbox cannot be claimed merely because unlock documents are deduplicated.

### Required outbox contract

The group transaction must atomically create all of the following:
- the group, founder membership, canonical roles, and optional character reservation;
- the caller's idempotency-key record;
- one immutable outbox event at `group_creation_events/{eventId}`, where `eventId` is deterministically derived from the authenticated UID and idempotency key (never from caller-supplied UID).

The event payload is versioned and contains only server-derived identity plus the committed `groupId`, event type `group_created`, and creation timestamp. It must not contain client-controlled entitlement values or claim achievement eligibility.

### Delivery and retry semantics

- Delivery is at-least-once, not exactly-once. A lease/claim with expiry permits recovery after Worker termination.
- A stable event receipt must be written before acknowledging completion. The receipt key is the deterministic event ID.
- Each achievement operation must be safe under replay. The existing threshold and active-day logic are based on monotonic/absolute state, but unlock reward delivery needs a separate durable idempotency key (for example `achievement:{uid}:{achievementId}`) enforced by the economy ledger, not just by an in-memory flag.
- Notifications must use their stable notification ID and verify that the notification builder treats repeated IDs as idempotent.
- A crash between the unlock document and economy reward must be recoverable: the reward ledger needs its own deterministic reference and a retryable pending/completed state. Swallowing reward errors, as the current evaluator does, is not sufficient evidence of durable delivery.
- The event may be marked complete only after all required effects are either completed or durably handed to independently retryable effect records.
- Poison events need bounded retries and a visible dead-letter/error state; never silently delete them.

### Migration decision

Do not call the current Firebase Admin `achievements.evaluate` from a Worker by inventing an HTTP bridge, and do not port a partial evaluator that silently omits economy, notifications, or composite achievements. Before switching the Flutter client, implement and test the outbox consumer plus idempotent effect ledger (or retain a verified server-side consumer that can run on the current Firebase plan). Until then, keep the existing callable path as the rollback path and keep the Worker route unexposed to the client.

### Required tests for this contract

- group transaction rollback leaves no group, membership, roles, character reservation, idempotency record, or outbox event;
- same-key retry returns the original group and does not enqueue a second event;
- concurrent same-key requests create one group and one event;
- event delivery retry after a simulated crash does not duplicate threshold progress, active-day count, achievement unlock, reward, or notification;
- crash after each individual side effect resumes from durable state;
- expired lease is reclaimable; active lease is not concurrently claimed;
- poison event remains inspectable and cannot block unrelated events;
- event acknowledgement cannot occur before all effects are durably complete.

Status: this section is a source-based design contract, **not an implementation or test-pass claim**.
