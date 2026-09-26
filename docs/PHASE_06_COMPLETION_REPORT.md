# PHASE 06 COMPLETION REPORT — Group Games + Mafia

Branch: `codex/pubget-phase-06-games-mafia`
Base commit at branch point: merge of Phase 05, PR #115
Workspace: `pubget` (Flutter client + `functions` Cloud Functions)

## A. Objective

Close the Group Games and Mafia axes end to end: one canonical Anime catalog behind every game,
three server-owned game engines that a real client can actually play, the Mafia social-deduction
domain (7–15 players, closed roles, Game Center only, disconnect handling), and the Game Center
sections the spec enumerates. Every change is backed by a runnable gate, and the report states
verification limits instead of claiming runs that did not happen.

## B. Result / Verdict

**PASS WITH NOT VERIFIED.**

All gates that run in this workspace pass:

| Gate | Result |
|------|--------|
| `flutter analyze --no-pub lib` | No issues found |
| `flutter analyze --no-pub test` | No issues found |
| Flutter tests for every changed Games/Mafia file | 40 passing |
| Full `flutter test` | 629 passing, 0 failing (see §L) |
| `functions/npm run check` | Passed |
| `functions/npm test` | 305/305 passed |

Two items are **NOT VERIFIED** for environment reasons, not open defects:

1. `npm run test:rules` (Firestore/Storage emulator) cannot boot: `firebase-tools` requires JDK 21
   and only Temurin 17 is installed. This phase **does** change `firestore.rules` (§I), so the new
   rule is reviewed and unit-shaped but not executed. This is the one gap a reviewer must close.
2. `flutter build apk --debug` is not re-run for the final client state; the last successful debug
   build predates the client work in §E.

## C. Spec sections audited against

Source of truth: `docs/PUBGET_MASTER_SPEC.md`.

| Spec § | Requirement | Where it landed |
|--------|-------------|-----------------|
| §12.1 | Group Games: creator, waiting room, timers, chat-card replacement, timeout leaves nothing behind | `functions/src/gamesDomain.js` (committed in `4dcd75b`) |
| §12.2 | One canonical catalog, not three provider lists; provider lookups never inside a transaction | `animeCatalogDomain.js`, `gameEngines/helpers.js` (E1) |
| §12.3 | Real IDs only: a typed title can never become game state | `searchAnimeCatalog` / `searchCharacterCatalog` + `resolveSubmission` (E2) |
| §12.4 | Server owns the outcome; the client renders it | engines + `GameResultPanel` (E3) |
| §13.2 | Mafia: closed roles, server-assigned, no reassignment after start | `roleAssigner.js`, `checkWinCondition` (E4) |
| §13.3 | Mafia is Game Center only | `createMafiaGame` callable + client route (E5) |
| §13.4 | Night/day/vote phases, server timers, disconnect handling | `phaseFlow.js`, `nightResolver.js`, `voteResolver.js`, `disconnectHandler.js` (F1–F4) |
| §13.5 | 7–15 players | `MafiaLimits`, server clamp (F5) |
| §14 (Economy) | Loss 2, draw 5, win 7–10, idempotent, server-side | `gamesDomain.js` settlement (committed) |
| §302 | Game Center: Available · Active · Waiting · Recent · History · Rules, all four games never disabled | `game_list_screen.dart` (G1) |
| §302 | Per-game info: players, duration, difficulty, win condition, type | `game_details_screen.dart` (G2) |
| §667 | Any rules change ships with an emulator test | rule added, emulator NOT VERIFIED (§B) |

## D. Surfaces audited

- `lib/features/games/**` live v1 client (the v2 Games files are unreachable and were left alone).
- `lib/features/mafia/**` live client.
- `functions/src/gamesDomain.js`, `functions/src/gameEngines/**`, `functions/src/animeCatalogDomain.js`.
- `functions/src/mafia/**` (domain, roles, night, vote, leave, disconnect, win condition).
- `firestore.rules` games and mafia_games paths.
- Callables exported from `functions/index.js`.

## E. Games work delivered (this session)

### E1. The live client could not search the catalog at all
`searchAnimeCatalog` and `searchCharacterCatalog` existed on the server, but no live client code
called them: the only caller in the repository was the unreachable
`game_room_v2_screen.dart`. Games therefore had no way to name a real Anime or Character.

- `GameRepository.searchAnime` / `searchCharacters` + Firebase implementation
  (`firebase_game_repository.dart`) and the `UnavailableGameRepository` fallback.
- `AnimeSearchItem` / `CharacterSearchItem` models, so a server-owned ID is stored verbatim.
- `GameCatalogProvider` (`game_catalog_provider.dart`): debounced 350 ms, per-query result cache,
  stale-response drop, disposal-safe.
- `CatalogSearchPicker` (`catalog_search_picker.dart`): search field, skeleton while loading,
  explicit empty copy, error copy.
- Registered in `pubget_app.dart`.

### E2. `guessCharacter` was unplayable in the live client
The shipped panel spoke a protocol the engine never speaks: it read `publicState.prompt`,
`prompt.choices`, `answeredPlayerIds`, `lastReveal`, `publicState.scores`, and submitted
`guess` with `choiceId` for every player at once. The real engine
(`functions/src/gameEngines/guessCharacter.js`) is strictly turn based and writes
`phase: selection | ask | answer`, `players[uid].selected`, `currentPlayerId`,
`answeringPlayerId`, `question`, `answerOptions`, `lastAction`, and accepts only
`select` / `ask` / `answer` / `guess` with a resolved `characterId`.

The `selection` phase had no UI anywhere in the live client, so a `guessCharacter` game could never
leave selection. `GuessCharacterPlay` is now rewritten against the real contract:

- `selection`: catalog picker submits `select` with a real `characterId`; a player who already
  chose is locked out with explicit copy.
- `ask`: only `currentPlayerId` gets the ask field and the guess picker; everyone else sees the
  question and `lastAction` and no input.
- `answer`: only `answeringPlayerId` gets Yes/No submitting `answer`.
- `GameActionTypes.ask` / `.answer` added; `stateVersion` is carried on every action.

### E3. `emojiAnimeGuess` let the clue owner submit an impossible guess
The engine rejects the turn owner's guess (`functions/src/gameEngines/emojiAnimeGuess.js`: "The
turn owner cannot guess") and allows one guess per player per round, but the client enabled the
field for the owner and ignored `answeredPlayerIds`. Both are now gated, the locked copy is shown,
and the input clears when `turnIndex` advances so a resolved guess is never resubmitted as a
duplicate.

### E4. `animeChain` never cleared its title
The chain rejects a duplicate title, and the field kept its text after a successful move, so the
next submit was guaranteed to fail. The field now clears when the chain length changes, and the
score is shown.

### E5. Lifecycle and pause/resume
`GameStatus` now maps the server vocabulary (`CREATED/WAITING/STARTING/IN_PROGRESS/COMPLETED/
CANCELLED`) through `wireName`, `WAITING` and `STARTING` are both lobby states, and the pause/resume
repository, provider, and event surface was removed because the server has no such transition.

## F. Mafia work delivered (earlier commits, restated for the record)

- `3265c88` — 7–15 contract, SAMURAI+ transactional creation gate, deterministic closed-role
  distribution, waiting/active leave, below-minimum cancellation, idempotent night and vote
  resolution with `resolvedNights` / `resolvedVoteRounds`.
- `ec63477` — night resolution made a legal Firestore transaction (document IDs discovered outside,
  every document re-read inside; only `tx.get` is used), public elimination role reveal, atomic
  final role reveal on the same transaction as the terminal write, shared `roleLabels.js`.
- `ba8e244` — creation gated on the §13.2 rank floor alone (adding `manageGames` would silently
  raise the real minimum to DAIMYŌ), heartbeat rejected after leave, Doctor repeat-target validation
  ordered before any staged write, misleading `lastWordsUntil` removed.

## G. Game Center work delivered (this session)

§302 enumerates six sections and requires the four games to stay visible. The live client had only
Live / Waiting / Mine.

- **G1** `game_list_screen.dart` now has Available · Live · Waiting · Recent · History · Rules.
  Available always lists all four implemented games including Mafia (Mafia is `implemented` but not
  `genericCreate`, so a new `GameTypeRegistry.all` was added rather than disabling it). Loading,
  empty, error, and offline states stay attached to the data tabs only, because Available is never
  empty.
- **G2** `game_details_screen.dart` shows difficulty and the win condition next to the existing
  player count, timer, and rounds line.
- **G3** Recent and History read `game_history`, which only the server writes, so a client cannot
  display a result the server did not record. `GameRepository.getHistory` uses
  `where('participants', array-contains: userId)` with **no** `orderBy`, because ordering that query
  would require a composite index this phase cannot deploy and prove; newest-first is applied from
  the loaded documents in both the repository and `GameListProvider`, and Recent is a prefix of
  History (`GameListProvider.recentLimit`).
- **G4** `firestore.rules` gained `match /game_history/{gameId}` — read only for a signed-in user
  listed in `resource.data.participants`, never client-writable. A client write to a history
  document was already denied and still is.

## H. Client contract consistency fixes

- `MafiaLimits.minPlayers = 7` / `maxPlayers = 15` is now the single client source of truth. The
  Game Center lobby dropdowns had hard-coded `4..16` and `GameTypeRegistry` advertised Mafia as
  4–16, both of which contradicted the spec and the server clamp.
- The create page accepts an `initialType`, so the Available Games button opens the game the player
  actually tapped instead of always defaulting to Guess the Character.
- Difficulty, win condition, and per-type rules text live on `GameTypeSpec` as presentation only;
  the server still decides every outcome.

## I. Files changed (client, this session)

- `lib/features/games/models/game_models.dart` — `AnimeSearchItem`, `CharacterSearchItem`,
  `GameHistoryEntry`, `ask`/`answer` action types.
- `lib/features/games/models/game_type_registry.dart` — `winCondition`, `rules`, `all`.
- `lib/features/games/providers/game_catalog_provider.dart` (new).
- `lib/features/games/repositories/{game_repository,firebase_game_repository,unavailable_game_repository}.dart`.
- `lib/features/games/screens/game_list_screen.dart`, `game_details_screen.dart`,
  `game_create_page.dart`.
- `lib/features/games/widgets/game_play_panels.dart`, `catalog_search_picker.dart` (new).
- `lib/features/mafia/models/mafia_models.dart` — `MafiaLimits`.
- `lib/app/pubget_app.dart` — catalog provider, `type` route parameter.
- `firestore.rules`, `functions/test/firestore.rules.test.js`.
- Tests: `test/game_screens_test.dart`, `test/game_providers_test.dart`, `test/game_engine_test.dart`,
  `test/product_engines_screens_test.dart`.

## J. Verification matrix (as run in this workspace)

| Command | Result |
|---------|--------|
| `flutter analyze --no-pub lib` | No issues found |
| `flutter analyze --no-pub test` | No issues found |
| `dart format --line-length 80` on changed Dart files | Clean (v2 files reverted, not in scope) |
| `flutter test test/game_engine_test.dart test/game_screens_test.dart test/game_providers_test.dart test/product_engines_screens_test.dart` | 40 passing |
| `flutter test` (full suite) | 629 passing, 0 failing |
| `functions/npm run check` | Passed |
| `functions/npm test` | 305/305 passed |
| `npm run test:rules` (repo root) | NOT VERIFIED — see §B/§K |
| `flutter build apk --debug` | NOT VERIFIED — see §B |

## K. NOT VERIFIED — rules suite cannot boot on this machine

`npm run test:rules` expects the Firestore/Storage emulator and does not start it. Starting it
fails immediately:

```
Error: firebase-tools no longer supports Java version before 21.
Please install a JDK at version 21 or above to get a compatible runtime.
```

Only Temurin 17 is installed. The 53 Firestore + 13 Storage rules cases therefore never execute.
This phase adds one rules clause and five new assertions for it in
`functions/test/firestore.rules.test.js` ("game history is readable only by the players who played
it"). The clause is deliberately narrow — participant-only read, no write — and the existing
assertion that a client cannot write `game_history` still holds, but a reviewer with JDK 21 must run
`npm run test:rules` before merge. The repo-root `npm test` is unusable for the same reason
(`node_modules/` is absent at the root), so the Functions suite was run from `functions/`.

## L. Full Flutter suite

The full suite completed inside a background run rather than the foreground command cap:
629 passing, 0 failing. Two failures surfaced during development and were fixed rather than
waived:

1. `game_engine_test.dart` asserted Mafia's client configuration was 4 players. The registry now
   carries the real 7–15 contract, so the expectation was wrong, not the code.
2. `game_screens_test.dart` asserted the empty copy on the default tab. The default tab is now
   Available Games, which by spec is never empty, so the assertion moved to the Live tab and a new
   test covers the four-game and Rules sections.

## M. Not done, risks, hand-off

1. **Rules emulator run** (§K) is the one outstanding gate for this phase.
2. **Debug APK build** was not re-run for the final client state; the analyze + widget-test signal
   is green but a build catches asset/plugin issues that neither does.
3. **`game_history` has no composite index** and deliberately has no `orderBy`. If a future phase
   needs paginated history beyond a single `limit` page, that index plus the query must ship
   together.
4. **Catalog search is per keystroke-debounce, not paginated.** The server caps a response at 25
   items; there is no infinite scroll, so a broad query shows a bounded result set.
5. **The v2 Games client files remain unreachable and unmaintained.** They were reverted from every
   formatter and analysis pass in this phase. They should be deleted or wired up in a later phase,
   not left as a second, divergent implementation.
6. **Mafia disconnect coverage** is unit-tested for the resolver but has no end-to-end emulator case
   in this phase.
