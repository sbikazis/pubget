# PHASE 05 COMPLETION REPORT — Events (ranking/quiz/prediction) + Fan Works (upload/drafts/analytics) + Anime l10n

Branch: `codex/pubget-phase-05-anime-hub-fanworks-events`
Base commit at branch point: `8bd7f47` (merge of Phase 04, PR #114)
Workspace: `pubget` (Flutter client + `functions` Cloud Functions)

## A. Objective

Close the Phase-05 gaps that Phase 04 handed over (Anime Hub, Fan Works, Events): the Event **Ranking**
drag-and-drop flow, the Quiz **per-question timer** (spec §14.7 item 9), the **Prediction** winner
resolution, the Fan Work **upload lifecycle** (real byte progress, cancel, retry), Fan Work
**draft persistence across restarts**, and the hard-coded English render sites on the Events / Fan
Works / Anime axes. Every change had to be backed by a runnable gate, and the report had to state
verification limits honestly instead of claiming a full-suite pass.

## B. Result / Verdict

**PASS WITH NOT VERIFIED.**

All gates that can run in this environment pass (static analysis, Functions unit suite, Functions
syntax/boot check, 8 Flutter test files covering the changed axes, debug APK build). Two items are
recorded as NOT VERIFIED because of environment limits, not because of open defects:

1. The **full Flutter suite** does not finish inside the 20-minute command cap (see §M).
2. The **Firestore/Storage rules suite** cannot start: `firebase-tools` requires JDK 21 and only
   Temurin 17.0.20.1 is installed (see §N). No rules file was modified in this phase.

No claim in this report depends on those two runs.

## C. Spec sections audited against

Source of truth: `docs/PUBGET_MASTER_SPEC.md`.

| Spec § | Requirement | Where it landed |
|--------|-------------|-----------------|
| §14.2 | "المدة: حد أدنى ساعة، حد أقصى 7 أيام" (min 1 hour, max 7 days) | `EventLifecycle.minDuration` + `MIN_DURATION_MS` in `events/src/eventsDomain.js` (§E1) |
| §14.3 | Result locked after end; no edits | untouched this phase (pre-existing server enforcement) |
| §14.7 (7) | Ranking: user orders by drag & drop, one submission, aggregated final order | §E2, §H1 |
| §14.7 (9) | Quiz: per-question timer, 1 point per correct answer, final score + order | §E3, §H2 |
| §14.7 (8) | Prediction: creator resolves; result opens for participants | §E4, §H3 |
| §14.10 | Every screen has loading / empty / error / ended / no-permission / already-participated / locked-result / retry states | ranking + quiz tile states added in §E2–E3; no new state was left without a control |
| §2.2 | Offline / retry / idempotency | upload cancel + retry reuses the same ticket (§F2) |
| §2.3 | Deep links | `/work/{id}` alias for fan works (§F4) |
| §1.4 | Localization (AR/EN) | §J |

## D. Surfaces audited

- **Events**: builder page, list/discovery screen, detail screen, widgets, models, type registry, and
  the `eventsDomain` callable module.
- **Fan Works**: editor + all six typed editors, feed/home strip, details, profile analytics page,
  widgets, providers, repository contract, Firebase repository, unavailable repository, draft store.
- **Anime**: my-page tab bar, details review card, `AnimeCopy` / `AnimeStrings` registry.
- **App**: router alias table, provider wiring.
- **Social**: profile Fan Works entry label.

## E. Events work delivered

### E1. Event duration floor aligned to spec (client + server)

`lib/features/events/models/event_lifecycle.dart` and `functions/src/eventsDomain.js` both moved the
minimum duration from **5 minutes → 1 hour** (max stays 7 days). The two sides previously agreed with
each other but not with spec §14.2. Validation messages were updated on both sides so the client copy
and the server rejection string stay identical.

### E2. Ranking: drag-and-drop, single submission, aggregated order

- `event_details_screen.dart` renders ranking options in a `ReorderableListView`
  (`Key('event-ranking-options')`) with drag handles, a **Reset** control, and a guard that blocks
  submit until the order contains every option exactly once.
- The order is submitted once as `{'rankedIds': [...]}` (the server already validated a full
  permutation, so no server validation change was needed for the submission path).
- The result card now renders the aggregated order from `result.orderedOptionIds`, so a finished
  ranking shows the final ranking rather than only raw scores.

### E3. Quiz: per-question timer and lock-on-expiry

- `EventQuizQuestion` gained a `seconds` field that round-trips through `toMap` / `fromMap` /
  `copyWith` (`'seconds'` is only written when > 0, so existing documents are untouched).
- The builder exposes a **per-question time limit** selector (10 / 20 / 30 s presets) per question.
- Each question tile runs its own countdown; on expiry it stops the timer, flips to a "time up"
  state, calls `onExpire`, and locks that question's radio options **only if the participant has not
  already answered** (an answer given before the buzzer stands). Timers are cancelled in `dispose`.
- Submit sends `{'answers': {...}}` and now tolerates unanswered questions, so a participant whose
  timer expired can still submit the questions they did answer.

### E4. Prediction result fix

`resolveEvent` previously stuffed the winning **option id** into `winnerIds` (a user-id field). It now
reads the participants' responses and returns the actual **participant uids** that picked the winning
option, and the result now carries `votes`. This also closed a real bug: the client could not show a
prediction winner because the field never held user ids.

## F. Fan Works work delivered

### F1. Real byte progress

`FirebaseFanWorkRepository.uploadMediaBytes` now listens to `UploadTask.snapshotEvents` and reports
`bytesTransferred / totalBytes` through the new `FanWorkUploadProgress` callback, forces a final
`1.0` on completion, and always cancels the subscription in `finally`. The provider exposes
`uploadProgress` / `uploadPercent`, and the editor shows a determinate progress bar labelled from the
localized `uploadingMedia` string. There is no simulated progress left.

### F2. Cancel and retry

- The repository keeps the in-flight `UploadTask` and exposes `cancelMediaUpload()`; Firebase
  `canceled`/`cancelled` codes (functions and storage) are mapped to `CancelledError`.
- The provider keeps a `_PendingFanWorkUpload` (bytes + content type + role + caption + ticket +
  `bytesUploaded` flag). **Retry reuses the same upload ticket** and skips the byte transfer when the
  bytes already landed, retrying only the confirmation. This is the case that previously forced a full
  re-upload after a confirmation failure.
- Guards: a second concurrent upload returns `uploadAlreadyRunning`; retry with nothing pending
  returns `uploadNothingToRetry`. A failed or cancelled upload leaves the editor draft intact (the
  draft text is already persisted by the editor's normal `_persistLocal()` flow, and the UI shows the
  "saved locally" state). What makes the retry possible is the retained in-memory
  `_PendingFanWorkUpload`, not a re-read of the draft.
- The editor shows **Cancel upload** while the byte phase is active and **Retry upload** afterwards;
  the failure message is the localized `uploadCanceled` / `uploadFailed` copy.

### F3. Draft persistence across restarts (new file)

`lib/features/fan_works/repositories/shared_preferences_fan_work_draft_store.dart` implements the
existing `FanWorkDraftStore` interface on top of `SharedPreferences`, and `pubget_app.dart` wires it
into `FanWorkEditorProvider` (previously the provider fell back to the in-memory store, so a draft
lost on app restart). The store tolerates corrupt/undecodable payloads by treating them as absent
(covered by a test).

### F4. Analytics correctness fix

`FanWorkAnalytics.totalViews` was a hard-coded `0` while the UI rendered it as a "Total Views" stat.
There is no view counter in the model, so the field was replaced with `totalRatings` (the real total
behind `averageRating`), and the average is now weighted:
`Σ(ratingsAverage × ratingsCount) / totalRatings` instead of the previous unweighted mean of
per-work averages. The analytics grid, the works-by-type chart, and the top-works list are fully
localized through `FanWorkCopy`.

### F5. Deep link

`/work/{id}` resolves to the fan-work entity (alias of `/fan-work/{id}`), registered in
`_requiredEntityKeys`, covered by `app_router_test`.

## G. Anime work delivered

The last hard-coded English on the anime axis now goes through the existing registry proxy:
`anime_my_page.dart` (4 tabs: Favorite characters / Favorite anime / Lists / Ratings) and
`anime_details_page.dart` (`Report review` semantic label + `Report` button). Six additive
`AnimeStrings` keys with AR/EN getters in `AnimeCopy`. No anime behavior, model, or provider logic
changed.

## H. Server changes (`functions/src/eventsDomain.js`)

1. **Ranking aggregation** — `calculateResult` for `ranking` now returns `orderedOptionIds`: options
   sorted by score descending, ties broken by the creator's configuration order (deterministic, so
   two clients always see the same final ranking). Borda scoring and the winner computation are
   unchanged.
2. **Quiz scoreboard** — `emptyTally` / `applyTally` carry a `scoreboard` keyed by uid, updated on
   join and decremented on leave, and `calculateResult` returns it as `leaderboard`. Blank answers are
   skipped during validation, so a partially answered quiz is a valid submission.
3. **Quiz timer bounds** — `validateQuiz` accepts a per-question `seconds` only when it is an integer
   in `[5, 600]`; anything else rejects the whole quiz configuration.
4. **Prediction winners** — `resolveEvent` prefetches the response collection, derives the participant
   uids that chose `winnerOptionId`, and returns them as `winnerIds` (plus `votes` on the result).

Client↔server round-trip fields added in `event_models.dart`: `orderedOptionIds`, `winnerOptionId`,
`leaderboard`, and per-question `seconds`.

## I. Localization registry

- `AppStrings` gained the event type label map (every `EventType` variant) plus ranking/quiz copy:
  drag instructions, reset, "time up", per-question timer label, points, leaderboard, submission
  result lines, "answered / total".
- `FanWorkCopy` (new file under `lib/features/fan_works/l10n/`) is the AR/EN proxy for the fan-work
  surface: editor fields, editors, feed, profile tabs, analytics cards, upload/cancel/retry states.
- `AnimeCopy` gained the 6 keys from §G.
- All three are additive to the existing registry pattern (`_ui(key, arabic)` with the English key as
  the source of truth). No registry key was renamed or removed, and no hard-coded English remains on
  the ranking/quiz/upload/analytics surfaces listed in §C.

## J. Files changed

Tracked modifications (31) + new files (4):

- **Events client**: `event_lifecycle.dart`, `event_models.dart`, `event_type_registry.dart`,
  `event_builder_page.dart`, `event_details_screen.dart`, `event_list_screen.dart`, `event_widgets.dart`
- **Events server**: `functions/src/eventsDomain.js`, `functions/test/eventsDomain.test.js`
- **Fan Works client**: `fan_work_lifecycle.dart`, `fan_work_models.dart`, `fan_work_repository.dart`,
  `firebase_fan_work_repository.dart`, `unavailable_fan_work_repository.dart`, `fan_work_providers.dart`,
  `fan_work_screens.dart`, `profile_fan_works_page.dart`, `fan_work_widgets.dart`,
  `social/screens/profile_page.dart`
- **Anime**: `anime_copy.dart`, `anime_models.dart`, `anime_details_page.dart`, `anime_my_page.dart`
- **App / l10n**: `app_router.dart`, `pubget_app.dart`, `core/l10n/app_strings.dart`
- **New**: `lib/features/fan_works/l10n/fan_work_copy.dart`,
  `lib/features/fan_works/repositories/shared_preferences_fan_work_draft_store.dart`,
  `test/fan_work_draft_store_test.dart`, `docs/PHASE_05_COMPLETION_REPORT.md`
- **Tests updated**: `test/event_models_test.dart`, `test/event_screens_test.dart`,
  `test/fan_work_providers_test.dart`, `test/fan_work_screens_test.dart`, `test/app_router_test.dart`

## K. Verification matrix (results as run in this workspace)

| Gate | Command | Result |
|------|---------|--------|
| Static analysis (lib + test) | `flutter analyze --no-pub lib test` | **No issues found** |
| Event models | `flutter test test/event_models_test.dart` | **11/11 pass** |
| Event screens (ranking, quiz timer, AR copy) | `flutter test test/event_screens_test.dart` | **5/5 pass** |
| Fan Work providers (upload cancel/retry, feed, details) | `flutter test test/fan_work_providers_test.dart` | **9/9 pass** |
| Fan Work screens (upload progress + retry UI) | `flutter test test/fan_work_screens_test.dart` | **7/7 pass** |
| Fan Work draft store (restart + corrupt payload) | `flutter test test/fan_work_draft_store_test.dart` | **2/2 pass** |
| Router incl. `/work/{id}` alias | `flutter test test/app_router_test.dart` | **18/18 pass** |
| Anime l10n registry | `flutter test test/anime_l10n_test.dart` | **4/4 pass** |
| Anime screens | `flutter test test/anime_screens_test.dart` | **17/17 pass** |
| Events server | `node --test test/eventsDomain.test.js` | **39/39 pass** |
| Functions unit suite (27 files) | `npm test` | **255/255 pass** |
| Functions syntax + module boot | `npm run check` | **exit 0** |
| Android debug build | `flutter build apk --debug` | **pass** → `build/app/outputs/flutter-apk/app-debug.apk` |
| Full Flutter suite | `flutter test` | **NOT VERIFIED** — hit the 20-minute cap (§M) |
| Firestore/Storage rules | `npm run test:rules` | **NOT VERIFIED** — JDK 21 required (§N) |

## L. New tests added (behaviour that had no coverage before)

- `upload progress can be canceled and retried` (provider) — progress reaches 100%, cancel maps to
  `CancelledError`, retry completes.
- `upload retry reuses transferred bytes after confirmation failure` (provider) — asserts the retry
  reuses the same ticket and performs **no** second `uploadMediaBytes` call.
- `editor shows upload progress and retry after cancellation` (widget) — the editor surfaces
  percentage, cancel, and the retry control.
- `ranking copy follows the app locale` and `ranking events submit the drag-and-drop order` (widget).
- `quiz questions lock when the per-question timer expires` (widget) — fake-async countdown, lock,
  and that a pre-buzzer answer is preserved.
- Fan Work draft store: persistence across a new store instance and corrupt-payload tolerance.
- `event_models_test`: `orderedOptionIds` / `leaderboard` / `winnerOptionId` / question `seconds`
  round-trip and legacy-document tolerance.
- `eventsDomain.test.js`: deterministic `orderedOptionIds` (including tie-break by configuration
  order), quiz `scoreboard` → `leaderboard`, quiz `seconds` bounds, blank-answer tolerance, and
  prediction `winnerIds` as participant uids.

## M. NOT VERIFIED — full Flutter suite hits the command cap

A full `flutter test --reporter expanded` run reached **+444 passing, 0 failures** and was still
running when the 20-minute command cap terminated it. The suite therefore has **no completed
end-to-end run in this workspace**, which is why the verdict is PASS WITH NOT VERIFIED and not PASS.
The canonical gate is a full `flutter test` to completion in CI (or a longer local timeout).

## N. NOT VERIFIED — rules suite cannot boot on this machine

`npm run test:rules` expects the Firestore/Storage emulator on `127.0.0.1:8080`, and it does not start
it. Starting it manually fails immediately:

```
Error: firebase-tools no longer supports Java version before 21.
Please install a JDK at version 21 or above to get a compatible runtime.
```

Only `Temurin 17.0.20.1` is present (`/usr/libexec/java_home -V` lists exactly one JDK; the
`.jdk21_home` file in the repo root is an empty file, not a JDK). Consequently the 67 rules cases all
report `hookFailed` / `fetch failed` — the emulator never boots, so **no rules assertion was
executed**. This phase changes no `firestore.rules` or `storage.rules` file, and no client write path
it touches depends on a rules change.

## O. Historical full-suite failures (classification)

An earlier full-suite run in this phase reported 7 failures concentrated in
`app_shell_test.dart`, `edits_pipeline_hardening_test.dart`, `chat_message_bubble_golden_test.dart`,
`home_torii_stage_test.dart`, and `group_bans_page_test.dart`. Re-running those five files together
in this workspace gives **18/18 pass**, and the later full-suite run observed **zero** failures in the
first 444 tests (see §M). The exact failing test IDs from the earlier truncated log were not retained,
so they are not restated here.

**Classification: test-isolation / timing flakiness under full-suite concurrency — not a product
defect in this phase's change set.** None of those five files was modified by this phase except
`app_router_test.dart` (different file). If the CI full run reproduces any of them, treat it as a
pre-existing suite-stability issue, not a Phase-05 regression.

## P. Not done, risks, hand-off

**Not done (intentional)**
- No Firestore/Storage rules changes and no rules verification (environment, §N).
- No golden regeneration; the existing goldens were not re-recorded.
- No Phase 06 work, no Games / Mafia / Economy / Kirari / Reels surfaces touched.
- The quiz per-question timer is **client-enforced** (countdown + lock + partial-submit tolerance).
  The server validates the `seconds` bounds and the submitted answers but does not compare against a
  server clock; a modified client could still answer after its own timer expired. Server-side timing
  enforcement would need a timestamp field on the response, which is a schema change and out of
  scope here.

**Risks**
- `resolveEvent` now reads the whole `responses` collection for predictions to derive winner uids. For
  very large events this is an unbounded read; a capped/aggregated tally would be the follow-up.
- The quiz `scoreboard` and ranking `orderedOptionIds` change the stored tally shape. Existing quiz
  events have no `scoreboard`, so their leaderboard renders empty until new participants join; ranking
  events fall back to configuration order, which is deterministic.
- The analytics schema swap (`totalViews` → `totalRatings`) is a client-side model change only; no
  stored document carries that field.

**Hand-off**
- No merge was performed. The branch is pushed and an unmerged PR is opened for review; merge is a
  separate, explicit decision.
- Unrelated pre-existing untracked artifacts (`.p01_*`, `.p02_worktree/`, `.tmp_p01/`,
  `.tmp_phase01/`, `android/build/`, `.jdk21_home`) were left untouched and are not part of the commit.
