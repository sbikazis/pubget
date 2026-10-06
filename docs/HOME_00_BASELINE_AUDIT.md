# HOME-00 — BASELINE + FORENSIC HOME AUDIT

**Phase:** HOME-00 (audit only — no production code modified)
**Authority:** `docs/PUBGET_MASTER_SPEC.md` (Locked). Where it conflicts with any other document or with the task brief, the Master Spec wins.
**Repository:** `pubget/` (workspace root is a container; the Flutter project is the `pubget/` subdirectory)
**Date of audit:** 2026-10-05

---

## 0. GATE RESULTS (exact, factual)

| Check | Command | Result | Status |
|---|---|---|---|
| Git state | `git status --porcelain` | Only `?? .p02_worktree/` (untracked scratch worktree copy) | **PASS** (clean otherwise) |
| Branch | `git branch --show-current` | `feature/anime-hub-restructure-comprehensive` | recorded |
| Last commits | `git log -5 --oneline` | `8e817b1`, `14f112a`, `39a5aae`, `f457f43`, `43b8ef4` (all anime-hub) | recorded |
| Static analysis | `flutter analyze --no-pub` | `No issues found! (ran in 219.7s)` | **PASS** — 0 issues |
| Home + shell tests | `flutter test` on 11 Home/shell/discovery test files | `All tests passed!` — **30/30** | **PASS** |
| Debug APK | `build/app/outputs/flutter-apk/app-debug.apk` exists, mtime **2026-09-28** | Artifact is **STALE** — HEAD is `8e817b1` (2026-10-05) | **NOT VERIFIED** — no fresh `flutter build apk --debug` was run in this audit-only phase |
| Backend deploy state | n/a | Not deployed/verified from this environment | **NOT VERIFIED** |
| Home visual QA screenshots | `screenshots/` contains only `prompt-06-groups.jpg`, `prompt-08-final.jpg`, `pubget-design-system-final.jpg`, `pubget-foundation*.jpg` (all 2026-09-17) | **No current Home screenshots exist** | **NOT VERIFIED** |

**Analyzer note:** the first `flutter analyze` invocation aborted with `analysis server exited with code -15` (SIGTERM). A second clean run completed with 0 issues. The abort was a tooling event, not a code verdict.

**Baseline verdict: the repository builds clean (analyze) and all Home-related tests pass.** The defects recorded below are therefore *design, truthfulness, RTL, localization, performance and dead-code* defects — not compilation blockers. This must not be read as "Home is production-ready".

---

## 1. CURRENT ARCHITECTURE

### 1.1 Layering (compliant with Master Spec §1.1)

```
UI (HomePage, tiles)
  ↓ context.watch<…Provider>
HomeProvider (ChangeNotifier, per-section state)
  ↓
HomeRepository (abstract interface)
  ↓
FirebaseHomeRepository  →  Firestore `groups` / `public_profiles`
                       →  Callable `getDiscoveryFeed` (us-central1)
```

- **UI does not touch Firestore.** Confirmed: `home_page.dart` only reads providers.
- **8 files, ~2,014 lines** total in `lib/features/home/`:
  - `screens/home_page.dart` (694)
  - `widgets/home_luxury_tiles.dart` (372)
  - `repositories/firebase_home_repository.dart` (351)
  - `providers/home_provider.dart` (288)
  - `models/home_models.dart` (166)
  - `repositories/unavailable_home_repository.dart` (55)
  - `repositories/discovery_errors.dart` (46)
  - `repositories/home_repository.dart` (28)
- **No god class.** Home logic is genuinely distributed. This is the strongest part of the current implementation.

### 1.2 Architecture violations / smells

| # | Finding | Location |
|---|---|---|
| A1 | **Home bypasses its own provider for 4 of 8 sections.** Edits, Events, Fan Works and Anime are read from their own domain providers directly in the widget tree, not through `HomeProvider`. This creates two competing discovery sources (§1.2 below). | `home_page.dart:378, 444, 496, 534` |
| A2 | **Duplicated discovery source-of-truth.** The backend `getDiscoveryFeed` already returns ranked `recommendedEdits`, `recommendedFanWorks`, `recommendedEvents`, `recommendedAnime` — but Home only consumes `recommendedGroups` and `recommendedPeople` from it, and takes edits/events/fanWorks/anime from separate providers instead. | `recommendationEngine.js:281-286` vs `home_page.dart` |
| A3 | **Shared singleton providers couple Home to other tabs.** `EditsProvider` and `EventListProvider` are app-level singletons (`pubget_app.dart:419, 455`). Home's `edits.load(limit: 8)` mutates the same instance the Reels viewer and Events page use. Navigating Home → Reels → Home can surface Home-mutated feed state and paging. | `pubget_app.dart:419,455` |
| A4 | Business logic in `build()`: `Future.microtask(() => provider.load())` is called from `build()` in **five** places, plus a sort/diversify pass and `DateTime.now()` filtering. | `home_page.dart:306,343,380,446,498,539,461` |
| A5 | Dead code: `HomeSection` model class is **never referenced anywhere** in `lib/` or `test/`. | `home_models.dart:150-166` |

---

## 2. CURRENT UI STRUCTURE

`home_page.dart:78-107` — a `CustomScrollView` with **hardcoded, fixed** order:

| # | Section | Widget | Notes |
|---|---|---|---|
| 1 | Promoted Groups | `_GroupSection` → `HomeSquareGroupCard` | height 214 rail |
| 2 | Edits | `_EditsSection` → `HomeEditPreviewCard` | height 228 rail |
| 3 | People | `_PeopleSection` → `HomePersonCard` | height 188 rail |
| 4 | Ad slot | `_HomeAdSlot` → `AdPlacementView` | conditional on EconomyProvider |
| 5 | Events | `_EventsSection` → `HomeEventsSection` | max 3 (correct) |
| 6 | Recommended Groups | `_GroupSection` → `HomeSquareGroupCard` | height 214 rail |
| 7 | Rising Groups | `_GroupSection` → `HomeSquareGroupCard` | height 214 rail |
| 8 | Fan Works | `_FanWorksSection` → `HomeFanWorkCard` | height 286 rail |
| 9 | Anime (this season) | `_AnimeSection` → `AnimeHorizontalStrip` | posterWidth 168 |
| — | bottom spacer | `SizedBox(AppSpacing.xl)` | |

**Structural assessment: this is the "Section / Section / Section" pattern the brief explicitly rejects.** Seven of nine sections are `PubgetSectionHeader` + `HomeHorizontalStrip` (a 168–214px horizontal `ListView.separated`). Visual rhythm is essentially flat.

### 2.1 Master Spec §5.2 / §5.3 conformance — FAIL

- **§5.2.1** "Promoted Groups always at top and **fixed**" → **PASS**.
- **§5.2.2** "Videos/edits per user interest (personalized)" → **PARTIAL** — data is `FeedType.forYou`, but the label claims *Trending* (see §13).
- **§5.2.3** "Remaining sections in an order that **smartly rotates between visits**" → **FAIL**. Order is hardcoded. `HomeProvider.displayOrder` (`home_provider.dart:82-98`) implements content-before-empty ordering but **is never called by any production widget** — only by `test/home_provider_display_order_test.dart`.
- **§5.3 section inventory** — Home currently shows **7 of the 13** mandated sections. **Missing entirely:**
  - أنمي الأسبوع (anime of the week)
  - شخصيات شعبية (popular characters)
  - نشاط الأصدقاء (friends activity)
  - صنّاع صاعدون (rising creators)
  - إنجازات/تقدم (achievements/progress)
  - محتوى جديد حسب آخر نشاط (new content by latest activity)
- **§5.3** "each section has its own design (Grid / hero rail / cards) — **not one card with only the title changed**" → **FAIL**. Promoted / Recommended / Rising all render the identical `HomeSquareGroupCard`; only the 3-stop gradient colour differs (`home_luxury_tiles.dart:30-46`).
- **§5.3** "a *See more* button in every section → an independent section page" → **FAIL**. `_SectionFrame` (`home_page.dart:559-578`) passes only `title` to `PubgetSectionHeader`. `PubgetSectionHeader` **does** support `subtitle`, `actionLabel`, `onAction` (`pubget_atmosphere.dart:38-47`) — Home uses none of them. No section has a See-more action except Events' *empty* state.

---

## 3. CURRENT DATA SOURCES

### 3.1 Promoted Groups — **REAL, server-authoritative**
`firebase_home_repository.dart:47-60`
```
groups where isSearchable==true, isPromoted==true,
       promotionExpiresAt > now
orderBy promotionExpiresAt desc, __name__ desc
limit(pageSize=8), startAfter([promotionExpiresAt, id])
```
- Writes come from `groupsDomain.js:1187-1204`. Identical for all users → satisfies §5.2.1. **PASS**
- Rules: `firestore.rules:691` `allow list: if signedIn();` — query is permitted.
- Index present (`firestore.indexes.json:208,212`). **PASS**

### 3.2 Rising Groups — **REAL, server-authoritative (best data story in Home)**
`firebase_home_repository.dart:63-77` reads `risingEligible==true` ordered by `risingScore desc, createdAt desc, __name__ desc`.

Writer chain verified end-to-end:
- `functions/index.js:253` `refreshGroupActivityScores = onSchedule(...)` → `discoveryEngine.updateScores()`
- `discoveryEngine.js:148-176` computes `risingScore` via `calculateRisingScore` and writes `risingScore`, `risingEligible`, `activityMetrics`.
- `discoveryEngine.js:115-121` enforces anti-manipulation: qualifying actors require **account age ≥ 7 days** and **membership ≥ 24 h**.
- `discoveryEngine.js:160-163` eligibility: `membersCount >= 2 && <= 200 && ageDays <= 180 && risingScore > 0`.

This satisfies Master Spec §7.5 (real activity signals, **not** member count; anti-manipulation present). **PASS — do not replace this.** Index present (`firestore.indexes.json:120,124,146`).

### 3.3 Recommended Groups — **MISLABELLED / effectively fake recommendation**
`firebase_home_repository.dart:80-89` → `rankedOrFallback(ranked: callable, fallback: Firestore)`.
- **Ranked path**: callable `getDiscoveryFeed(section: 'recommendedGroups')` — real ranking. **PASS**
- **Fallback path** (`:114-125`): `groups where isSearchable==true orderBy createdAt desc` — i.e. **newest groups by date**, with zero personalisation.
- `rankedOrFallback` (`discovery_errors.dart:34-48`) silently substitutes the fallback when ranking fails **or returns empty**. The user is never told.
- The section is labelled **"مجموعات مقترحة" / "Recommended groups"**.

> **This violates Master Spec §5.4: "ممنوع إظهار سبب توصية زائف" (forbidden to display a false recommendation reason).** When the fallback is in play, Home asserts a personal relevance that does not exist. **Report as conflict; do not silently relabel.**

### 3.4 People discovery — **MISLABELLED / no signal**
`firebase_home_repository.dart:142-202` → `rankedOrFallback`:
- **Ranked path**: callable `recommendedPeople` — real. **PASS**
- **Fallback path** (`:178-202`): `public_profiles` collection with **no `where` clause and no `orderBy`**, `.limit(limit + 8)` = **18 documents**, then client-side index slicing for pagination.
- The same 18 documents are returned to every user regardless of interests; pagination is synthetic (sublist of a fixed 18-item window).
- Labelled **"أشخاص لاكتشافهم" / "People to discover"**.

> Violates §5.4 in the same way, and additionally produces a **fixed arbitrary sample presented as discovery**. §16.9 (real signals) is not met on this path.

### 3.5 Community Activity — **DEAD + has a pagination bug**
`firebase_home_repository.dart:127-139`. Never rendered by Home (§13 "Dead paths"). Bug: query orders by **`lastMessageAt`** but the cursor uses **`after.lastActivityAt`** — mismatched field, so `startAfter` cannot match the ordering and pagination is incorrect.

### 3.6 Events — **REAL, and correctly capped**
- `EventListProvider.loadHome` → `EventRepository`; Home renders `active + upcoming + recent(≤24h)`.
- `home_event_card.dart:539-559` `pickHome` sorts active-non-expired → active-expired → others, then participants desc, then remaining-time asc, and **`.take(3)`**.
- This satisfies **§14.5 ("Home: 3 events only + See more")** and **§14.10 ("Home loads only 3")**. **PASS**
- Gap vs §14.5 internal ranking: no recency/creator-quality/group-relevance terms — partial only.

### 3.7 Fan Works — **REAL**
`FanWorkFeedProvider` → `FanWorkRepository`; filtered `status==published && moderationStatus==approved` in the search path (`firebase_home_repository.dart:254-256`). `diversifyFanWorks` caps at 6 and forces ≥2 types (`home_fan_work_card.dart:339-354`). **PASS**

### 3.8 Anime — **REAL but silently absent**
`maybeAnimeHub(context)` → `AnimeHubProvider.section(AnimeCatalogKind.thisSeason)`.
- If `hub == null` **or** `snapshot.items.isEmpty` → `const SizedBox.shrink()` (`home_page.dart:535, 541`).
- The section **disappears with no empty/error/unavailable state**, while the provider is still loading on the first frame. Violates §2.1 and the brief's "honest state" requirement. **FAIL**

### 3.9 Edits / KIRARI — **REAL data, but the Home client bypasses the ranked feed**
- Primary: `EditsProvider` (singleton) with `FeedType.forYou`, `limit: 8`.
- Secondary: `home.feed.section('recommendedEdits')` mapped into synthetic `Edit` objects (`home_page.dart:412-436`) — constructing `commentsCount: 0`, `viewsCount: 0`, `status: 'published'` as literals. Those zeros are fabricated fields presented as counters. **Report.**

### 3.10 Firestore read cost per Home cold open (measured by inspection)

| Query | Trigger |
|---|---|
| `groups` promoted (limit 8) | `HomeProvider.load` → `ensureLoaded(promotedGroups)` |
| `groups` rising (limit 8) | `_GroupSection.build` microtask when section scrolls into build |
| callable `getDiscoveryFeed` (full feed) | `_prefetchFeed()` on every `load`/`refresh` — fetches **all 6 ranked sections** |
| callable `recommendedGroups` + Firestore `groups` newest | Recommended section (fallback may double-query) |
| callable `recommendedPeople` + Firestore `public_profiles` (18 docs) | People section |
| `edits` feed (limit 8) | `_EditsSection` |
| `events` | `EventListProvider.loadHome` |
| `fanWorks` | `FanWorkFeedProvider.load` |
| anime catalog | `AnimeHubProvider.load` |

`HomeProvider.refresh()` (`home_provider.dart:128-135`) re-runs **every non-placeholder section with `refresh: true` in `Future.wait`** — i.e. pull-to-refresh reloads all group/people sections unconditionally, which §5.5 ("لا تحميل كلي") and §25 discourage. There is **no in-flight guard**, so concurrent refreshes are possible.

---

## 4. CURRENT SECTIONS — MASTER SPEC §5.3 SCORECARD

| §5.3 mandated section | Present | Real data | Own distinct design | See-more |
|---|---|---|---|---|
| المجموعات المروّجة (Promoted Groups) | ✅ | ✅ server | ❌ shared card | ❌ |
| إيديتات مخصصة (personalized edits) | ⚠️ labelled "Trending" | ✅ server | ✅ | ❌ |
| الأحداث (3 + more) | ✅ | ✅ server | ✅ | ⚠️ only when empty |
| أعمال المستخدمين الخاصة (Fan Works) | ✅ | ✅ server | ✅ | ✅ (card) |
| أشخاص مقترحون (suggested people) | ⚠️ mislabelled fallback | ⚠️ | ❌ | ❌ |
| مجموعات مقترحة (recommended groups) | ⚠️ mislabelled fallback | ⚠️ | ❌ | ❌ |
| مجموعات صاعدة (Rising) | ✅ | ✅ **real ranking** | ❌ shared card | ❌ |
| أنميات الموسم / Anime Hub | ⚠️ partial (season only) | ✅ | ✅ | ✅ |
| أنمي الأسبوع (anime of the week) | ❌ | — | — | — |
| شخصيات شعبية (popular characters) | ❌ | — | — | — |
| نشاط الأصدقاء (friends activity) | ❌ | — | — | — |
| صنّاع صاعدون (rising creators) | ❌ | — | — | — |
| إنجازات/تقدم (achievements/progress) | ❌ | — | — | — |
| محتوى جديد بآخر نشاط | ❌ | — | — | — |

**No achievements/progress strip exists. No rank progression. No next-milestone element.**

---

## 5. CURRENT NAVIGATION

### 5.1 Routes Home actually calls — all resolve

| Call | Registered | Verdict |
|---|---|---|
| `/profile` | `pubget_app.dart:1017` | ✅ |
| `/notifications` | `:988` | ✅ |
| `/settings` | `:983` | ✅ |
| `/store` | `:1011` | ✅ |
| `/group?groupId=` | `:1052` | ✅ |
| `/profile?uid=` | `:1017` | ✅ |
| `/edits` | `:989` | ✅ |
| `/events` | `:1078` | ✅ |
| `/groups` | `:995` | ✅ |
| `/search` | `:982` | ✅ |
| `/fan-works` | `:1010` | ✅ |
| anime catalog | `:998`+ | ✅ |

**No dead routes are currently wired from Home.** ✅

### 5.2 Deep-link conformance — Master Spec §2.3 FAIL

Canonical paths required: `/group/{id}` · `/profile/{username}` · `/reel/{id}` · `/anime/{id}` · `/work/{id}` · `/event/{id}` · `/hashtag/{tag}` · `/audio/{id}`

`_routeFromUri` (`app_router.dart:360-458`) has **no parser branch** for `reel`, `hashtag`, or `audio`:
- `pubget_app.dart:1019,1021,1026` **do** register `/reel`, `/audio`, `/hashtag` pages, but only reachable via query form (`/reel?reelId=…`).
- A canonical-form link such as `/reel/abc123` parses to `path: '/reel/abc123'`, which matches **neither** `parameterizedPages` **nor** `domainPages`.
- It then hits `app_router.dart:205`: `_ => domainPages['/unknown'] ?? homePage`.

> **Result: any unregistered path silently renders Home instead of a clear error screen.** Spec §2.3 requires "بلا صلاحية ← شاشة مناسبة واضحة". Only the exact literal `/unknown` shows `UnknownLinkPage`.

Also: Home navigates with **query form** (`/group?groupId=`, `/profile?uid=`) rather than the canonical `/group/{id}` form. Both work; the canonical form is unused by Home. Note `/profile/{username}` per spec, but the implementation keys on **uid** (`app_router.dart:448`, `pubget_app.dart:1017`).

### 5.3 Bottom navigation — THREE-WAY CONFLICT (owner decision required)

| Source | Bottom bar definition |
|---|---|
| **Master Spec §4.2** ("يُحافظ على توزيعه الحالي كما هو") | `اكتشف · مجموعاتي · منضم لها · الخاص · إيديتات` — **5 tabs, no center create button** |
| **Current code** `app_shell.dart:95-136` | `Discover · Groups · [ + ] · Private · Edits` — **4 tabs + center create**; `joined` has **no visible tab** |
| **Task brief §9** | "Reels, Private, central create action, Groups, Discover" |

- `AppShellTab` enum still contains `joined` (`app_shell_tab.dart:2`) and `/joined` is a registered `shellPath` (`app_router.dart:266`), reachable only from the drawer (`app_shell_drawer.dart:48`).
- Master Spec wins over the brief. But the brief and the spec disagree with each other **and** with the code. **This is a genuine STOP-level ambiguity (brief §68) and is escalated, not decided.**

### 5.4 Side drawer gaps vs Master Spec §4.4

Present: profile, private, groups, joined, events, games, home, anime, store, premium, achievements, settings, guide.
**Missing from the spec list:** المجموعات المقترحة (suggested groups) · الإيديتات (edits) · الأعمال الخاصة (Fan Works).
**Logout is absent from the drawer entirely** — it exists only in `settings_page.dart:73`. Spec §4.4 requires "تسجيل الخروج (في الأسفل دائماً)". **FAIL.**
(Drawer scope is adjacent to Home; the drawer is opened from the Home top bar.)

### 5.5 Top bar vs Master Spec §4.1 — FAIL

Spec order (RTL): `[logo]` ← coins `(+)` ← dragon store ← search ← notifications ← profile ← `☰`

Actual (`home_page.dart:161-245`): avatar · notifications · **logo(center)** · settings · `☰`, with coins in a **separate strip below the bar**.
- **No search button** in the top bar (spec requires one).
- **No dragon-store button** in the top bar (spec requires one; `/store` is only reachable from the coin chip and drawer).
- A **settings** button is present, which the spec order does not include.
- Coins are in a second row, not inline as specified.

---

## 6. CURRENT STATES

`LoadingState` enum: `initial · loading · refreshing · loadingMore · loaded · empty · error · offline`.

### 6.1 Per-section state resolution — `_stateChild` (`home_page.dart:580-622`)

| State | Handled | Verdict |
|---|---|---|
| `loading` + no content | `_SkeletonSection` | ✅ skeleton, correct shape |
| `error` + no content | `PubgetErrorState` + retry | ✅ local, not full-screen — **good** |
| `empty` | `PubgetEmptyState` + smart action | ✅ |
| `loaded` | rail | ✅ |
| `refreshing` | falls through to `loaded` | ⚠️ no refresh indicator |
| `loadingMore` | rail + `_MoreCell` spinner | ⚠️ `CircularProgressIndicator` |
| **`offline`** | **no branch — falls through to `loaded`** | ❌ **FAIL** |

> **Critical:** `HomeProvider._setSectionFailure` (`home_provider.dart:259-268`) deliberately sets `LoadingState.offline` when cached content exists — but `_stateChild` has **no `offline` case**. Result: cached content renders with **no stale/offline indication and no retry**. Spec §2.1 requires "Offline (cached data available + Retry)". The user's brief §31 requires the same. **This is a confirmed functional gap, not a cosmetic one.**

### 6.2 Missing states summary
- **Offline/stale indicator: absent** (state exists, is produced, and is then ignored).
- **Refresh feedback: absent.**
- **Anime section: silent disappearance** instead of loading/empty/error.
- `_prefetchFeed` failure is swallowed: `onFailure: (_) {}` (`home_provider.dart:176`) — no user-visible signal, no degraded-mode marker.
- `UnavailableHomeRepository` exists (returns a uniform failure) but is **never constructed anywhere in `lib/`** — dead class.

---

## 7. CURRENT LOCALIZATION

- System: custom central catalog `AppStrings` with `pick(en, ar)` (`app_strings.dart`) — **not** `gen_l10n`/ARB. This satisfies §1.4's "central localization system" requirement as an architectural choice. **Do not migrate.**
- Self-documented limitation, `app_strings.dart:3-6`: *"Feature screens that are not yet translated still contain English literals."*
- **Home's own strings are correctly localized**: `sectionPromoted`, `sectionRecommended`, `sectionRising`, `sectionPeople`, `sectionEdits`, `sectionEvents`, `sectionFanWorks`, `nothingHereYet`, `sectionFailed`, `tryAgainShort`, `loadMore`, `seeMore`, `searchPeople`, `exploreGroups`, `membersCount`, `fansCount`, `groupTypeLabel`, `pagesCount` — all bilingual. ✅

### 7.1 Hardcoded English reaching Home users — CRITICAL

1. **`discovery_errors.dart:15-27`** — the failure *messages* are English literals:
   - `'Discovery could not load.'`, `'Check your connection and try again.'`, `'Sign in to load discovery.'`
   - `home_page.dart:594, 399` renders `state.failure?.message` **directly into the UI**.
   - **→ Arabic users see English error text. Spec §1.4: "كلمة إنجليزية واحدة في الواجهة العربية … عيب حرج". FAIL.**
2. **`pubget_states.dart:40-43`** — `PubgetErrorState` defaults `title = "Couldn't load this"`, `message = 'Please try again.'`, **`retryLabel = 'Try again'`**. Home does not pass `retryLabel`, so the **retry button reads "Try again" in Arabic**. **FAIL.**
3. **`pubget_states.dart:72-75`** — `PubgetOfflineState` defaults all English. Not currently reached from Home, but it is the shared offline component.
4. **`pubget_states.dart:132-133`** — `PubgetLoadingStateView` empty fallback is English.
5. **`app_shell_tab.dart:27-32`** — `AppShellTab.label` returns hardcoded English `'Discover'/'Groups'/'Joined'/'Private'/'Reels'`. Not used by `AppShell` (which uses `copy.tabDiscover`), so latent — but a live trap for the next change.
6. **`home_fan_work_card.dart:307`** — `'✦ AI'` badge (arguably acceptable as a universal term; minor).

### 7.2 Unused-but-present localized copy (dead product intent)
`AppStrings.homeWhatNow` = `'ماذا أفعل الآن؟'` and `AppStrings.coldStartBanner` exist but are **referenced nowhere in `lib/`**. Spec §5.1 defines Home as answering "ماذا أفعل الآن؟" and §5.4 requires new/returning-user differentiation. The copy exists; the feature does not.

---

## 8. CURRENT THEME SUPPORT

**The theme layer is genuinely good and should be preserved.**
- `AppColors` (`app_colors.dart`): royal purple family, gold family, semantic success/warning/error/info with dark variants, and **separate** dark and light surface/text/outline scales.
- `AppTheme._build` (`app_theme.dart`) constructs both `Brightness.light` and `Brightness.dark` with distinct `background / surface / mutedSurface / strongSurface / text / mutedText / outline` tuples. **This is the "light is designed, not inverted" requirement of §1.3 — PASS.**
- Component themes: divider, appBar, input, elevated/outlined/text buttons, snackBar, bottomSheet, tooltip, pageTransitions, navigationBar. Shadows (`app_shadows.dart`) and motion (`app_motion.dart`) exist.

### 8.1 Theme defects on Home

| # | Finding | Location |
|---|---|---|
| T1 | **Home cards bypass the theme entirely.** `HomeSquareGroupCard` hardcodes 3 gradient palettes and text colours `0xFF1B1028` / `0xFF3B2A18`. Identical in light and dark mode — coincidentally legible, but not designed per theme. | `home_luxury_tiles.dart:30-46, 96-116` |
| T2 | **Off-brand palette.** `HomePersonCard` uses a teal/mint gradient `0xFFE8FFFB → 0xFF9EE8DC → 0xFF4EC4B4` with dark-teal text — outside the purple+gold identity. Violates §1.3 and the brief's colour restraint. | `home_luxury_tiles.dart:149-155, 173, 180, 190` |
| T3 | **No image-failure fallback that matches the brand.** `AppImageLoader`'s default error widget is `Icon(Icons.broken_image_outlined)`; Home passes no override. Missing group images render as a broken-image glyph — precisely what the brief prohibits. | `app_image_loader.dart:120-124`; `home_luxury_tiles.dart:79-83` |
| T4 | **Blind spinner as image placeholder.** `AppImageLoader`'s default `loading` is `CircularProgressIndicator`; Home passes no `placeholder`. A Home rail shows up to 8 concurrent spinners instead of skeletons. Violates §2.1. | `app_image_loader.dart:125-130` |
| T5 | **Hardcoded gold accent bar** on `PubgetSectionHeader`, not theme-derived. | `pubget_atmosphere.dart:76-81` |

---

## 9. CURRENT PERFORMANCE RISKS

| # | Risk | Severity | Evidence |
|---|---|---|---|
| P1 | **Mass simultaneous video initialisation.** `HomeEditPreviewCard.initState` creates a `VideoPlayerController.networkUrl` and calls `initialize()` **+ `play()` for every card**, eagerly, with no viewport awareness, no thumbnail-first gate and no single-active-player constraint. | **CRITICAL** | `home_luxury_tiles.dart:216-232` |
| P2 | **Full-video download for previews.** `initialize()` pulls the whole clip even when `thumbnailUrl` exists; the thumbnail only shows while `_ready == false`. Spec §15.14 and §25 both require *cover + preload-next + dispose-previous*. | **CRITICAL** | `home_luxury_tiles.dart:271-290` |
| P3 | **Permanent decoder hold.** `_clipFirstSecond` pauses/seeks-to-0/replays forever once position ≥ 1 s. Combined with P1, N cards each hold an active decoder indefinitely. | **CRITICAL** | `home_luxury_tiles.dart:234-242` |
| P4 | **Not lazy at the section level.** All nine sections are `SliverToBoxAdapter`, so the whole section tree is constructed on first frame. Only the inner horizontal `ListView`s are lazy. §25/§33 want sliver-level laziness. | HIGH | `home_page.dart:79-107` |
| P5 | **Refresh reloads everything.** `HomeProvider.refresh()` re-queries all non-placeholder sections with no in-flight guard → duplicate concurrent refreshes possible; no scroll-position preservation. | HIGH | `home_provider.dart:128-135` |
| P6 | **Full discovery feed prefetch.** `_prefetchFeed()` requests the entire ranked feed (6 sections) on every load and refresh although Home consumes 2 of them; its failure is swallowed. | MEDIUM | `home_provider.dart:161-179` |
| P7 | **Arbitrary 18-doc `public_profiles` scan** on the people fallback path, with client-side fake pagination. | MEDIUM | `firebase_home_repository.dart:184-198` |
| P8 | **Storage images fetched as raw bytes up to 12 MB**, then decoded — for small Home cards. | MEDIUM | `app_image_loader.dart:95-102` |
| P9 | **Nested horizontal scrollables** (7 of them) inside one vertical `CustomScrollView`; each builds independently with default `cacheExtent`. | LOW | `home_page.dart` |
| P10 | **Provider over-subscription:** `_AppShellState._onRouteChanged` calls `setState` on every router notification, rebuilding the whole shell (incl. `IndexedStack` of 5 pages). | MEDIUM | `app_shell.dart:49-51` |
| P11 | Five `Future.microtask(load)` side effects inside `build()`, each re-evaluated on every rebuild. | MEDIUM | `home_page.dart` |

**Positives:** `AppImageLoader` correctly does decode-time downscaling (`memCacheWidth`), `gaplessPlayback`, cached futures, and single-axis decode to preserve aspect ratio. `HomeHorizontalStrip` uses `ListView.separated` (lazy). `CustomScrollView` is used instead of a monolithic `SingleChildScrollView`. These are the right instincts.

---

## 10. CURRENT ACCESSIBILITY RISKS

| # | Risk | Evidence |
|---|---|---|
| X1 | **The entire Home top bar is forced LTR** via `Directionality(textDirection: TextDirection.ltr)` — in the Arabic UI the avatar sits left and settings/menu sit right. Spec §4.1 gives the order explicitly "في RTL"; §1.4 requires RTL auditing. **CRITICAL.** | `home_page.dart:169-171` |
| X2 | **A test codifies X1.** `home_app_bar_order_test.dart` pumps the bar inside `Directionality(textDirection: TextDirection.rtl)` then asserts `avatar.left < notify.left` and `settings.left > logo.right` — i.e. it *enforces* LTR positioning in an RTL context. Fixing the header will fail this test; it must be changed deliberately. | `test/home_app_bar_order_test.dart:33-45` |
| X3 | **No semantic labels on any Home card.** Group, person, edit and fan-work cards expose no `Semantics` label; the avatar tap target has none either. Only 2 `semanticLabel` uses exist in the whole Home chain (both See-more text buttons). | `home_page.dart:480, 610` |
| X4 | **Non-mirroring directional icon in RTL.** `HomeFanWorksSeeAllCard` uses `Icons.arrow_forward_rounded`, which Flutter does **not** auto-flip. Points the wrong way in Arabic. | `home_fan_work_card.dart:227` |
| X5 | Touch targets: `_MoreCell` is a bare `TextButton` in a 120px box; icon boxes are 36px (`HomeTopBar.iconSize`) — at the low end of the 48dp guidance, mitigated by `_BarIconBox` `SizedBox.square`. | `home_page.dart:253-257, 624-644` |
| X6 | **No large-text / text-scale audit.** Card heights are fixed (214/228/188/286) with `Column` layouts holding 3–5 text lines; `HomeSquareGroupCard` uses `Expanded` for the image so text is protected, but `HomeFanWorkCard`'s fixed `AspectRatio(3/4)` + 4 stacked text rows in 286px is the most fragile under `textScaleFactor > 1.3`. **NOT VERIFIED** — no test or screenshot covers it. |
| X7 | `pubget_accessibility_test.dart` uses `home:` only as a `Scaffold` parameter in **generic component tests** — it does **not** test the Home screen. Home has effectively no accessibility test coverage. |

---

## 11. MOCK / FAKE DATA FINDINGS

**Result: NO `_mock*` / `_fake*` production lists exist in `lib/features/home/`.** The brief's §41 red line is currently clean.

Non-fake but **misleading-signal** findings:

| # | Finding | Location |
|---|---|---|
| F1 | "Recommended groups" falls back to **newest-by-date** ordering while keeping the "recommended" label. | `firebase_home_repository.dart:114-125` |
| F2 | "People to discover" falls back to an **unfiltered 18-doc sample**, identical for all users. | `firebase_home_repository.dart:178-202` |
| F3 | "Trending Reels" section renders a **`FeedType.forYou`** feed. The label asserts trending; the data is personalised-for-you. Spec §5.2.2 actually asks for *interest-based* edits here — so the label is wrong in both directions. | `home_page.dart:320` (`AppStrings.sectionEdits`) vs `edits_provider.dart:16` |
| F4 | Synthetic `Edit` objects built from feed metadata hardcode `commentsCount: 0`, `viewsCount: 0`, `status: 'published'`. Fabricated counter values. | `home_page.dart:419-433` |
| F5 | `rankedOrFallback` hides ranking failure/emptiness behind a non-personalised result with no user signal. | `discovery_errors.dart:34-48` |

---

## 12. BROKEN / MISSING ROUTES

- **No route wired from Home is dead.** ✅
- **Unregistered paths silently render Home** instead of `UnknownLinkPage` — `app_router.dart:205` catch-all. Any `/reel/{id}`, `/hashtag/{tag}`, `/audio/{id}` canonical deep link lands on Home. **FAIL vs §2.3.**
- `/joined` is registered and reachable from the drawer, but has **no bottom-nav tab** (see §5.3).
- `AppShellTab.canonicalPath` maps edits → `/reels`, but `AppShell._go` navigates to `/edits` — two live aliases for one tab.

---

## 13. HARDCODED STRINGS (summary)

See §7.1 for the full list with severities. Home's own widgets: **clean**. Reachable English in the Arabic UI via shared components: **`PubgetErrorState.retryLabel`**, **`PubgetErrorState` defaults**, **`PubgetOfflineState` defaults**, **`discovery_errors.dart` messages**, **`AppShellTab.label`**, **`PubgetLoadingStateView` empty fallback**.

---

## 14. MISSING STATES (summary)

| State | Home | Note |
|---|---|---|
| Loading (skeleton) | ✅ | `_SkeletonSection`, correct card shape |
| Loaded | ✅ | |
| Empty | ✅ | with smart action |
| Error (local) | ✅ | localized title, **English message + English retry label** |
| **Offline / stale** | ❌ | state produced, then ignored by `_stateChild` |
| Refreshing | ❌ | no indicator |
| Loading-more | ⚠️ | spinner |
| Permission denied | ❌ | not distinguished |
| Expired | ❌ | not applicable to current sections |

---

## 15. DUPLICATE / DEAD COMPONENTS

### 15.1 Dead code (verified zero references outside their own definition)

| Symbol | Location |
|---|---|
| `HomeSection` (model class) | `home_models.dart:150-166` |
| `HomeProvider.displayOrder` | `home_provider.dart:82-98` — **only** `test/home_provider_display_order_test.dart` calls it |
| `HomeSectionKind.communityActivity` + `getCommunityActivity` | `home_models.dart:13`, `home_provider.dart:64,234` |
| `HomeSectionKind.editsPlaceholder / eventsPlaceholder / gamesPlaceholder / fanWorksPlaceholder / animePlaceholder` | `home_models.dart:15-19` — 5 placeholder kinds never loaded or rendered |
| `UnavailableHomeRepository` | `unavailable_home_repository.dart` — never constructed |
| `HomeProvider.coldStart` | `home_provider.dart:103` — set from server, never read by UI |
| `AppStrings.homeWhatNow`, `AppStrings.coldStartBanner` | `app_strings.dart:295, 308` |

> Note: `gamesPlaceholder` is **correctly** never rendered — Master Spec §12.1 forbids creating games from Home.

### 15.2 Duplicate components (same job, two implementations)

| Job | Used by Home | Unused design-system twin |
|---|---|---|
| Group card | `HomeSquareGroupCard` | `PubgetGroupTile` (`pubget_discovery.dart:211`) — **0 refs** |
| Person card | `HomePersonCard` | `PubgetPersonTile` (`:302`) — **0 refs** |
| Media/reel card | `HomeEditPreviewCard` | `PubgetMediaTile` (`:132`) — **0 refs** |
| Hero banner | *none* | `PubgetHeroBanner` (`:13`) — 1 ref, in `group_details_page.dart` |
| First-session actions | *none* | `PubgetNowActions` (`:73`) — **0 refs** |
| Recommendation reason | *none* | `PubgetReasonChip` (`:117`) — **0 refs** |
| State resolution | `_stateChild` + `_SkeletonSection` (hand-rolled in Home) | `PubgetLoadingStateView` (`pubget_states.dart:102`) |

**Test-coverage trap:** `test/home_command_center_test.dart` tests `PubgetHeroBanner` + `PubgetNowActions` — i.e. it validates **components the current Home never renders**. It also asserts `AppStrings.homeWhatNow`. This test gives false confidence about Home's identity layer. It passes, but it is not testing the shipped Home.

---

## 16. SPECIFICATION CONFLICTS (escalated, not decided)

| ID | Conflict | Authority ruling |
|---|---|---|
| **C1** | **Bottom navigation.** Spec §4.2 = 5 tabs, no center create. Code = 4 tabs + center create, `joined` demoted to drawer. Brief §9 = a third, different arrangement. | **BLOCKED — needs owner ruling.** Spec wins by default, but this changes global navigation and `app_shell_test.dart` asserts "five tabs render". Not a Home-only decision. |
| **C2** | **Top bar composition.** Spec §4.1 mandates logo · coins(+) · dragon-store · search · notifications · profile · ☰. Code has avatar · notifications · logo · settings · ☰ + a separate coin strip, with **no search and no dragon-store button**. | Spec wins. Home must gain search + store; must decide whether `settings` stays. |
| **C3** | **"Recommended"/"suggested" labels over non-personalised fallbacks** (F1, F2). Spec §5.4 forbids false recommendation reasons. | Either (a) surface ranked-only and show an honest "unavailable/needs more activity" state, or (b) relabel the fallback section. **Product copy decision — escalated.** |
| **C4** | **"Trending Reels" label over a For-You feed** (F3). Spec §5.2.2 says Home's second slot is *interest-based* edits. | Relabel to the interest-based phrasing the spec actually mandates. Low risk, flagged for HOME-05. |
| **C5** | **Deep-link canonical forms** `/reel/{id}`, `/hashtag/{tag}`, `/audio/{id}` are registered as pages but unparseable, and fall through to Home. | Spec §2.3 wins. Touches `app_router.dart` (shared) — needs an explicit scope decision in HOME-03. |
| **C6** | **Drawer omissions** (suggested groups, edits, Fan Works) and **missing logout**. Spec §4.4. | Drawer is adjacent to, not inside, Home. Reported, not actioned in this phase. |

**No conflict found between source code and the Master Spec on data truthfulness for Promoted Groups, Rising Groups, Events cap, Fan Works, or Achievements (absent rather than contradictory).**

---

## 17. BLOCKERS

**None blocking HOME-00 itself.** The repository analyzes clean and all 30 Home-related tests pass.

Pre-existing conditions that will constrain later Home phases:

1. **No current Home screenshots exist** → HOME-13 visual QA has no baseline; it must capture its own.
2. **Debug APK is stale** (2026-09-28 vs HEAD 2026-10-05) → HOME-14 must run a fresh build.
3. **`.p02_worktree/` (untracked) is not excluded in `analysis_options.yaml`**, and neither is `build/**`. The first `flutter analyze` aborted with SIGTERM while walking `build/**` XML. Analyzer runs are slower and less stable than they should be. Repo hygiene, outside Home scope.
4. **`home_app_bar_order_test.dart` enforces the RTL violation** (X2) → any correct header fix *will* fail this test by design.
5. **`app_shell_test.dart` asserts "five tabs"** → C1 resolution will require updating it.
6. Backend deploy state, emulator rule tests, and live Firebase data volumes are **NOT VERIFIED** from this environment.

---

## 18. RECOMMENDED IMPLEMENTATION ORDER

Ordered by dependency and by (spec-conflict risk ÷ user visibility). Each step names its gate.

**Phase A — establish truthfulness and safety first (low risk, high integrity gain)**
1. **A1 · Localize the failure surface.** Remove English from `discovery_errors.dart` and `pubget_states.dart` defaults; make Home pass a localized `retryLabel`. *Unblocks HOME-12 and removes the §1.4 critical defect. Pure addition, no layout change.*
2. **A2 · Honour the offline state.** Add the missing `offline` branch in `_stateChild` → cached content + subtle stale chip + retry. *Implements §2.1 / brief §31.*
3. **A3 · Fix video behaviour (P1–P3).** Thumbnail-first, viewport-aware single-active preview, dispose on exit, retry on failure. *Removes the only CRITICAL performance defect; required before any visual work on §D.*
4. **A4 · Branded image fallback + skeleton placeholders.** Kill `broken_image_outlined` and the image `CircularProgressIndicator` on Home. *Fixes T3/T4 and the brief's explicit prohibition.*

**Phase B — resolve owner decisions before touching layout**
5. **B1 · Escalate C1 (bottom nav) and C2 (top bar) to the owner.** Both are global navigation changes with existing tests. *Must precede HOME-03.*
6. **B2 · Decide C3/C4 labelling policy** for recommended/suggested/trending.
7. **B3 · Decide C5 scope** — whether `/reel/{id}`, `/hashtag/{id}`, `/audio/{id}` parsing lands in the Home phase or a separate navigation phase.

**Phase C — architecture (do this before adding sections)**
8. **C1 · Introduce a real `HomeFeed` / `HomeSection` model** (§26 of the brief) so section type/state/title/items/navTarget are data, not a hardcoded widget tree. Retire the dead `HomeSection` class by actually using it.
9. **C2 · Wire `displayOrder` into production** so §5.2.3 rotation is real; add per-visit rotation beyond the existing content-first rule.
10. **C3 · Stop the dual discovery source.** Decide one owner per section (ranked feed vs domain provider) and delete the synthetic `Edit` mapping (F4).
11. **C4 · Scope the shared singletons.** Give Home its own `EditsProvider` / `EventListProvider` instances (or a read-only projection) so Home cannot corrupt the Reels and Events tabs (A3).
12. **C5 · Make refresh safe.** Single-flight guard, preserve scroll offset, refresh only stale sections.
13. **C6 · Delete confirmed dead code** (`HomeSectionKind` placeholders, `communityActivity` or fix its cursor bug, `UnavailableHomeRepository` if truly unused). *Do not delete `risingScore` machinery — it is correct.*

**Phase D — IA and visual system**
14. **D1 · Write the Home IA** (first viewport, section order, density rhythm, new-vs-returning emphasis using the already-available `coldStart` signal).
15. **D2 · Extend the design system** with the missing primitives: themed group hero card, distinct recommended card, rising card, branded fallback, offline/stale chip, rank/achievement strip, section header wired to subtitle + See-more.
16. **D3 · Distinct card per section** — kill the "one card, three gradients" violation of §5.3.
17. **D4 · Move Home cards onto `colorScheme`** and remove the teal off-brand palette (T1/T2).
18. **D5 · Convert every section to a sliver** for lazy construction (P4), and add See-more routing to real section pages.

**Phase E — content completeness**
19. **E1 · Add the 6 missing §5.3 sections**, each gated on real backend availability, with honest states where a backend is not ready (anime of the week, popular characters, friends activity, rising creators, achievements/progress, freshest content). **Never fabricate to fill.**
20. **E2 · Arabic typography pass** — remove negative `letterSpacing` for Arabic, choose/verify an Arabic family (spec §1.3/§1.4, brief §22).

**Phase F — QA gates**
21. **F1 · Update the codifying tests** (`home_app_bar_order_test`, and `app_shell_test` if C1 changes tabs) — deliberately, with the spec cited in the test comment.
22. **F2 · Add real Home coverage**: RTL/LTR × dark/light × loading/empty/error/offline; semantics; large text scale; navigation resolution. Replace the `home_command_center_test` false-confidence gap.
23. **F3 · HOME-13/14 gates**: capture Home screenshots in ar/en × dark/light at 3 widths; fresh `flutter build apk --debug`; re-run analyze + full Home suite; record exact results.

---

## 19. WHAT MUST NOT BE REGRESSED

Passing today — protect explicitly:

- `flutter analyze` = 0 issues.
- 30/30 Home, shell, discovery and error-mapping tests.
- Rising Groups ranking chain (scheduler → `risingScore` → query → card). **Spec-correct; do not replace with member-count ordering.**
- Promoted Groups identical-for-all-users semantics.
- Events Home cap at exactly 3 with active-first ranking.
- Fan Works type diversification (≥2 types within 6).
- Per-section local error/empty with retry — already correct, keep the property.
- `firestore.rules:691` list permission + the `deletionPending` filter rationale in the comment — do not "simplify" the query.
- `AppImageLoader` decode sizing and aspect-ratio preservation.

---

## 20. FINAL STATUS

| Item | Status |
|---|---|
| Repository analyzes clean | **PASS** |
| Home/shell/discovery tests | **PASS** (30/30) |
| Debug build (current HEAD) | **NOT VERIFIED** (stale artifact) |
| Backend deploy / emulator rules | **NOT VERIFIED** |
| Home visual QA | **NOT VERIFIED** (no current screenshots) |
| Fake production data in Home | **PASS — none found** (5 misleading-signal findings instead) |
| Dead routes wired from Home | **PASS — none** |
| Master Spec §5 (Home) conformance | **FAIL** on ordering rotation, section inventory, distinct per-section design, See-more, and label truthfulness |
| Master Spec §1.4 (localization/RTL) conformance | **FAIL** — forced-LTR top bar; English in Arabic error/retry surfaces |
| Master Spec §2.1 (UI states) conformance | **FAIL** — offline/stale state produced then ignored |
| Master Spec §4.2/§4.1 (navigation) conformance | **FAIL** — see C1/C2 |
| Master Spec §15.14 / §25 (video perf) conformance | **FAIL** — P1/P2/P3 |

**HOME-00 status: COMPLETE (audit only). No production code was modified.**

**Blocking items for HOME-01+:** C1 and C2 require an owner ruling before any navigation work. C3 requires a copy-policy ruling before the recommended/people sections are redesigned.

Per the operating prompt's own gate, nothing in this report may be reported as "working" on the basis of code existing — only the items in §20 marked PASS were executed and verified.
---

## 21. IMPLEMENTATION ADDENDUM (HOME-01, same branch)

This addendum records what was built against the findings above. It does not
replace §20; where the two disagree, §20 describes the pre-fix state and this
section describes the state at the end of the branch.

### 21.1 Resolved

| Finding | Resolution |
|---|---|
| §5.3 missing five sections | `getHomeSections` callable serves anime-of-the-week, popular characters, rising creators, friends' activity, freshest content. Wired through `HomeRankedSection`. |
| §5.2 ordering | Promoted Groups is pinned first and personalized edits second (`FeedType.forYou`, real per-user ranking). `_rotatedSections` shuffles everything after them once per visit using `HomeProvider.rotationSeed`. |
| §5.2.3 rotation absent | `lib/features/home/section_rotation.dart`. Seeded, so one build yields one stable order and rows never reshuffle under a finger. |
| Fabricated edits on Home | `_editsForHome` deleted. Home now shows only real `EditsProvider` items, and an honest empty state otherwise. |
| §5.4 false reason | Reasons are server-supplied and rendered verbatim; an unknown or absent reason renders no label at all. |
| §1.4 English in Arabic errors | All Home failure copy routes through `discoveryFailureMessage`. Covered by `discovery_error_mapping_test.dart`. |
| §4.1 top bar order | Logo ← coins `(+)` ← store ← search ← notifications ← profile ← menu, pinned by `home_app_bar_order_test.dart`. |
| §4.1 forced LTR / overflow | Row order follows `Directionality`, not a forced LTR. Below 380 px the bar scales to 32 px icons and a 48 px logo with no overflow. |
| §2.1 offline/stale ignored | A failed refresh keeps loaded rows and marks the section stale with `PubgetStaleBanner`; a refresh sets `refreshing` without blanking content. |
| Section refresh was partial | `refresh()` now reloads the ranked sections as one unit. |
| Ranked sections double-loaded | `ensureLoaded` and `refresh` no longer route callable-backed sections through the legacy per-section fetch, which was overwriting the callable result with an empty page. |

### 21.2 Correctness issues found and fixed during implementation

These were defects in the first cut of this branch, caught by writing tests
against the real Firestore schema rather than against the code's own assumptions:

- **Anime of the week could never populate.** It read `weeklyRatingCount` and
  `lastRatedAt` from `animeCatalog`, but no code in the repository writes either
  field. The section would have shipped permanently empty. It now counts real
  published `edits` created in the last seven days per `animeId`, and falls back
  to `anime_stats.updatedAt` (moved by every rating transaction) when nothing
  was published. Covered by four tests, including one that proves edits older
  than the window are excluded.
- **Popular characters silently reported zero favourites.** It counted favourites
  with `collectionGroup("character_favorites")`, which needs a collection-group
  index that does not exist in `firestore.indexes.json`. The `.catch()` turned
  that failure into "every character has zero favourites" and ranked the section
  on a signal that does not exist. It now reads `character_stats.favoritesCount`,
  which `animeListsDomain` maintains transactionally.
- **`discussionCount` is written by nothing.** The section now treats it as
  optional and drops any character with neither signal, instead of ranking on a
  permanently zero field.

### 21.3 Verification

| Gate | Result |
|---|---|
| `flutter analyze --no-pub` | **PASS** — no issues |
| Backend `npm run check` | **PASS** |
| Backend `npm test` | **PASS** — 496/496 |
| `functions/test/homeSections.test.js` | **PASS** — 27/27 |
| `home_ranked_sections_test.dart` | **PASS** — 8/8 |
| `home_section_rotation_test.dart` | **PASS** — 5/5 |
| `home_app_bar_order_test.dart` | **PASS** — 5/5 (LTR + RTL, 320/360/412 px) |
| `discovery_error_mapping_test.dart` | **PASS** — +7 |
| Related Home/shell suites | **PASS** |
| Full `flutter test` | **PASS** — 830 tests across all 132 files, run in 4 batches (a single full run exceeds the 900 s tool timeout) |
| `flutter build apk --debug` | **PASS** — `build/app/outputs/flutter-apk/app-debug.apk` |
| Firebase emulator rules/indexes | **NOT VERIFIED** — `getHomeSections` has not been run against the emulator |
| Home visual QA (ar/en, light/dark, multiple widths) | **NOT VERIFIED** — no device attached |
| `getHomeSections` deployed | **NOT VERIFIED** |

### 21.4 Still open

- C1/C2 (five-tab shell and `/edits` vs `/reels` deep links) and C3 (copy policy
  for the recommended/people sections) still need an owner ruling.
- See-more is shown only where a real listing page exists: anime of the week and
  popular characters. Rising creators, friends' activity and freshest content
  have no listing route yet, so they render without the action rather than
  linking somewhere unrelated.
- Firestore index and rule coverage for the new queries is unverified against
  the emulator.
- No Arabic/English, light/dark, device-width visual pass has been done.
