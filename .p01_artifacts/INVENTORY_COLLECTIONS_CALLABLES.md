# Phase-01 Inventory: Collections and Callables

Date: 2026-09-21
Scope: server (`functions/`) resolved against the Flutter client call surfaces.
Status: verified against `functions/index.js` (146 exports) and the client repositories.

## 1. Top-level collections (roots)

| Collection | Description | Written by |
|---|---|---|
| `users` | User profiles; own `notifications`, `transactions`, `daily_rewards`, `inventory`, `anime_lists`, `character_favorites`, `anime_custom_lists`, `anime_ratings` subcollections; `coinsBalance` wallet | Callables + auth |
| `profiles` / `public_profiles` | Public profile projections (separate from private `users` docs) | `syncPublicProfile` trigger |
| `groups` | Chat groups; subcollections `members`, `messages`, `invites`, `media`, `eventFeed` | Callables |
| `privateChats` | 1:1 chats; `messages` subcollection | Callables |
| `friendships` | Pair relationships incl. `status` | Callables |
| `respects` | Respect relations `fromUserId`->`toUserId` | Callables |
| `events` | Events; `participants`, `responses`, `comments` subcollections | Callables |
| `edits` | Fan edits + `editUploadKeys` idempotency ledger; `comments` subcollection | Callables |
| `games` | Games (guess/chain/emoji + mafia) + `game_request_idempotency` root | Callables + schedulers |
| `game_history` | Completed game records | Schedulers/engine |
| `fanWorks` | Fan works; `revisions`, `comments`, `likes` subcollections | Callables |
| `mafia_games` | Legacy/reserved mafia container (mafia writes to `games`) | – |
| `economyTransactions` | Economy ledger (unique `txId` per tx) | Callables |
| `_system` | Internal scheduler state (`discoveryScheduler`) | Schedulers |
| `reels`, audio domain | NOT wired into `index.js` (no import) — dead/legacy | – |

Notes:
- `collectionGroup("members")` and `collectionGroup("fcmTokens")` service membership/FCM lookups.
- `wallet` = `users/{uid}.coinsBalance`; daily caps/large ledger live under `_system`/`users/{uid}` subcollections (`daily_rewards`, `transactions`).

## 2. Server exports (146 total = 133 onCall + 13 onSchedule/onDocument)

### On-call handlers (133), grouped by module
- **social**: `sendFriendRequest`, `respondToFriendRequest`, `removeFriend`, `blockUser`, `unblockUser`, `giveRespect`, `getDiscoveryFeed`
- **profile/avatar**: `syncAvatarPrivacy`, `syncPublicProfile`, `updateSocialProfile`
- **groups**: `createGroup`, `joinGroup`, `requestToJoin`, `acceptJoinRequest`, `rejectJoinRequest`, `leaveGroup`, `kickMember`, `banMember`, `unbanMember`, `changeRole`, `updateRolePermissions`, `disbandGroup`, `promoteGroup`, `warnMember`, `createGroupInvite`, `sendGroupMessage`, `editGroupMessage`, `deleteGroupMessage`, `forwardGroupMessage`, `addGroupMessageReaction`, `pinGroupMessage`, `markGroupMessagesRead`, `markGroupMessagesDelivered`, `updateGroupChatBackground`, `updateGroupSettings`
- **private chat**: `startPrivateChat`, `sendPrivateMessage`, `deletePrivateMessage`, `deletePrivateChat`, `markPrivateMessagesRead`, `markPrivateMessagesDelivered`
- **events**: `previewEvent`, `saveEventDraft`, `publishEvent`, `cancelEvent`, `endEvent`, `resolveEvent`, `joinEvent`, `leaveEvent`, `submitEventResponse`, `reactToEvent`, `archiveEvent`, `addEventComment`, `editCommentAction`, `getEventAnalytics`
- **edits/media**: `startEditUpload`, `finalizeEditUpload`, `retryEditProcessing`, `deleteEdit`, `getEditFeed`, `likeEdit`, `repostEdit`, `recordEditView`, `recordEditSignal`, `startEditPlayback`, `addEditComment`, `confirmFanWorkMedia`, `startFanWorkMediaUpload`, `saveFanWorkDraft`, `deleteFanWorkDraft`, `publishFanWork`, `archiveFanWork`, `revisePublishedFanWork`, `requestFanWorkRemoval`, `rateFanWork`, `likeFanWork`, `bookmarkFanWork`, `addFanWorkComment`, `fanWorkCommentAction`
- **games (system)**: `initializeGame`, `createGame`, `joinGame`, `cancelGame`, `leaveGame`, `startGame`, `pauseGame`, `resumeGame`, `submitGameAction`, `endGame`
- **games (mafia)**: `createMafiaGame`, `joinMafiaGame`, `startMafiaGame`, `submitMafiaAction`, `sendMafiaChat`, `heartbeatMafia`, `leaveMafiaGame`
- **economy**: `claimEconomyReward`, `purchaseStoreItem`, `equipCosmetic`, `unequipCosmetic`, `getEconomy`, `getEconomyTransactions`, `getPremiumEntitlement`, `restorePremiumPurchases`
- **anime**: `getAnimeList`, `setAnimeListEntry`, `removeAnimeListEntry`, `deleteAnimeRating`, `upsertAnimeRating`, `getCharacterFavorites`, `setCharacterFavorite`, `getCustomAnimeList`, `createCustomAnimeList`, `updateCustomAnimeList`, `deleteCustomAnimeList`, `getCustomAnimeLists`, `getCustomListsForAnime`, `addAnimeToCustomList`, `removeAnimeFromCustomList`, `postCharacterDiscussion`, `deleteCharacterDiscussion`
- **notifications**: `markNotificationRead`, `markAllNotificationsRead`, `registerFcmToken`, `unregisterFcmToken`
- **achievements**: `getAchievements`
- **ownership/moderation/misc**: `reserveRoleplayCharacter`, `releaseRoleplayCharacter`, `prepareOwnershipTransfer`, `transferOwnership`, `reportFanWork`, `reportGroupMessage`, `reportAnimeReview`, `getInventory`
- **economy/inventory utility**: `getInventory` (intentionally server-only; no client caller)

### Scheduled / document-trigger exports (13)
`processExpiredGames`, `processEventLifecycle`, `refreshGroupActivityScores`, `processExpiredLobbies`, `processPhaseTransitions`, `onFriendRequest`, `onNewGroupMessage`, `onNewPrivateMessage`, `onRespectReceived`, `onJoinRequest`, `onJoinRequestDecision`, `syncPublicProfile`, `syncAvatarPrivacy`

## 3. Client -> server match result

- **Every resolved client callable has a server export. No client-only mismatches.**
- Server-only export: `getInventory` (intentional utility, no client caller).
- Dead/legacy client code with NO server counterpart (do not wire, do not build): `reels` audio calls (`extractReelAudio`, `listReelAudios`, `getReelAudio`, `useReelAudio`, `removeReelAudio`, `searchReelAudios`); the `FirebaseEditsRepository._callable(..., reels: true)` wrapper is identity when `reels:false` (production default) and `reels:true` never executes in production.
- Ownership/membership/role gates are implemented server-side per sensitive callable (see IDEMPOTENCY_CONTRACT.md and the rules coverage matrix in RULES_GATE.md).