# PUBGET — PROJECT STATE (LOG / KNOWN ISSUES / FOLLOW-UP)

Living document for the current branch state, unblocked issues, and follow-up items. Append, do not rewrite history blithely.

## Branch: cursor/chat-phase-b (Games Rebirth close, 2026-09-14)

### Phased change summary (`d28b44a..HEAD`)

**Prompt 1 — Decoupled Games domain** is implemented and verified. Merge `95eec93` reverted game engines to the legacy contract; this patch restores the e3273cd engine byte-exact and merges the rebirth domain into `gamesDomain.js`.

- **Engines restored** (`functions/src/gameEngines/guessCharacter.js`, `animeChain.js`, `emojiAnimeGuess.js`): byte-identical via `git cat-file blob e3273cd:<path>` + verified `git hash-object`. Player/turn model: guessCharacter uses `players`/`playerOrder`/`answeredPlayerIds`; animeChain validates `payload.targetId` against `state.selections[opponent]`; emojiAnimeGuess uses `currentPlayerId` as turn owner.
- **Domain rewritten** (`functions/src/gamesDomain.js`): uppercase `STATUSES` (`CREATED`/`WAITING`/`STARTING`/`IN_PROGRESS`/`COMPLETED`/`CANCELLED`), 3-game registry (mafia excluded), `normalizeConfiguration` server-authoritative, two-phase `startGame` (`WAITING`→`STARTING`→`IN_PROGRESS`), `submitGameAction` with replay-before-terminal + resign, `processExpiredGames` 50-limit batch, HEAD-style outcome-specific rewards (`earn_game_win_{difficulty}`, `earn_game_draw`, `earn_game_loss`), `creationSource:"group_chat"` enforced, 15-min waiting room (`waitingDeadlineAt`), `requestRef` idempotency. `pauseGame`/`resumeGame`/`endGame` throw (no screens).
- **Function tests** (`functions/test/gamesDomain.test.js`, `gameEngines.test.js`): replaced with patched e3273cd suites (`creationSource:"group_chat"` added to all `createGame` calls).
- **ChatCardWriter registry test** (`functions/test/chatCardWriter.test.js` lines 111–115): flipped mafia assertion to `GAME_TYPE_REGISTRY.mafia === undefined` (rebirth contract).
- **Emulator E2E** (`functions/test/productEngines.e2e.test.js`): updated game blocks to rebirth engine protocol (selection→ask→guess flow for guessCharacter; round-1 correct-guess path for emojiAnimeGuess).

**Targeted test results**

| Suite | Result |
|-------|--------|
| `functions/test/gamesDomain.test.js` + `gameEngines.test.js` + `chatCardWriter.test.js` + rebirth contract files | 28/28 pass |
| `functions/test/guessCharacterRebirth.test.js` + `animeChainRebirth.test.js` + `emojiAnimeGuessRebirth.test.js` | 6/6 pass |
| `npm test` full function suite | 217/217 pass |
| Dart game tests (`game_engine_test.dart` + `games_schema_v2_test.dart` + `game_providers_test.dart` + `game_screens_test.dart` + `features/games/games_v2_screens_test.dart`) | 33/33 pass |
| `flutter analyze lib/features/games` | 0 errors, 7 pre-existing info-level deprecation warnings |

**NOT deployed** — run `firebase deploy --only functions` manually.

## Known Issues

### K1 — Pre-existing full-suite failures (NOT phase-B regressions; fail identically on base `95eec93`)

Verified empirically: the exact same 5 test files were run in a temp git worktree at base `95eec93` and reproduce the same 8 failures byte-for-byte at HEAD.

| # | Test file | Failure | Root cause shape |
|---|-----------|---------|------------------|
| 1 | `test/app_shell_test.dart` "Drawer items route to existing destinations" | `ensureVisible(drawer-settings)` → `Bad state: No element` | Shell drawer no longer exposes a `drawer-settings` key/destination that the test taps; stale test fixture. |
| 2 | `test/chat_message_bubble_golden_test.dart` "golden whatsapp bubbles" | `Pixel test failed, 3.85%, 12658px diff` against `test/goldens/chat_message_bubble_whatsapp.png` | Golden is stale relative to current bubble rendering (or environment-dependent fonts). Bubble widget itself unchanged by phase B. Regenerate after reviewing the isolated diff, ideally under the CI golden baseline. |
| 3 | `test/edits_pipeline_hardening_test.dart` "mapEditException never surfaces raw Storage unauthorized text" | Expected `contains 'securely'`, actual copy is `…blocked by storage security…` | Copy drift between the test and `mapEditException` in `lib/features/edits/repositories/firebase_edits_repository.dart`. |
| 4 | `test/edits_pipeline_hardening_test.dart` "Arabic EditCopy hides technical auth failures" | Expected `contains 'تعذر'`, actual `تم حظر الرفع بواسطة أمان التخزين…` | Same copy drift (Arabic branch of the edits copy). |
| 5 | `test/group_bans_page_test.dart` "authorized user can unban a banned member" | `Bad state: No element` in `WidgetController.tap` (banned-users row finder) | Bans page fixture/empty-state mismatch (page predates MIKADO rework). |
| 6 | `test/group_bans_page_test.dart` "unauthorized user cannot unban" | `Found 0 widgets with text "You cannot manage bans"` | Copy no longer matches the visible bans-page copy. |
| 7 | `test/group_details_rebuild_test.dart` "founder details show identity, type, and open chat" | `group-hero-badges` key not found | Group details hero rebuilt pre-phase-B; test expects removed key. |
| 8 | `test/group_details_rebuild_test.dart` "control panel follows live rank permissions" | `group-quick-stats` key not found | Same key lifecycle drift. |

Each is in a feature area outside the chat scope (shell, edits, group bans/details) or a stale golden. Recommend a dedicated follow-up sweep.

## Follow-up

- [ ] `firebase deploy --only functions` (groupChat callables) — manual deploy required, cannot run from this session.
- [ ] `flutter build apk --debug` — was interrupted during phase-B close; rebuild and smoke-test on device.
- [ ] K1 sweep: fix or refresh the 8 pre-existing failures above (separate branch/PR recommended).
- [ ] Manual chat testing checklist (see PR/report): recent/favorite sticker strip, voice slide-to-cancel + lock, composer send freeze while offline, failed-media reuse on retry, private-chat retry no double-send, long-press overlay reaction gating, truthful security banner locale.

## PROMPT 2 — Mafia Rebirth (branch `cursor/mafia-rebirth-prompt-2`, 2026-09-14)

Rebuilds Mafia as the exact spec-conformant server-authoritative domain. PR #97.

- **State machine** (`phaseFlow.js`, `mafiaDomain.js`, `phaseScheduler.js`, `actionDomain.js`, `roleAssigner.js`, `winConditionChecker.js`, `lobbyManager.js`, `leaveTransition.js`, `disconnectHandler.js`): exact uppercase string set `WAITING → STARTING → ROLE_REVEAL → NIGHT → DAY → DISCUSSION → VOTING → VOTE_RESULT → RESOLUTION` + `GAME_OVER`/`CANCELLED`. Removed legacy lowercase aliases and the `revote`/`finished`/`execution` states. Revote now stays inside `VOTING` (`voteRound` 1→2, `revoteCandidates` = tied players, 30s timer); terminal states are only `GAME_OVER`/`CANCELLED`.
- **Timers**: server-owned `serverStartedAt`/`serverEndsAt` on every transition (Mafia), `phaseEndsAt` kept as compatibility alias; countdown renders `serverEndsAt ?? phaseEndsAt ?? countdownEndsAt`.
- **Roles**: registry and `ROLE_LABELS` reduced to exactly Mafia/Don/Doctor/Detective/Citizen (Good Boy/Sniper/Silencer removed); `computeRoleDistribution` 4 = mafia+doctor+detective+citizen, ≥5 adds Don. Doctor no-same-target-two-nights enforced; Don private Detective probe wired; vote idle revote resolution.
- **Anti-cheat rules** (`firestore.rules`): uppercase `WAITING`/`STARTING` markers on `mafiaGameCreate`/join/leave counters/players, group marker `gameStatus == 'WAITING'`, `serverStartedAt`/`serverEndsAt` fields added to the create allow-list. Client writes to `night_actions`, `votes`, `chat`, `mafia_messages`, `action_receipts` remain denied (callables only). `productEngines.e2e.test.js` + `firestore.rules.test.js` mafia sections updated to assert the anti-cheat contract (emulator-only, not run locally).
- **Client**: `mafia_models.dart` (MafiaPhase enum dropped `revote`/`finished`; `MafiaGame` adds `serverStartedAt`, `serverEndsAt`, `voteRound`, `revoteCandidates`; `isFinished` = `GAME_OVER`/`CANCELLED`), `mafia_leave_copy.dart` uppercase status list, `mafia_game_screen.dart` phase labels/actions/countdown.
- **Bugfix on main**: `functions/src/mafia/historyWriter.js` on `origin/main` was a corrupted merge (two `writeHistory` bodies + unmatched brace → SyntaxError). Restored the clean single-transaction idempotent writer.
- **Docs**: `PRODUCT_ENGINES.md` (4–8, 5 roles, uppercase machine, revote rules, rewards), `CURRENT_STATE_MASTER.md` §11 + security table + callable list + unit-file list. No deploy performed — user runs `firebase deploy --only functions` manually, then `flutter build apk --debug` + on-device test.

## PROMPT 3 — Events Rebirth (branch `cursor/events-rebirth-prompt-3`, 2026-09-14)

Rebuilds Events as the exact spec-conformant social/community domain on top of the (already ~80% spec-compliant) engine. **Not deployed** — run `firebase deploy --only functions` manually.

- **Server (`eventsDomain.js`)**: exact 12-type set (poll, comparison, theory, challenge, ranking, question, prediction, quiz, imageComparison, characterComparison, animeComparison, openDiscussion); `group`/`multiGroup`/`global` scopes; canonical `DRAFT`/`ACTIVE`/`ENDED`/`ARCHIVED`/`DELETED` (legacy lowercase preserved for old callers); 2/day race-safe creation limit; 7-day max duration. Ended notifications now type **`event_result_available`** (pushWorthy true, title "Results are ready"). Added **`resolveEvent`** (prediction/challenge creator locks the result → ENDED, `resultLockedAt`, immutable; validates `winnerIds` against stored responses via transaction; then result chat card + ended notification + `earn_event` rewards). Exported `previewEvent`, `resolveEvent`, `getEventAnalytics`, `addEventComment`, `reactToEvent` in `index.js`.
- **Notifications (`notificationBuilder.js`)**: `event_starting` / `event_result_available` in `PUSH_TYPES`.
- **Rules + indexes**: scope-aware visibility helpers (`eventVisibleOrGlobal` = creator OR public-status AND scope member incl. any multiGroup id); `comments`/`reactions` readable under the same visibility; `responses` readable for author or ENDED/ARCHIVED; new composite indexes for `scope+status+participantsCount+endAt` / `startAt` / `endAt` / `searchName`.
- **Server tests**: `eventsDomain.test.js` now 35 tests (ended notification type + resolveEvent happy path + rejects invalid winners/non-creators); full `npm test` 216/216 pass. `firestore.rules.test.js` updated (emulator-only, source-consistent).
- **Client**: `EventRepository` + `FirebaseEventRepository` + `UnavailableEventRepository` extended with `preview/resolve/getAnalytics/addComment/react/watchComments` and cursor pagination on active/recent (`after`); `EventProvider` wires comments watch + resolve/analytics/comment/reaction actions; `EventListProvider.loadMoreActive()` = infinite-scroll discovery; `EventDetailsScreen` adds like, comments, creator resolve dialog (prediction picker / challenge response picker), analytics sheet, action-manager buttons; `home_event_card.dart` Home strip shows exactly 3; Profile owner quick action "My Events"; test fakes in 5 test files updated + 3 new provider tests. `flutter analyze` clean (info-only); 35 event/social Dart tests pass.
- **Docs**: `CURRENT_STATE_MASTER.md` §12 Events, §23.3 callables, notification table; `PUBGET_PROJECT_STATE.md` this entry.
- **Known limitations (follow-up)**: quiz per-question timer UI not implemented (server has no `timePerQuestionMs` enforcement; details screen shows overall countdown); event-level "report" has no server callable (only reaction/comments); `firestore.rules.test.js` scope-visibility test not executed locally (emulator required).

## Older entries (pre-phase-B)

None retained in this log at the time of creation. Start appending from here.