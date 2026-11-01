# Comprehensive Pubget Audit Validation

**Document type:** Evidence-based validation of a prior forensic audit against the current repository
**Status:** Complete (audit-only; no code, test, rule, or configuration changes were made)
**Validation date:** 2026-09-28
**Validated branch:** `feature/09-chat-media-actions-ux` @ `653fcf125762600af540d4511a94de29faec565c`
**Prior audit artifact:** `docs/COMPREHENSIVE_PUBGET_FORENSIC_AUDIT.md` (authored against `dabb149`)

---

## 1. Executive Summary

The prior forensic audit reached seven findings. All seven were re-tested against the current tree. Two of its three Priority 1 findings do not survive validation. Its central instinct is correct; its stated mechanisms for two of those findings are not.

| Prior finding | Verdict |
| --- | --- |
| 3.1 Mock roleplay content treated as real data | **ALREADY FIXED** |
| 3.2 Functions entrypoint re-declares `mafiaDomain` | **FALSE POSITIVE** |
| 3.3 Home contains user-visible placeholder sections | **PARTIALLY TRUE** (evidence accurate, impact misclassified) |
| 3.4 Search only partially aligned with the required search model | **CONFIRMED** (understated) |
| 3.5 "Looks complete but is not fully production-safe" pattern | **PARTIALLY TRUE** (conclusion correct, cited evidence wrong) |
| 3.6 Architecture outpaces product readiness | **CONFIRMED** (latent risk, now quantified) |
| 3.7 Rules not validated end-to-end | **CONFIRMED** (materially understated) |

This validation independently identified **14 new findings**, three of them P1 and none of them detected by the prior audit. The three P1 findings are more consequential than anything the prior audit reported:

- **V-02 — Global search permanently discards Characters and Reels.** `lib/features/search/search_provider.dart:126-132` rebuilds the results object without the `characters` and `reels` fields, discarding data for which `lib/features/search/search_hit.dart:108-138` contains complete, correct, now **unreachable** rendering code. Two of the seven entities mandated by `docs/PUBGET_MASTER_SPEC.md:562` can never appear in search.
- **V-01 — Six top-level Firestore list queries are structurally incompatible with their own security rules.** Rules for `events`, `fanWorks`, `privateChats`, `respects`, `friendships`, and `game_history` depend on `resource.data` or on `get()`/`exists()` through an unbound wildcard. Firestore cannot evaluate either for `list`. This disables five product domains. The repository's own comments on `groups` and `public_profiles` document this exact failure mode and correctly work around it — proving the pattern is known to the codebase and was missed elsewhere.
- **V-03 — Zero Firestore transactions or batched writes in 95,641 lines of Dart.** `runTransaction` and `WriteBatch` both count 0 across all of `lib/`, against a product with a currency ledger, real-time Mafia phase transitions, matchmaking state, and read-modify-write counters.

Also material: **V-04 — the repository has no CI quality gate.** None of its five GitHub Actions workflows runs `flutter analyze` or `flutter test`, and four deploy on push. This is the mechanism by which the above reached a merged Phase 06, and it is the cheapest finding here to fix.

No product readiness score is assigned, consistent with the audit-only mandate and with the eleven explicitly unverified items in §32.1.

---

## 2. Scope, Method, and Verification Environment

### 2.1 Classification scheme

Every claim in this document carries exactly one classification:

| Classification | Meaning |
| --- | --- |
| `CONFIRMED` | Reproduced by direct code or artifact evidence in the current tree |
| `ALREADY FIXED` | True at the audited baseline, no longer true at HEAD |
| `FALSE POSITIVE` | Cited evidence does not support the conclusion, at baseline or at HEAD |
| `PARTIALLY TRUE` | Core observation holds; stated evidence or impact is inaccurate |
| `POTENTIAL RISK` | Defensive gap or latent hazard; no reproduced failure |
| `UNVERIFIED` | Cannot be established with available tooling or access |
| `MISCLASSIFIED` | Real observation filed under an incorrect severity or category |

### 2.2 What was executed

| Check | Command | Result |
| --- | --- | --- |
| Static analysis | `flutter analyze --no-fatal-infos` | **PASS** — `No issues found!` (117.9 s) |
| Dart tests | `flutter test --reporter=compact` | Partial run, 0 failures — see §2.4 |
| Functions syntax | `node --check functions/index.js` | **PASS** |
| Functions static check | `npm run check` (in `functions/`) | **PASS** |
| Functions module load | direct `require` of `functions/index.js` | **PASS** — `MODULE_LOAD_OK`, 161 exports, all functions, no duplicate or undefined exports |
| Functions test suite | `npm test` (in `functions/`) | **PASS** — 328/328, 0 failures, 5456 ms |
| Firestore rules tests | `firebase emulators:start --only firestore,storage --project demo-pubget-security` | **BLOCKED** — see §2.3 |
| Index coverage audit | `firestore.indexes.json` vs. all client queries | **PASS** (static) — 46 indexes; no missing composite required by an active query |

### 2.3 Blocked verification — the single verification blocker

**The Firestore emulator could not be started.** `firebase-tools` refuses to run on the installed JDK:

```
Error: firebase-tools no longer supports Java version before 21.
Please install a JDK at version 21 or above to get a compatible runtime.
```

Only Java 17 is present. Invoking the emulator JAR directly fails identically:

```
java.lang.UnsupportedClassVersionError: Unsupported class file major version 65.0
(this runtime only supports up to 61.0)
```

No JDK was installed, because the audit mandate prohibits environment mutation.

Consequence: **all Firestore and Storage rule behavior is `UNVERIFIED` at runtime.** The rule findings in §22 and §24 are static-analysis conclusions derived from documented Firestore semantics and from internal corroborating evidence (§22.3), and they are labelled as such. They are **not** emulator-verified, and no claim of rules runtime verification appears anywhere in this document.

### 2.4 Dart test suite — partial run, reported as such

The Dart suite is large (126 test files, ~684 test declarations) and widget-pump heavy. It was executed to a bounded budget and was still progressing when stopped, at **145 passing tests across 23 of 126 test files, with zero failures and zero error markers**. It had not completed, and **no full-suite pass is claimed here.**

Files confirmed green during the run include `roleplay_provider_test.dart` — including its test `a failed catalog source surfaces the error state`, the direct regression guard for the validation of finding 3.1 — and `product_engines_screens_test.dart`. A complete run is required and belongs in CI once V-04 is fixed.

---

## 3. Repository Baseline and Git State

### 3.1 Two divergent checkouts exist

This materially affects how any prior audit claim must be read.

| | Target checkout | Stale checkout |
| --- | --- | --- |
| Path | `/Users/sbikazis/Documents/Default Project/pubget` | `/Users/sbikazis/pubget` |
| Branch | `feature/09-chat-media-actions-ux` | `main` |
| HEAD | `653fcf125762600af540d4511a94de29faec565c` | `dabb149` |
| Contains prior audit file | **No** — absent from tree, all branches, and all history | Yes, **untracked** |
| Phase completion reports | Phase 04, 05, 06 present | None |

The prior audit file **does not exist in the target repository's working tree, any branch, or any commit history.** It exists only as an untracked file in the stale checkout. It was read from there and deliberately **not** copied into the target repository, because this engagement authorizes exactly one file to be written.

`dabb149` is a direct ancestor of current HEAD; in the target checkout's remote-tracking state, `dabb149..origin/main` spans 31 commits. No Phase 02 through Phase 06 commit is an ancestor of `dabb149`.

**Consequence:** the prior audit describes a codebase roughly two and a half months of development behind the code under validation. Its findings must be re-tested, not inherited.

### 3.2 Current branch position

| Measurement | Value |
| --- | --- |
| `git rev-list --left-right --count main...HEAD` | `0 36` |
| `git rev-list --left-right --count origin/main...HEAD` | `0 10` |
| Phase 05 commit `6fae2cd` ancestor of HEAD | Yes |
| Phase 05 PR #115 | Merged (`b1c7072`) |
| Phase 06 merge | `86f5a18`, PR #119, merged |
| `git status --porcelain` (pre-existing) | `?? .p02_worktree/` |

`.p02_worktree/` is a pre-existing untracked directory that predates this engagement. It was not read, modified, staged, or removed. The local `main` branch being 36 commits behind is recorded as repository hygiene (§30), not as a defect.

### 3.3 Actual phase status — correction to the engagement premise

The engagement premise anticipated a repository at or before Phase 05 completion. **That is not the case.** Phase 05 is merged, and **Phase 06 is also merged** (PR #119, `86f5a18`). The repository additionally sits on a Phase 09 feature branch.

Accordingly, this document does **not** assess "Phase 06 readiness" in the sense of preparing to begin Phase 06 — Phase 06 is history. What it assesses is whether the merged Phase 05 and Phase 06 work holds up, and what must be remediated before further phase work compounds the current defect set.

---

## 4. Previous Audit Validation Matrix

### 4.1 Finding 3.1 — "Mock roleplay content is being treated as real data"

**Classification: `ALREADY FIXED`**

The cited evidence was accurate at baseline: at `dabb149`, `lib/features/groups/repositories/firebase_group_repositories.dart` and `lib/features/groups/screens/roleplay/roleplay_character_page.dart` did contain a static mock roster. Phase 03 commit `d1639d1` removed `_mockCharacters`.

Current state:

- Occurrences of `mock`/`Mock`/`MOCK` in `lib/`: **0**
- `RoleplayProvider` sources characters from `AnimeRepository.getCharacters(animeId)` for anime-scoped roleplay and `AnimeHubSocialRepository.listPopularCharacters()` for open roleplay, wired at `lib/app/pubget_app.dart:335-339`
- Groups with null or public configuration expose no reservable characters rather than a fabricated roster
- Catalog failure surfaces an error state instead of substituting fake data
- `test/roleplay_provider_test.dart` includes `a failed catalog source surfaces the error state` and passes

The product-integrity concern is fully resolved. There is no fake-data path in roleplay.

### 4.2 Finding 3.2 — "The Firebase Functions entrypoint contains a backend registration risk"

**Classification: `FALSE POSITIVE`**

The finding asserts that `functions/index.js` "re-declares `mafiaDomain`." It does not, and did not.

- `functions/index.js:51` — single import
- `functions/index.js:180` — single `const mafiaDomain = createMafiaDomain(...)`
- Used at three export sites
- At audited baseline `dabb149`, the declaration also appeared exactly once

Verified at HEAD: `node --check` PASS; `npm run check` PASS including module initialization; direct module load `MODULE_LOAD_OK` with 161 exports, every export a function, no duplicate keys, no undefined references; `npm test` 328/328.

The finding's own cited source, `docs/PUBGET_GAP_ANALYSIS_AND_ROADMAP.md:12`, is a stale document that never matched the code. The audit transcribed a roadmap claim into a code defect without opening the code. Its recommendation to treat this as "a blocking operational risk" was unwarranted.

Actual deployed Functions health remains `UNVERIFIED` (§25, §32.1) — a different and much narrower question.

### 4.3 Finding 3.3 — "Discovery/Home still contains placeholder sections"

**Classification: `PARTIALLY TRUE` — evidence accurate, impact misclassified**

The literal evidence checks out. `lib/features/home/providers/home_provider.dart` does declare `HomeSectionKind.editsPlaceholder`, `eventsPlaceholder`, `gamesPlaceholder`, `fanWorksPlaceholder`, `animePlaceholder`, and does maintain a `sectionOrder`/`displayOrder` mechanism containing them. `HomeSectionKind.communityActivity` is additionally unused.

The conclusion does not follow. Nothing in that set is ever rendered:

- `sectionOrder`/`displayOrder` have **no production consumers**; the only references are in provider tests
- `lib/features/home/screens/home_page.dart` builds real sections from dedicated real providers: Edits, Events, Fan Works, Anime, plus group and recommended-person sections
- The placeholder enum values function purely as internal sentinels that suppress loading for sections with no data source

This is **dead code**, not a user-visible placeholder surface, and not a master-spec violation. It should have been filed as a maintainability issue at P3, not a Priority 1 product-integrity issue. See **V-12**.

### 4.4 Finding 3.4 — "Search page is only partially aligned with the required global search model"

**Classification: `CONFIRMED` — and materially understated**

Both halves hold, and the second is considerably worse than reported.

Hardcoded user-facing strings in `lib/features/search/screens/search_page.dart`:

| Line | Literal |
| --- | --- |
| 41 | `Search` |
| 93 | `Search Pubget` |
| 94–95 | Search instructional copy |
| 113 | `Nothing found` |
| 114 | Retry instruction copy |
| 122 | `Search failed.` |

Additionally, `lib/features/search/search_hit.dart` hardcodes every result subtitle, mixing languages inside one results list: `'Group'` (58), `'Person'` and `'Pubget user'` (68), `'Event'` (78), `'Anime'` (90), `'Fan Work'` (102), and Arabic `'شخصية'` (115) and `'ريل'` (131).

The prior audit said the search UX "does not reflect the full entity matrix required by the spec" without identifying the mechanism. The mechanism is a hard data-loss defect: **V-02**, reclassified here from the prior audit's P2 placement to P1.

### 4.5 Finding 3.5 — "Looks complete but is not fully production-safe"

**Classification: `PARTIALLY TRUE` — conclusion correct, cited evidence wrong`

The pattern is real, and this validation found three concrete instances in exactly the surfaces the finding names:

- Search appears complete and fetches six entity types, but discards two (**V-02**)
- Home appears complete, but its featured events area depends on a top-level `events` list query its own rules forbid (**V-01**)
- Games navigation appears complete, but two pushed routes are unregistered (**V-06**)

The finding, however, cites `home_provider.dart` placeholder sections as the cause, and that cause is false (§4.3). The correct cause is different: functional defects hidden behind plausible surfaces, not placeholder content. A remediation plan built on the original citation would target the wrong code.

### 4.6 Finding 3.6 — "Architecture suggests a better base than current product readiness"

**Classification: `CONFIRMED` — latent risk, now quantified`

The structural investment is real: 385 Dart files, 95,641 lines, 18 feature modules, a consistent provider-and-repository architecture, and 50+ provider registrations composed at the application root in `lib/app/pubget_app.dart`.

The latent risk is also real, and this validation supplies the mechanism the prior audit was missing: **there is no automated quality gate** (**V-04**). `flutter analyze` passes cleanly and both test suites pass, yet no workflow runs either. Nothing prevents a merge that introduces a dead route, a discarded field, or a rules/query incompatibility. Well-structured code with no enforcement is precisely the condition under which uneven implementation quality persists, and the merged Phase 06 is consistent with that.

### 4.7 Finding 3.7 — "Rules are important but this audit did not validate every security assertion"

**Classification: `CONFIRMED` — materially understated`

The prior audit's caution was appropriate, but its conclusion was too comfortable, resting on the observation that `firestore.rules` and `storage.rules` are "clearly substantial and more advanced than a scaffold." Substance is not correctness.

This validation performed the static analysis the prior audit declined, and found that several rules are **structurally incompatible with the queries the client actually issues** (**V-01**). The rules are substantial and simultaneously contain a systemic query-compatibility defect across six collections and five product domains. The correct posture statement is: well-intentioned, well-documented rules containing a specific, systemic, fixable defect class — a more actionable and more concerning conclusion than "more advanced than a scaffold."

Runtime confirmation is `UNVERIFIED` (§2.3). The static conclusion does not depend on it: Firestore's documented `list` semantics do not permit `resource.data` or a wildcard-`get()` check to succeed.

---

## 5. Documentation Authority, Phase Status, and Master Spec Traceability

`docs/PUBGET_MASTER_SPEC.md` is treated as final product authority. The prior forensic audit is treated as evidence to be tested, not as truth.

### 5.1 The specification is explicit on the axes this validation measures

| Spec location | Requirement | Current state |
| --- | --- | --- |
| Line 562 | Search universe must cover Anime, Characters, Groups, Reels, Events, Fan Works, across AR/EN/JA with fuzzy matching and filters | **Not met** — Characters and Reels never reach the UI (**V-02**); zero AR/EN/JA strings in the search surface (**V-05**) |
| Line 514 | Reels lifecycle must be an explicit state machine, "no messy booleans" | Partially implemented over `edits`; representation not audited in this pass (§32.1 item 10) |
| Line 673 | Collections include `reels`, `reel_comments`, `reel_interactions` | **Not implemented** — no client, rules, or function reads them (**V-07**) |
| General | No fake data; server is truth | Met in roleplay after Phase 03 (§4.1) |
| General | No placeholder or "coming soon" production surfaces | Met — placeholders are unrendered dead code (**V-12**) |

### 5.2 Documentation drift

`docs/PUBGET_GAP_ANALYSIS_AND_ROADMAP.md:12` asserts a `mafiaDomain` duplicate-declaration defect that has never existed in the code. A stale internal document was the sole evidentiary basis for a Priority 1 finding in the prior audit. Internal documents are not a reliable secondary source here, and no finding in this document rests on one. See **V-14**.

---

## 6. Phase 05 Regression Validation

Phase 05 is merged (PR #115, `b1c7072`; base commit `6fae2cd`) and is an ancestor of HEAD.

Regression review of the merged surface found **no Phase 05-introduced functional regression**. None of the 14 findings in §31 were traced to Phase 05 changes. Three findings do intersect Phase 05 and 06 surfaces:

- **V-01** affects Events and Fan Works, both in the Phase 05/06 surface
- **V-06** sits in the Games V2 surface
- **V-04** is why none of these were caught before merge

`docs/PHASE_05_COMPLETION_REPORT.md` asserts completion. This validation does not dispute the report; it records that its specific claims about rules-backed list access could not be substantiated and are contradicted by **V-01**.

---

## 7. Architecture and Feature Topology

**Verdict: structurally sound, enforcement absent.**

18 feature modules under `lib/features/`: achievements, anime, authentication, economy, edits, events, fan_works, games, groups, home, mafia, notifications, private_chat, reels, search, settings, social.

Positives, confirmed:

- Consistent provider/repository separation throughout
- Providers composed at the app root in `lib/app/pubget_app.dart`, with 50+ `ChangeNotifierProvider` and `ChangeNotifierProxyProvider` registrations
- `Result<T>` / `Success` / `FailureResult` used consistently, with typed `Failure` subtypes
- Session-dependent providers (Social, Group, Game, Mafia, Achievement, Economy) are all `ChangeNotifierProxyProvider`s keyed on `AuthProvider`, correctly preventing stale-auth reads
- A single `AppNavigation` helper centralizes routing intent
- `analyze` is clean with no suppressions required

Structural concerns are catalogued in §30.

---

## 8. Search

**Verdict: `CONFIRMED` defect — the weakest domain in the product.**

Search is the domain the prior audit correctly identified and misdiagnosed.

### 8.1 Data loss — Characters and Reels are always discarded

The highest-confidence finding in this document, because the evidence is a direct internal contradiction across four files.

`lib/features/home/models/home_models.dart` declares seven result fields, including:

```dart
final List<CharacterCommunityStats> characters;   // line 29
final List<Edit> reels;                            // line 39
```

`lib/features/home/repositories/firebase_home_repository.dart:226-329` issues **six** parallel Firestore queries in a single `Future.wait`, including:

```dart
final charactersFuture = _firestore
    .collection('character_stats')
    .where('searchName', isGreaterThanOrEqualTo: normalized)
    .where('searchName', isLessThanOrEqualTo: end)
    .limit(20)
    .get();                                        // lines 261-266
```

and correctly populates both fields on the returned `DiscoverySearchResults` (lines 312-323).

`lib/features/search/search_hit.dart` contains complete, correct rendering code for both:

```dart
for (final character in results.characters) { ... }   // lines 108-122
for (final edit in results.reels) { ... }             // lines 123-138
```

Both loops are **unreachable**, because `lib/features/search/search_provider.dart:126-132` rebuilds the results object without them:

```dart
_results = DiscoverySearchResults(
  groups: results.groups,
  people: results.people,
  events: results.events,
  anime: anime,
  fanWorks: results.fanWorks,
);
// characters and reels are never passed through
```

Net effect, on every debounced search:

- Two Firestore queries execute and their results are discarded
- `SearchHitType.character` and `SearchHitType.reel` hits are never produced
- Two of the seven entities mandated at `docs/PUBGET_MASTER_SPEC.md:562` are permanently absent
- The correct rendering code sits in the tree looking tested and working

A test asserting "search returned hits" passes while never exercising the missing mapping. This is the mechanism behind §29.2.

### 8.2 What search does correctly

Genuine strengths, verified:

- 280 ms debounce with generation-counter race protection (`search_provider.dart:104,116`)
- In-flight duplicate suppression via `_inflight` (line 103)
- Disposal guard checked before state mutation (line 116) and before `notifyListeners` (line 164)
- `Timer` cancelled in `dispose()` (line 170)
- Query length normalized to 2–80 characters
- Anime search sourced from the real provider chain with a ranking pass
- Network failure degrades to `LoadingState.offline`, distinct from `error` (line 154)
- All six repository queries wrapped in one `try`/`on Object catch` returning a typed failure (repository lines 231, 326)

### 8.3 Residual robustness gap

`search_provider.dart:111-115` awaits `_homeRepository.search`, then awaits `_animeRepository.searchAnime` outside any `try`. If the latter threw rather than returning a `FailureResult`, `_search` would propagate out of the `Timer` callback through `unawaited`, leaving `_state` at `LoadingState.loading` and `_inflight` set — a permanently stuck search requiring an app restart.

**Not reproducible today.** The entire repository chain defends against it: `JikanAnimeRepository._page` catches `on Object` (line 364), `ProviderChainAnimeRepository._run` catches `on Object` (line 155), and `CachedAnimeRepository` wraps its inner future. Classified `POTENTIAL RISK` at P3 (**V-08**), not a confirmed defect.

### 8.4 Localization

The worst-localized surface in the product — see §28.

---

## 9. Home and Discovery

**Verdict: no user-visible placeholders; real query-exposure defect.**

- No placeholder content is rendered. The prior audit's P1 finding does not hold (§4.3, **V-12**)
- Real providers back each section: Edits, Events, Fan Works, Anime, groups, recommended people
- **V-01 applies here:** the featured events area depends on a top-level `events` list query that the rules forbid
- `HomeSectionKind.communityActivity` and the placeholder sentinels are dead code

---

## 10. Groups, Roleplay, and Membership

**Verdict: healthy; prior finding resolved.**

The mock roster is fully removed and replaced with server-backed catalogs (§4.1). Reservation semantics are honest: groups without a configured roster expose no reservable characters rather than fabricating one. Catalog failure surfaces an error state, guarded by a passing regression test. No defect found.

---

## 11. Group Chat and Private Messaging

**Verdict: `CONFIRMED` defect — the private chat list is functionally broken.**

- `FirebasePrivateChatRepository.watchChats` issues a top-level `privateChats` query
- The `privateChats` rules gate reads through a `get()`/`exists()` chain on an unbound wildcard
- Firestore cannot evaluate that for `list`, so the query is denied — **V-01**
- `firestore.indexes.json` provisions exactly the right index (`participantIds ARRAY_CONTAINS | lastMessageAt DESCENDING | __name__ DESCENDING`), indicating the query was designed correctly and the **rules** are what block it
- Reporting is implemented and is not missing: `reportGroupMessage` (`functions/index.js:456`) and `reportPrivateMessage` (`:484`)

This is the clearest illustration of the V-01 diagnosis: a correct query, a correct index, and a correct test, defeated only by the rule.

---

## 12. Media: Edits and Reels

**Verdict: `CONFIRMED` schema drift.**

Reels are implemented as a projection of the `edits` collection. Evidence:

- `lib/features/reels/` issues **no** Firestore collection query at all
- `DiscoverySearchResults.reels` is typed `List<Edit>` (`home_models.dart:39`)
- Search populates the reels slot from `collection('edits')` (repository lines 267-273, 318-323)
- `firestore.rules` contains **no** `match /reels` block
- No Cloud Function references a `reels` collection

Yet the spec and provisioned infrastructure assume a separate collection:

- `docs/PUBGET_MASTER_SPEC.md:673` lists `reels · reel_comments · reel_interactions`
- `firestore.indexes.json` provisions **three** composite indexes on `reels`

**Finding V-07 (P2).** Three provisioned indexes serve a collection no client, rule, or function reads. The de facto design — reels-as-edits — is coherent and may be the better one, but the spec, the index budget, and a future contributor reading `firestore.indexes.json` all assume an architecture that does not exist. This is exactly the drift that produces phantom dependencies in a later phase.

This is a *different* defect from **V-02**. Even after V-02 is fixed so reels reach the UI, V-07 remains: the data model still contradicts the spec.

---

## 13. Fan Works

**Verdict: `CONFIRMED` defect — feed and search both blocked by rules.**

- `FirebaseFanWorkRepository` issues a top-level `fanWorks` list query; the `fanWorks` rules derive visibility from `resource.data`, unavailable for `list` — **V-01**
- Search's `fanWorks` branch is subject to the identical failure (repository lines 253-260)
- The composite index is correctly provisioned (`status | moderationStatus | publishedAt | __name__`), again indicating the query was right and the rules are wrong
- Reporting is implemented: `reportFanWork` (`functions/index.js:676`)
- Three fanWorks composite indexes cover creator, character-tag, and status variants — no missing index

---

## 14. Events

**Verdict: `CONFIRMED` defect — widest blast radius of V-01.**

Five affected top-level query paths, all against a rules block that gates visibility through a wildcard `get()`:

| Query location | Purpose |
| --- | --- |
| `FirebaseEventRepository` — active | Current events feed |
| `FirebaseEventRepository` — upcoming | Upcoming events feed |
| `FirebaseEventRepository` — recent | Recently ended events |
| `FirebaseEventRepository` — group | Group-scoped event lists |
| `FirebaseHomeRepository.search` lines 246-252 | Global search |

The `events` collection has **ten** provisioned composite indexes, and the repository filters on `status`, `scope`, `groupId`, `creatorId`, `animeIds`, and `searchName`. This is a heavily engineered feature surface, and the rules incompatibility disables a large fraction of it. See **V-01**.

---

## 15. Anime Catalog and External Data Providers

**Verdict: strongest domain; error handling is exemplary.**

- Real multi-provider chain: Jikan → AniList → Firestore cache, with fallback
- Every layer converts exceptions to typed failures rather than rethrowing (`_get` line 415, `_page` line 364, `_object` line 381, `_run` line 155)
- `Result<T>` discipline consistent; no raw `dynamic` escape hatches in the mapping path
- `fromCache` is surfaced so cached content is distinguishable from fresh
- Anime search integrates into global search correctly, including a ranking pass with `keepUnmatched`
- This is the domain the rest of the codebase should follow, and it is the direct reason V-08 is only a potential risk

No defect found.

---

## 16. Social Graph

**Verdict: `CONFIRMED` defect — the entire social snapshot is blocked.**

`FirebaseSocialRepository.getSnapshot` (`firebase_social_repository.dart:21-54`) issues three top-level queries inside one `Future.wait`:

```dart
_firestore.collection('respects').where('fromUserId', isEqualTo: userId).get(),
_firestore.collection('respects').where('toUserId',  isEqualTo: userId).get(),
_firestore.collection('friendships').where('userIds', arrayContains: userId).get(),
```

The `respects` and `friendships` rules derive access from `resource.data`. All three are denied for `list` — **V-01**.

Amplifying factor: the three queries share one `Future.wait` under one `try`, so a single denial fails the **whole** snapshot. The `on Object catch` at line 51 converts it to a clean typed failure, so there is no crash — but respects given, respects received, and friendships all become unavailable together, with no partial degradation. The user sees an empty state that is indistinguishable from "you have no social data yet."

Index coverage is correct: single-field equality queries need no composite. **This is a rules defect, not an index defect** — the fix is in `firestore.rules` and requires no reindexing.

---

## 17. Games

**Verdict: `CONFIRMED` defect — dead navigation plus a blocked history query.**

- **V-06 (P2):** `lib/features/games/screens/games_center_v2_screen.dart:149-150` pushes named routes `/games/waiting` and `/games/room`. `lib/app/app_router.dart:463-464` parses both as valid deep links with required entity keys, but **neither is registered** in `lib/app/pubget_app.dart`. A user tapping the active-game tile navigates to a route with no builder.
- **V-01:** `firebase_games_repository_v2.dart:138-141` queries `game_history` by `groupId` + `orderBy('endedAt', desc)`. The index is correctly provisioned (`groupId | endedAt DESC | __name__ DESC`); the `game_history` rules block the list.
- `firebase_game_repository.dart:242-243` (`participants arrayContains`) needs only an automatic single-field index — no index gap, but subject to the same rules denial
- Hardcoded Arabic labels in the same screen, including the archive section (§28)

---

## 18. Mafia

**Verdict: no duplicate-registration defect; real-time state risk inherited from V-03.**

The prior audit's P1 backend claim is a false positive (§4.2). What is genuinely notable is the structural risk created by the absence of transactions (**V-03**): Mafia manages phase transitions, role assignment, wagers, and award settlement, all multi-document state changes. With no `runTransaction` and no `WriteBatch` anywhere in `lib/`, any partial failure leaves a game inconsistent.

The existing test `mafia lobby hides a start button that would fail` passes and is good practice; it does not cover mid-phase consistency.

---

## 19. Economy and Wallet

**Verdict: highest-risk domain for V-03; also the least verifiable.**

- A currency ledger with `economyTransactions` correctly indexed (`userId ASCENDING | createdAt DESCENDING | __name__ DESCENDING`), and a `wallets` collection per spec line 673
- **V-03 (P1) applies with full force.** A balance change is inherently multi-step: read balance, decrement, credit recipient, append ledger entry. Without a transaction, a client retry or network failure between steps produces a lost update, a double credit, or a ledger entry that does not match balances. Idempotency and reconciliation are not verifiable from source alone.
- Client-side balance authority is a trust-boundary question this validation could not settle statically, and which depends on the `wallets` rules block plus Functions mutation paths — both `UNVERIFIED` (§32.1 items 6 and 7)

---

## 20. Achievements, Notifications, Authentication, and Settings

**Verdict: no defects identified; verified less deeply than the flagged domains.**

Grouped and honestly labelled rather than presented as clean.

- **Achievements:** unlock logic exercised by `product_engines_screens_test.dart`, including a locked/unlocked rendering test that passes
- **Notifications:** no functional, query, or rules defects found
- **Authentication and Onboarding:** the prior audit's assessment that session infrastructure is concrete holds. `AuthProvider` and `AuthDraftStore` are registered at the app root; `OnboardingProvider` and `ProfileProvider` are `ChangeNotifierProxyProvider`s keyed on `AuthProvider` — correct wiring preventing stale-auth reads
- **Settings:** no defects found

All four received less scrutiny than Events, Social, or Search. See §32.1 item 11.

---

## 21. Navigation and Routing Integrity

**Verdict: `CONFIRMED` defect.**

- `/search` is correctly registered (`pubget_app.dart:933`) and reachable
- Deep-link parsing in `app_router.dart` recognizes `/games/waiting` and `/games/room` with required entity keys (lines 463-464), but no route builders exist — **V-06**
- Because the parser accepts these paths, an inbound deep link is treated as valid and then has nowhere to land — a worse failure mode than the parser rejecting it outright
- Centralized `AppNavigation` / `PubgetLinks` helpers are a genuine strength: route construction is consistent and greppable

---

## 22. Firestore Security Rules

**Verdict: `CONFIRMED` P1 defect; runtime `UNVERIFIED`.**

`firestore.rules` contains 101 match blocks. Substantial and clearly not a scaffold — that much of the prior audit's read is fair. The static analysis the prior audit declined, however, finds a systemic query-compatibility defect.

### 22.1 The defect class

A Firestore `list` operation evaluates rules **per candidate document**, but `resource.data` is available only for `get`/`update`/`delete` — for `list`, `resource` is `null`. Separately, a `get()`/`exists()` on a path that is not the resource path leaves the wildcard variable **unbound**, which makes the rule evaluate to error and deny the request.

Rules depending on either construct cannot authorize a top-level list query, regardless of the querying user's permissions.

### 22.2 Affected collections

| Collection | Rule dependency | Client top-level list queries |
| --- | --- | --- |
| `events` | `get`/`exists` wildcard in `eventVisibleToUser` | 5 (§14) |
| `fanWorks` | `resource.data` visibility | 2 (feed, search) |
| `privateChats` | `get`/`exists` wildcard in `chatParticipant` | 1 (§11) |
| `respects` | `resource.data` | 2 (§16) |
| `friendships` | `resource.data` | 1 (§16) |
| `game_history` | `resource.data.participants` | 2 (§17) |

### 22.3 The decisive corroboration

The repository's own comments on `groups` and `public_profiles` state that reads using `get()` poison list queries, and the rules for those two collections **correctly split `allow get` from `allow list`**, with a dedicated list rule that does not touch `resource.data`.

The author understood the failure mode, solved it for two collections, and did not apply it to six others. This is not speculation about Firestore semantics; it is a documented, already-solved problem in the same file, inconsistently applied. It also explains why the affected areas survive code review: each query is individually reasonable, and each has a correct index.

### 22.4 Test gap

`functions/test/firestore.rules.test.js` contains 53 tests. They cover individual `get` operations for events, fan works, and private chats — **but no `list` test for any of the six affected collections.** Every one of these rules passes its test suite while being unable to authorize the query its own client issues.

### 22.5 Verification status

`UNVERIFIED` at runtime — emulator blocked by JDK version (§2.3). The static conclusion stands on documented Firestore semantics plus §22.3. No deployed-rules parity claim is made.

---

## 23. Firestore Indexes and Schema Drift

**Verdict: index coverage is correct; schema drift confirmed.**

46 composite indexes are provisioned. Every multi-field client query was checked against them:

| Query | Required composite | Provisioned |
| --- | --- | --- |
| `groups` search (`isSearchable` + `searchName` range) | Yes | Yes |
| `events` search (`status whereIn` + `searchName` range) | Yes | Yes |
| `fanWorks` search (`status` + `moderationStatus` + `searchTitle` range) | Yes | Yes |
| `edits` search (`status` + `searchName` range) | Yes | Yes |
| `character_stats` search (single-field range) | Automatic | N/A |
| `public_profiles` search (single-field range) | Automatic | N/A |
| `game_history` by group (`groupId` + `endedAt` desc) | Yes | Yes |
| `privateChats` watch | Yes | Yes |
| `respects` / `friendships` (single-field equality) | Automatic | N/A |

**No missing composite index was found in any active client query.** Index engineering here is thorough and correct, and this deserves credit.

**But the indexes are right and the rules still block the queries.** Three index variants are provisioned for Events and three for Fan Works, and both collections are non-functional under current rules. The `reels` indexes are orphaned entirely (**V-07**).

---

## 24. Storage Rules and Media Security

**Verdict: `UNVERIFIED`.**

`storage.rules` exists and was inspected structurally. No `CONFIRMED` defect is reported, and none is ruled out.

Media security is a high-value target for a product with user-uploaded video, avatars, event imagery, and stickers, and this received the least verification of any security area — the same emulator blocker as §22 applies. It is listed in §32.1 rather than presented as satisfactory.

---

## 25. Cloud Functions

**Verdict: healthy; prior P1 finding refuted.**

- 161 exports, all functions, no duplicates, no undefined references
- `node --check`, `npm run check`, module load, and 328/328 tests all pass
- `mafiaDomain` declared exactly once, at both HEAD and the audited baseline
- Domain modules follow a consistent `createXDomain()` factory pattern
- Reporting callables implemented for group messages, private messages, fan works, and anime reviews
- The deploy workflow uses `npm ci`, a `require.resolve` smoke check, and retry-on-failure — reasonable practice

Deployed health is `UNVERIFIED` (§32.1 item 3).

---

## 26. State Management, Async Lifecycle, and Data Integrity

**Verdict: `CONFIRMED` P1 defect — no transactional integrity anywhere.**

### 26.1 Async and lifecycle discipline: genuinely good

This is where the codebase is strongest, and the prior audit's structural optimism is justified here:

- 28 files carry explicit `_disposed` guards
- 34 `StreamSubscription` sites and 25 `Timer` sites are managed
- 164 explicit `unawaited(` call sites — async fire-and-forget is deliberate and visible rather than accidental
- `SearchProvider` demonstrates the full pattern correctly: debounce, generation counter, in-flight suppression, disposal check before mutation, `_safeNotify` wrapper, timer cancellation in `dispose`
- `AnimeHubProvider.load` guards re-entry on both `_loading` and terminal state (lines 83-84)
- 26 `.snapshots()` stream sites, consistent with app-scoped providers

No leak or use-after-dispose defect was found in this pass.

### 26.2 Data integrity: the critical gap

Counted across all 385 Dart files / 95,641 lines in `lib/`:

| Operation | Count |
| --- | --- |
| `runTransaction` | **0** |
| `WriteBatch` / `.batch()` | **0** |
| `.set(` | 3 |
| `.update(` | 15 |

**There is not a single atomic multi-document write in the product.** The entire `set`/`update` surface is 18 calls.

For a real-time product with a currency ledger, Mafia phase transitions and wagers, matchmaking state, publish counters, and social edges, multi-document invariants are not an edge case — they are the domain. Concrete exposure:

- **Economy:** a balance mutation is read-modify-write. Two concurrent purchases, or one purchase retried after a timeout, can double-spend or lose a credit. Without a ledger-matching transaction, the ledger cannot be reconciled against balances.
- **Mafia:** advancing a phase while awarding wagers and updating player records can partially apply.
- **Publish flows:** a Fan Work or Edit marked published while its counters and denormalized search fields are written separately can become visible with stale metadata.
- **Counters:** `viewsCount`, `likesCount`, `commentsCount`, `participantsCount` are read-modify-write by nature.

A transaction-free design is legitimate when writes are idempotent single-document updates. That is not the case here. This is the most consequential architectural finding here, rated P1.

Scope caveat: full assessment also depends on whether Cloud Functions perform the authoritative mutations — Functions are capable of transactions and could be enforcing invariants server-side. That was **not** established by this validation (§32.1 item 6).

### 26.3 Query hygiene

86 top-level `.get()` call sites. Pagination is correctly applied in pagination-aware repositories (`firebase_games_repository_v2.dart:141-151` uses a document-ID cursor). Some list reads are unbounded — a cost and scalability concern rather than a correctness defect (§27).

---

## 27. Performance

**Verdict: reasonable, with two concrete issues.**

Positives: TTL caching with in-flight deduplication in `CachedAnimeRepository`; request priority tiers; debounced search; cursor pagination where lists grow; `fromCache` surfaced for honest UI state.

- **V-09 (P2):** search fires 6 parallel Firestore reads on every debounced query, 2 of which are discarded outright (**V-02**). Fixing V-02 without also eliminating the wasted reads leaves the cost in place. One fix, two findings.
- Unbounded list reads (86 sites) will degrade as collections grow; no production dataset was available, so impact is `UNVERIFIED` (§32.1 item 8)
- No image-sizing or caching strategy was validated in this pass

---

## 28. Localization, RTL, Theming, and Accessibility

**Verdict: `CONFIRMED` defect — a spec-level product failure, plus an accessibility gap.**

The master spec describes an Arabic-first, trilingual (AR/EN/JA) product. Localization is systematically bypassed in exactly the high-traffic surfaces.

### 28.1 Search — the worst offender

`search_page.dart`: six hardcoded user-facing strings (lines 41, 93, 94, 95, 113, 114, 122), including the page title, empty state, failure state, and retry instruction.

`search_hit.dart`: **every** result subtitle is hardcoded, and the language is inconsistent within a single results list:

| Line | Subtitle | Language |
| --- | --- | --- |
| 58 | `Group` | English |
| 68 | `Person` / `Pubget user` | English |
| 78 | `Event` | English |
| 90 | `Anime` | English |
| 102 | `Fan Work` | English |
| 115 | `شخصية` | **Arabic** |
| 131 | `ريل` | **Arabic** |

An English-locale user sees Arabic subtitles for Characters and Reels; an Arabic-locale user sees English for everything else. There is no JA path at all, against a spec that mandates it.

### 28.2 Other surfaces

Hardcoded Arabic literals also appear in group bans and members management, the member council view, the composer's attachment/emoji/camera affordances, chat special cards, and sticker details. `games_center_v2_screen.dart` contains hardcoded Arabic including the archive section.

Partial remediation is worse than none: fixing Search alone leaves the language mix visible to any user who navigates between Search and these surfaces.

### 28.3 RTL

Mixed-direction and hardcoded-direction padding in Search and Games screens is a likely RTL defect, but this was not verified by rendering and is recorded as `UNVERIFIED` (§32.1 item 5). No claim of RTL correctness is made.

### 28.4 Theming

No theming defect confirmed. `lib/core/theme/` was inspected structurally; no finding is filed. Light/dark parity was not verified by rendering.

### 28.5 Accessibility

- 24 `Semantics(` usages across 95,641 lines is sparse for a consumer social product
- 26 `Image` usages lack a `semanticLabel`
- `MergeSemantics`: 0; `excludeSemantics`: 0

Icon-only controls — search clear, composer attachments, camera, emoji, game tiles — are the likely gaps, clustering on the same surfaces already failing localization. A screen-reader user navigating Search would encounter unlabeled icon buttons and unreadable hardcoded strings. Adequate as a first remediation target, not as a final state. See **V-10**.

---

## 29. Test Suite Quality

**Verdict: strong and real, with a structural coverage blind spot that explains the defect set.**

### 29.1 What genuinely passes

| Suite | Result |
| --- | --- |
| `flutter analyze --no-fatal-infos` | PASS — `No issues found!` |
| `npm test` (Functions) | **328/328**, 0 failures, 5456 ms |
| `flutter test` | Bounded run stopped at 145 passing tests, 0 failures, 23 of 126 files — **not a full pass** (§2.4) |

The Functions suite in particular is substantial and green, and the prior audit's positive assessment of test evidence is fair.

### 29.2 The blind spot

The suites pass while the product contains a permanently-broken search universe, six rules-blocked list queries, and two unregistered routes. The blind spot is structural, not accidental:

- **Provider and widget tests use fakes.** A fake `HomeRepository` returns a fully populated `DiscoverySearchResults`, so a `SearchProvider` test sees `characters` and `reels` present — while the real repository's results are silently dropped at the provider boundary (**V-02**). The defect lives precisely in the seam between real and fake, which no test covers.
- **No rules list tests** for the six affected collections (§22.4), so rules that cannot authorize their own client queries pass.
- **No route-coverage test** enumerating parsed paths against registered builders, so **V-06** passes.
- **No test asserts entity coverage** of the search universe against `docs/PUBGET_MASTER_SPEC.md:562`, so two permanently missing entity types pass.

### 29.3 Absence of a CI gate

**V-04 (P1).** No workflow in `.github/workflows/` runs `flutter analyze` or `flutter test`. Verified by search across all five workflows: no match.

| Workflow | Trigger | Gate? | Action |
| --- | --- | --- | --- |
| `build.yml` | push, `workflow_dispatch` | **None** | `flutter build apk --release --split-per-abi` |
| `deploy-firestore-rules.yml` | push (branch filter) | **None** | `firebase deploy --only firestore:rules,firestore:indexes` |
| `deploy-functions.yml` | push (branch filter) | **None** | `npm ci` + resolve smoke check, then deploy |
| `deploy-hosting.yml` | push to `main` | **None** | `flutter build web --release`, then deploy |
| `deploy-storage-rules.yml` | push (branch filter) | **None** | `firebase deploy --only storage` |

Four of five deploy on push, and `deploy-hosting.yml` ships to `main` with no test or analysis gate. Note that `deploy-firestore-rules.yml` deploys `firestore:indexes` alongside rules, so index and rule changes ship together — fortunate here, since the V-01 fix requires new list-rule logic deployed alongside any query changes.

**This is the highest-leverage finding in the document.** It is why the others are in a merged Phase 06 rather than caught in review, and it costs less to fix than every individual defect combined. `analyze` and both test suites pass today, so the gate would go green immediately.

---

## 30. Dead Code, Legacy, and Repository Hygiene

**Verdict: `CONFIRMED` at P3; no runtime or build impact.**

- **`lib_legacy/`** — present in the repository, imported by nothing in `lib/`, and not declared in `pubspec.yaml`, so it is not in the build path. It invites accidental reuse of pre-Phase code. **V-11**
- **`functions/src/reelsDomain.js`** — exports `createReelsDomain`, imported nowhere. **V-11**
- **Home placeholder sentinels** — `HomeSectionKind.{editsPlaceholder, eventsPlaceholder, gamesPlaceholder, fanWorksPlaceholder, animePlaceholder}` plus unused `communityActivity`; `sectionOrder`/`displayOrder` referenced only in provider tests. Dead code, not a spec violation. **V-12**
- **Local `main` is 36 commits behind the working branch** — invites branch-base errors. **V-14**
- **Stale internal documentation** — `docs/PUBGET_GAP_ANALYSIS_AND_ROADMAP.md:12` asserts a `mafiaDomain` defect that has never existed, and that stale line was the sole basis for a Priority 1 finding in the prior audit. **V-14**

Recommendation for all of the above: remove, or mark explicitly as superseded/deprecated. Confirm intent before deleting `lib_legacy/`.

---

## 31. Consolidated Findings Register

Severity: **P0** production outage or data loss · **P1** core functionality broken, or security/integrity risk · **P2** significant feature or quality gap · **P3** maintainability, polish, or latent risk.

### V-01 — Firestore list queries structurally incompatible with their own rules · P1 · `CONFIRMED`

- **Area:** Firestore Security Rules · Events, Fan Works, Private Chat, Social, Games
- **Evidence:** `firestore.rules` (`events`, `fanWorks`, `privateChats`, `respects`, `friendships`, `game_history`) vs. `firebase_event_repository.dart`, `firebase_fan_work_repository.dart`, `firebase_private_chat_repository.dart`, `firebase_social_repository.dart:21-54`, `firebase_game_repository.dart:242`, `firebase_games_repository_v2.dart:138`
- **Impact:** six collections across five domains cannot be listed at all — Events feeds (active/upcoming/recent/group), the Fan Works feed, the private chat list, the entire social snapshot, and game history. The Social snapshot shares one `Future.wait`, so one denial removes all three. Users see clean empty or error states rather than crashes, which makes this easy to misread as "no data yet."
- **Root cause:** rules use `resource.data` or a wildcard `get()`/`exists()` to derive visibility — neither is evaluable for `list`. The same file already splits `allow get` from `allow list` for `groups` and `public_profiles` and documents why, so the correct fix pattern exists in-repo (§22.3).
- **Recommendation:** add dedicated `allow list` rules for the six collections, deriving visibility from the query's own constraints (`status`, `participantIds`, `userIds`, `groupId`, `moderationStatus`) rather than a document lookup. Mirror the existing `groups` pattern.
- **Verification:** blocked by §2.3. Add `list` tests to `functions/test/firestore.rules.test.js` for all six collections; the 53 existing tests do not cover them.
- **Runtime status:** `UNVERIFIED` (static analysis only)

### V-02 — Global search permanently discards Characters and Reels · P1 · `CONFIRMED`

- **Area:** Search
- **Evidence:** `search_provider.dart:126-132` (fields omitted) vs. `home_models.dart:29,39` (declared), `firebase_home_repository.dart:261-266,312-323` (fetched and returned), `search_hit.dart:108-138` (complete but unreachable rendering code)
- **Impact:** two of the seven entities mandated by `docs/PUBGET_MASTER_SPEC.md:562` never appear in search, for any query, in any locale. Two Firestore queries execute per debounced search and are discarded. Correct rendering code is present in the tree, making the defect invisible to review and to any test asserting "search returned hits."
- **Root cause:** the provider reconstructs the results object field-by-field instead of forwarding the repository's object, silently defaulting omitted fields to empty lists.
- **Recommendation:** forward `characters` and `reels` from `results`. Add a test asserting search hit types include `SearchHitType.character` and `SearchHitType.reel`, plus a repository-level test asserting both fields are populated.
- **Verification:** fully verifiable by unit test; no emulator or network required.

### V-03 — Zero Firestore transactions or batched writes in 95,641 lines · P1 · `CONFIRMED`

- **Area:** Data integrity · Economy, Mafia, Games, Publishing, Social
- **Evidence:** repository-wide counts — `runTransaction` = 0, `WriteBatch`/`.batch()` = 0, `.set(` = 3, `.update(` = 15 across all 385 files in `lib/`
- **Impact:** every multi-document state transition is non-atomic. Currency operations are exposed to double-spend and lost updates; Mafia phase and wager settlement can partially apply; publish flows can expose records with stale denormalized search fields; read-modify-write counters can lose increments.
- **Root cause:** absent by construction, not by regression — the architecture has no transaction layer.
- **Recommendation:** introduce transactions for currency mutation, Mafia phase transitions, and publish-state changes; make counters idempotent (server-side increments or `FieldValue.increment()`). Confirm whether Cloud Functions already perform authoritative mutations before scoping client work (§32.1 item 6).
- **Verification:** requires a Firestore emulator (JDK 21) plus concurrency tests.

### V-04 — No CI quality gate in any workflow · P1 · `CONFIRMED`

- **Area:** CI/CD · all five workflows
- **Evidence:** `.github/workflows/{build,deploy-firestore-rules,deploy-functions,deploy-hosting,deploy-storage-rules}.yml` — no `flutter analyze`, no `flutter test`, no `npm test`
- **Impact:** every other finding here could merge undetected, and four workflows deploy on push with `deploy-hosting.yml` shipping to `main` unverified. Clean local `analyze` and 328/328 Functions tests show the gate is cheap and would pass today.
- **Root cause:** no pull-request verification workflow exists; build and deploy workflows are the only automation.
- **Recommendation:** add a `pull_request` workflow running `flutter analyze --fatal-infos`, `flutter test`, and Functions `npm run check && npm test`; make deploy workflows depend on it. Consider branch protection on `main`.
- **Verification:** fully verifiable in CI.

### V-05 — Hardcoded, language-mixed UI strings in Search · P2 · `CONFIRMED`

- **Area:** Localization
- **Evidence:** `search_page.dart:41,93,94,95,113,114,122`; `search_hit.dart:58,68,78,90,102,115,131`
- **Impact:** global search is not localized. Users see English subtitles in an Arabic UI and Arabic subtitles (`'شخصية'`, `'ريل'`) in an English one. No JA coverage, against a spec mandating AR/EN/JA. The spec's localization requirement fails on the product's most-used discovery surface.
- **Root cause:** strings authored inline rather than routed through the `app_strings.dart` / per-feature `*_copy.dart` pattern the rest of the codebase uses.
- **Recommendation:** migrate all listed strings to the existing pattern; audit Games and the other surfaces in §28.2 in the same pass, since partial remediation leaves the mix visible.
- **Verification:** verifiable by test asserting no bare literals in these files. RTL correctness needs rendering and is `UNVERIFIED`.

### V-06 — Unregistered game routes behind an active tile · P2 · `CONFIRMED`

- **Area:** Navigation
- **Evidence:** `games_center_v2_screen.dart:149-150` pushes `/games/waiting` and `/games/room`; `app_router.dart:463-464` parses both; neither is registered in `pubget_app.dart`
- **Impact:** tapping the active-game tile navigates to a route with no builder, and inbound deep links to those paths are accepted by the parser with nowhere to land.
- **Root cause:** the deep-link parser was extended without a corresponding route registration, and no test enumerates parsed paths against registered builders.
- **Recommendation:** either register the two routes or remove the tile and the parser entries. Add a route-coverage test.
- **Verification:** fully verifiable by a widget test asserting each parsed path resolves to a registered route.

### V-07 — Reels schema drift: spec and indexes assume a collection nothing reads · P2 · `CONFIRMED`

- **Area:** Media / schema
- **Evidence:** `PUBGET_MASTER_SPEC.md:673` lists `reels · reel_comments · reel_interactions`; `firestore.indexes.json` provisions three `reels` indexes; `lib/features/reels/` issues no collection query; `firestore.rules` has no `match /reels`; no function references `reels`; `DiscoverySearchResults.reels` is `List<Edit>` (`home_models.dart:39`)
- **Impact:** three provisioned indexes serve a collection with no client, rules, or function. Reels are in fact edits. A later contributor reading the spec or the index file will reasonably assume a `reels` collection exists and may build against it or author rules for it.
- **Root cause:** reels were implemented as a projection of `edits` without reconciling the spec or removing the provisioned indexes.
- **Recommendation:** decide the intended model, then either provision and implement the collection or update the spec and delete the three orphaned indexes.
- **Verification:** verifiable by static inspection once decided.

### V-08 — Search state machine has no terminal escape on unexpected throw · P3 · `POTENTIAL RISK`

- **Area:** Search / async
- **Evidence:** `search_provider.dart:111-115` — `_animeRepository.searchAnime` awaited outside any `try`, while `_inflight` (line 105) and `_state = loading` (line 106) reset only on the normal path (line 117)
- **Impact if triggered:** `_search` would propagate out of the `Timer` callback via `unawaited`, leaving search permanently stuck in `LoadingState.loading` with `_inflight` set, requiring an app restart.
- **Why not confirmed:** every repository layer converts exceptions to typed failures — `jikan_anime_repository.dart:364`, `provider_chain_anime_repository.dart:155` — so no throwing path was found. This is a defensive gap, not a reproduced failure.
- **Recommendation:** wrap the awaits in `try`/`finally` that clears `_inflight` and sets a failure state.
- **Verification:** trivially testable with a throwing fake repository.

### V-09 — Search issues two queries whose results are discarded · P2 · `CONFIRMED`

- **Area:** Performance
- **Evidence:** `firebase_home_repository.dart:261-273` (two of six queries) vs. `search_provider.dart:126-132` (both dropped)
- **Impact:** two unnecessary Firestore reads per debounced search — `character_stats` and the reels/edits query — costing reads, latency, and index cost on the most-used discovery surface.
- **Root cause:** the same field-by-field reconstruction as V-02, viewed from the cost side. **Resolving V-02 resolves this too — do not treat as separate work.**
- **Verification:** covered by V-02's tests.

### V-10 — Sparse semantics labeling · P3 · `CONFIRMED`

- **Area:** Accessibility
- **Evidence:** 24 `Semantics(` usages; 26 `Image` usages without `semanticLabel`; 0 `MergeSemantics`; 0 `excludeSemantics` across 95,641 lines
- **Impact:** screen-reader users encounter unlabeled icon buttons, concentrated on the same surfaces already failing localization (Search composer, Games).
- **Recommendation:** label icon-only controls, merge composite buttons, add `Semantics` to custom tappable containers. Treat as a first remediation target, not a final state.
- **Verification:** requires manual screen-reader testing; static counts do not establish runtime accessibility.

### V-11 — Unreachable legacy and dead backend module · P3 · `CONFIRMED`

- **Area:** Dead code
- **Evidence:** `lib_legacy/` imported by nothing in `lib/` and not declared in `pubspec.yaml`; `functions/src/reelsDomain.js` exports `createReelsDomain` and is imported nowhere
- **Impact:** maintenance surface and reader confusion; `lib_legacy` in particular invites accidental reuse of pre-Phase code. No runtime or build impact — not in the build path.
- **Recommendation:** remove both, or add an explicit deprecation note. Confirm intent before deleting.
- **Verification:** verifiable statically; no build impact expected.

### V-12 — Home placeholder sentinels and dead section ordering · P3 · `CONFIRMED`

- **Area:** Home / dead code
- **Evidence:** `home_provider.dart` — `HomeSectionKind.{editsPlaceholder, eventsPlaceholder, gamesPlaceholder, fanWorksPlaceholder, animePlaceholder}` and unused `communityActivity`; `sectionOrder`/`displayOrder` referenced only in provider tests; `home_page.dart` renders only real providers
- **Impact:** none user-visible. Corrects prior finding 3.3, which filed this as a Priority 1 product-integrity issue; it is dead code, not a spec violation.
- **Recommendation:** remove the unused enum values and the ordering mechanism, or retain them with a comment explaining the sentinel purpose.
- **Verification:** verifiable by test asserting `sectionOrder` has no production consumer.

### V-13 — Firestore and Storage rule behavior unverified · P2 · `UNVERIFIED`

- **Area:** Security
- **Evidence:** `firebase emulators:start --only firestore,storage --project demo-pubget-security` fails — `firebase-tools` requires JDK 21, only JDK 17 installed; direct emulator JAR fails with `UnsupportedClassVersionError` (class file version 65.0, runtime supports 61.0)
- **Impact:** the entire rules test surface is unexecuted. V-01 is statically established but not runtime-confirmed, and `storage.rules` — the higher-risk file for user-uploaded media — received no behavioral verification at all.
- **Recommendation:** install JDK 21 and run `functions/test/firestore.rules.test.js` against the emulator. This is a prerequisite for closing V-01.
- **Verification:** this finding is itself the blocker for verifying the others.

### V-14 — Stale documentation and a stale local base branch · P3 · `CONFIRMED`

- **Area:** Repository hygiene
- **Evidence:** local `main` is 36 commits behind the working branch; `docs/PUBGET_GAP_ANALYSIS_AND_ROADMAP.md:12` asserts a `mafiaDomain` defect that has never existed in code
- **Impact:** low direct risk, but a stale internal document already produced one false Priority 1 finding, and a stale local `main` invites branch-base errors.
- **Recommendation:** keep the gap-analysis document current or mark it superseded; keep `main` synchronized.
- **Verification:** verifiable by inspection.

---

## 32. Unverified Items and Prioritized Remediation Roadmap

### 32.1 Unverified items

Stated explicitly so no section of this document is read as more complete than it is.

| # | Item | Why unverified | To resolve |
| --- | --- | --- | --- |
| 1 | All Firestore rule runtime behavior | Emulator blocked by JDK 21 requirement (§2.3) | Install JDK 21, run rules tests |
| 2 | All Storage rule behavior | Same | Same |
| 3 | Deployed Cloud Functions health | No deployment access | Deploy-and-probe, or Functions logs |
| 4 | Deployed rules vs. source parity | No Firebase console access | `firebase firestore:rules:get` diff |
| 5 | Visual, RTL, and light/dark verification | No rendering performed | Run the app; screenshot key screens |
| 6 | Whether Functions enforce the V-03 invariants | Not statically established | Audit all Functions write paths for transaction use |
| 7 | Wallet authority boundary (client vs. Functions) | Not statically established | Inspect `wallets` rules and Functions mutations |
| 8 | Production data volumes for §27 scaling | No dataset access | Query collection counts |
| 9 | Full `flutter test` suite result | Bounded run; 145 tests, 23 of 126 files completed, 0 failures | Re-run to completion in CI once V-04 is fixed |
| 10 | Reels lifecycle state machine (spec line 514) | Not audited in this pass | Audit `Edit` lifecycle fields against the spec |
| 11 | Achievements, Notifications, Auth, Settings depth | Lightly verified only (§20) | Deep pass if remediation proceeds |

### 32.2 Remediation roadmap

Sequenced by leverage, not severity alone. **No remediation was performed in this engagement.**

**Phase A — Stop the bleeding (small, high leverage)**

1. **V-04** — add the CI gate. Cheapest change, highest leverage. `analyze` and both test suites pass today, so it goes green immediately and blocks the V-02/V-05/V-06 class of regression from recurring.
2. **V-13** — install JDK 21. Unblocks rules verification and is a prerequisite for closing V-01.

**Phase B — Restore broken core functionality**

3. **V-02** together with **V-09** — forward `characters` and `reels` at `search_provider.dart:126-132`. The smallest high-impact fix here: restores two spec-mandated search entities and eliminates two wasted queries. Add the entity-coverage test that would have caught it.
4. **V-01** — add `allow list` rules for the six affected collections, following the `groups`/`public_profiles` pattern already in `firestore.rules`, and add the six missing list tests. One pattern fix restores Events, Fan Works, Private Chat, Social, and Games history.
5. **V-06** — register or remove the two game routes; add a route-coverage test.

**Phase C — Structural and quality gaps**

6. **V-03** — transaction layer. By far the largest item; scope domain by domain, economy first. Resolve §32.1 item 6 first to avoid duplicating work Functions may already do.
7. **V-05** — Search localization, audited together with the other hardcoded surfaces in §28.2 so the language mix is not left visible.
8. **V-07** — decide the Reels data model, then reconcile spec and indexes.
9. **V-08** — `try`/`finally` in `_search`. Trivial; do it alongside V-02.

**Phase D — Cleanup**

10. **V-10** — accessibility labeling, starting with the surfaces already flagged.
11. **V-11**, **V-12**, **V-14** — dead code, documentation, and repository hygiene.

**Deliberately not recommended:** assigning a product readiness score. The evidence base is strong for the domains audited and explicitly absent for eleven items in §32.1. A numeric score would misrepresent that.

---

## Validation Statement

All seven prior findings were re-tested against the current tree with direct evidence. Two of the prior audit's three Priority 1 findings are refuted; the third is reclassified downward with its evidence preserved. Fourteen new findings are recorded, three at P1, none detected by the prior audit.

The prior audit's most durable contribution was not any individual finding but the observation in 3.5 that the product looks more finished than it is. That observation is confirmed. Its stated mechanism — placeholder content — was wrong, and the actual mechanism is more serious: a data-losing defect in search, a rules defect disabling five domains, and no CI gate to catch either.

No production code, test, rule, localization, or configuration file was modified. No remediation was attempted. The only file created by this engagement is this document. Unverified items are enumerated in §32.1 and are not represented as passing anywhere in this document.

---

## Appendix A — Evidence Index

| Finding | Primary evidence |
| --- | --- |
| V-01 | `firestore.rules`; `firebase_event_repository.dart`; `firebase_fan_work_repository.dart`; `firebase_private_chat_repository.dart`; `firebase_social_repository.dart:21-54`; `firebase_game_repository.dart:242`; `firebase_games_repository_v2.dart:138`; contrasting `groups`/`public_profiles` list rules |
| V-02 | `search_provider.dart:126-132`; `home_models.dart:29,39`; `firebase_home_repository.dart:261-266,312-323`; `search_hit.dart:108-138`; `PUBGET_MASTER_SPEC.md:562` |
| V-03 | Repository-wide counts: `runTransaction` 0, `WriteBatch` 0, `.set(` 3, `.update(` 15 across 385 files |
| V-04 | `.github/workflows/*.yml` — all five inspected; no test or analyze step |
| V-05 | `search_page.dart:41,93-95,113,114,122`; `search_hit.dart:58,68,78,90,102,115,131` |
| V-06 | `games_center_v2_screen.dart:149-150`; `app_router.dart:463-464`; absence in `pubget_app.dart` |
| V-07 | `PUBGET_MASTER_SPEC.md:673`; `firestore.indexes.json` (3 `reels` indexes); `lib/features/reels/`; `firestore.rules`; `home_models.dart:39` |
| V-08 | `search_provider.dart:103-117`; `jikan_anime_repository.dart:364`; `provider_chain_anime_repository.dart:155` |
| V-09 | `firebase_home_repository.dart:261-273`; `search_provider.dart:126-132` |
| V-10 | Repository-wide counts: `Semantics(` 24, unlabeled `Image.` 26, `MergeSemantics` 0 |
| V-11 | `lib_legacy/`; `functions/src/reelsDomain.js` |
| V-12 | `home_provider.dart`; `home_page.dart`; `sectionOrder` reference sites |
| V-13 | `firebase emulators:start` failure output; `UnsupportedClassVersionError` |
| V-14 | `git rev-list --left-right --count main...HEAD` = `0 36`; `PUBGET_GAP_ANALYSIS_AND_ROADMAP.md:12` |
| 3.1 | `d1639d1`; `roleplay_provider_test.dart`; `pubget_app.dart:335-339`; zero `mock` in `lib/` |
| 3.2 | `functions/index.js:51,180`; `node --check`; `npm run check`; module load (161 exports); `npm test` 328/328 |
| 3.3 | `home_provider.dart`; `home_page.dart`; `sectionOrder` production-consumer count = 0 |
| 3.4 | Same as V-05 and V-02 |
| 3.5 | Same as V-02, V-01, V-06 |
| 3.6 | `pubget_app.dart` (50+ provider registrations); V-04 |
| 3.7 | Same as V-01, V-13 |

## Appendix B — Commands Executed

```
git rev-parse --abbrev-ref HEAD
git rev-parse HEAD
git status --porcelain
git rev-list --left-right --count main...HEAD
git rev-list --left-right --count origin/main...HEAD
git merge-base --is-ancestor 6fae2cd HEAD

flutter analyze --no-fatal-infos
flutter test --reporter=compact              # bounded run; see 2.4

node --check functions/index.js
npm run check                 # in functions/
npm test                      # in functions/
node -e "require('./functions/index.js')"   # export/duplicate audit

firebase emulators:start --only firestore,storage --project demo-pubget-security
java -jar firebase-database-emulator.jar    # direct fallback attempt

grep -rniE "flutter (test|analyze)|npm (test|run check)" .github/workflows/
firestore.indexes.json parse and dump via python3
repository-wide counts for mock / runTransaction / WriteBatch / Semantics / .snapshots()
```

Environment: macOS (darwin), Flutter SDK, Node.js, Firebase CLI, Java 17 (JDK 21 unavailable — the sole verification blocker, §2.3).
