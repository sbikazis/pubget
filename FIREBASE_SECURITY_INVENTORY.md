# Firebase security inventory

Audit date: 2026-08-31  
Firebase project: `pubget-aaf27`

This inventory is derived from the Flutter client, Firebase rules, Cloud Functions, emulator tests, and the production deployment receipts captured during the security rollout. It does not claim that an unreferenced production resource is absent unless it was listed through Firebase CLI/API.

## Authentication

- Email/password registration and sign-in.
- Google sign-in.
- Sign-out, current-user lookup, and account-ban rejection.
- No anonymous, phone, Apple, or client custom-token flow was found.
- Firestore admin authorization is designed around an `admin == true` custom claim; no client-writable Firestore role is accepted as an admin bit.
- No code that assigns the admin custom claim was found in this repository.

Primary evidence:

- `lib/services/firebase/auth_service.dart`
- `firestore.rules`

## Firestore resources

| Resource | Typical subresources | Client access boundary |
|---|---|---|
| `users/{uid}` | `notifications`, `stickers`, `daily_rewards`, `transactions`, `rewards`, `user_mafia_history` | Root is self-readable; profile fields are self-editable; finance, subscription, moderation, referral, and counters are server-owned |
| `public_profiles/{uid}` | None | Authenticated read; server-only writes |
| `groups/{groupId}` | `members`, `requests`, `invites`, `messages`, `games`, `characters` | Authenticated/group-member/founder/moderator checks by operation |
| `privateChats/{chatId}` | `messages` | Participants only |
| `edits/{editId}` | `comments`, `viewers`, `watch_events` | Rule-specific author/authenticated access |
| `user_interactions/{uid}` | `interactions` | Owner-scoped |
| `user_seen/{uid}` | `seen_edits` | Owner-scoped |
| `respects/{id}` | None | Canonical sender/target identity checks |
| `fans/{id}` | None | Canonical identity checks |
| `promotions/{id}` | None | Rules-defined surface |
| `physical_products/{id}` | None | Read-only client surface |
| `mafia_games/{gameId}` | `players`, player-private role data, `night_actions`, `votes`, `events`, `chat` | Membership/player/phase checks; authoritative state is server-only |
| `mafia_history/{gameId}` | None | Currently readable by every authenticated user; see High finding SEC-H-01 |

Central path constants do not fully represent every path used by services and rules. In particular, `user_interactions`, `user_seen`, `physical_products`, `rewards`, `mafia_history`, and several Mafia subcollections are referenced directly.

## Sensitive fields and roles

Sensitive user/account fields include:

- `email`, `fcmToken`
- `coinsBalance`
- `subscriptionType`, `premiumSince`, `premiumExpiresAt`, `autoRenewPremium`
- `isBanned`
- referral state and social counters
- custom group/member limits

These fields remain on private `users/{uid}` documents. Public display data is projected to `public_profiles/{uid}` by `syncPublicProfile`.

Group roles observed:

- `founder`
- `sensei`
- `hakusho`
- `senpai`
- `member`

The first four are treated as moderator roles where applicable. Message role, premium badge, display name, and avatar are checked against trusted member/public-profile data rather than accepted blindly from a sender payload.

Mafia roles and teams are written under player-private data and are server-controlled. Client writes represent intent only: joining, heartbeat, voting, night target, and chat.

## Storage resources

| Path | Boundary |
|---|---|
| `avatars/{uid}.jpg` | Owner write/delete; authenticated read |
| `users/{uid}/avatar.jpg` | Owner write/delete; authenticated read |
| `users/{uid}/stickers/{file}.png` | Owner write/delete; authenticated read |
| `groups/{groupId}/group_image.jpg` | Founder/owner write/delete |
| `groups/{groupId}/chat_background.jpg` | Founder/owner write/delete |
| `groups/{groupId}/characters/{uid}.jpg` | Matching UID and group membership |
| `groups/{groupId}/chat/{uid}/{file}` | Matching uploader UID and membership |
| `groups/{groupId}/media/{file}` | Group member; uploader metadata protects updates/deletes |
| `groups/{groupId}/voices/{file}.m4a` | Group member; uploader metadata and MIME/size limits |
| `private_chats/{chatId}/{uid}/{file}` | Matching participant/uploader |
| `privateChats/{chatId}/media/{file}` | Participant; uploader metadata protects updates/deletes |
| `privateChats/{chatId}/voices/{file}.m4a` | Participant; uploader metadata and MIME/size limits |
| `edits/{uid}/v_*.mp4` | Owner write/delete; authenticated read |
| `edits/{uid}/t_*.jpg` | Owner write/delete; authenticated read |

There is no catch-all Storage allow rule. Unsupported paths are denied.

Known mismatch: `StoragePaths.privateChatBackground()` documents `privateChats/{chatId}/backgrounds/{uid}.jpg`, but no Storage rule grants that path. A client attempt is expected to be denied until the contract is aligned.

## Cloud Functions

Production functions reported as `ACTIVE` by the session-transcript-derived `firebase functions:list` result after the rollout (see `PRODUCTION_EVIDENCE_20260831.md`):

- `syncPublicProfile`
- `disbandGroup`
- `leaveMafiaGame`
- `onNewGroupMessage`
- `onNewPrivateMessage`
- `onJoinRequest`
- `processExpiredLobbies`
- `processPhaseTransitions`
- `markDisconnectedPlayers`

Security boundaries:

- Callable functions require Firebase Authentication and validate bounded identifiers.
- `disbandGroup` verifies founder ownership, marks deletion pending transactionally, removes Storage under the group prefix, then performs recursive Firestore deletion.
- Message triggers re-fetch trusted users, groups, membership, and chat participants before sending FCM.
- Scheduled Mafia functions and resolvers use Admin SDK authority and must therefore validate state internally.

## Indexes and deployment resources

Tracked indexes:

- `respects(fromUserId, toUserId, __name__)`
- `mafia_games(status, countdownEndsAt, __name__)`
- `mafia_games(status, phaseEndsAt, __name__)`

Configuration:

- Firestore rules: `firestore.rules`
- Firestore indexes: `firestore.indexes.json`
- Storage rules: `storage.rules`
- Functions source: `functions/`
- Hosting is configured but was not included in the security deployment.
