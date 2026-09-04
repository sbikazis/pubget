# Pubget product engines

Games, Events, and Achievements are separate domains. They share Economy and Notifications through integration services. They never write group chat documents.

## Game engine architecture

Generic lobby state lives in `games/{gameId}`. Specialized rules live in Cloud Functions (`functions/src/gameEngines/`). Flutter renders `publicState` and a self-only `private/{uid}` projection. Secret answers live in `games/{id}/secret` and are not client-readable.

| Type | Collection | Min–max | Engine |
|---|---|---|---|
| Guess Character | `games` | 2–2 | `guessCharacter.js` |
| Anime Chain | `games` | 2–8 | `animeChain.js` |
| Emoji Anime Guess | `games` | 2–4 | `emojiAnimeGuess.js` — server-owned catalog emoji clues, one guesser per turn |
| Mafia | `mafia_games` | 4–16 | `mafia/` |

Mafia is not created through `createGame`. The Flutter registry marks it implemented and routes to `/mafia/{id}` via `createMafiaGame`.

## State machine

Generic games: `draft → waiting → active ⇄ paused → completed | cancelled`.

Server phases for quiz/chain/emoji engines are stored in `currentPhase` (`waiting`, `round`, `resolution`, `game_over`). Invalid transitions are rejected. `stateVersion` plus optional `payload.stateVersion` reject stale clients.

Mafia phases: `waiting → starting → night → day → discussion → voting → execution → night`, with `cancelled` from a valid cancel and `finished` after WIN_CHECK. ROLE_REVEAL is `starting` plus private role assignment. Four-player classic games assign one Mafia plus Doctor and Detective so the match does not start at parity. Vote ties spare everyone. Town wins when no Mafia remain. Mafia wins at parity/majority.

## Server authority

The client may request join, start, submit, vote, or leave. Cloud Functions decide validity, score, winner, role, timer expiry, rewards, and achievement grants. Clients never write `score`, `winner`, `role`, `deadlineAt`, or economy balances.

Timers use server `deadlineAt` / `phaseEndsAt`. Clients only render countdowns.

## Mafia architecture

Components: `lobbyManager`, `roleAssigner`, `phaseFlow`, `phaseScheduler`, `nightResolver`, `voteResolver`, `winConditionChecker`, `rewardDistributor`, `historyWriter`, `disconnectHandler`.

Roles (server-assigned, private under `mafia_games/{id}/players/{uid}/private/data`): Mafia, Citizen, Detective, Doctor when player count supports them.

Night actions and votes are idempotent document IDs (`uid_n{n}`, `uid_d{d}`). Vote ties spare everyone. Town wins when no Mafia remain. Mafia wins at parity/majority. Disconnects set `isDisconnected`; the scheduler does not freeze the game on a missing client.

History is written after completion without exposing live private roles.

## Event lifecycle

`functions/src/eventsDomain.js` owns create, participate, expire, and finalize. Maximum lifetime is 7 days. Participation is idempotent and rejected after `endAt`. `processEventLifecycle` finalizes expired events, writes results, and notifies. UI hides submit when `isInteractable()` is false; the backend still enforces expiry.

## Achievement architecture

Catalog and unlocks are server-side (`achievementsDomain.js`). Triggers: first group, first edit, first friend, first fan, first event participation/win, first game win, creator milestone (fan work), community milestone (finish a game). Grants are idempotent on `user_achievements/{uid}/items/{id}`.

## Reward integration

Coins go through the existing economy ledger. Game wins use `earn_game`. Achievement coins use `earn_achievement` (5 coins, daily cap). Deterministic `transactionId(type, userId, referenceId)` prevents duplicate payouts. Clients never mutate `users/{uid}.coinsBalance`.

## Idempotency

Game actions use `clientActionId`. Mafia night/vote docs overwrite the same id. Achievement unlocks create-if-missing. Economy rewards use deterministic transaction ids. Duplicate scheduler ticks no-op when the phase/version already advanced.

## Security

- `games/{id}/secret`: no client access
- `games/{id}/private/{uid}`: self-read only
- Mafia private role docs: self-read only
- `user_achievements/{uid}`: self-read, no client write
- Scores, winners, phases, timers, rewards: Functions-only writes

## Recovery

Interrupted transitions resume from persisted `status`, `currentPhase`, `stateVersion`, and deadlines. `processExpiredGames` (every minute) advances timed-out quiz/chain/emoji rounds. Mafia `phaseScheduler` advances expired phases. A vanished client cannot leave a game stuck.

## Chat isolation

Games and events emit domain events / compact notifications. They do not write `groups/{id}/messages`.
