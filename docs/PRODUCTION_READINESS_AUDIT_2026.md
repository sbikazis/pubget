# Pubget — Production Readiness Audit

**Date:** 2026-10-14
**Scope:** Flutter client (`lib/`), Cloud Functions (`functions/`), security rules,
web shell, and project metadata.
**Auditor lens:** Meta/Microsoft-grade product quality — correctness, trust,
bilingual (AR/EN) integrity, state handling, and platform professionalism.

---

## ملخّص تنفيذي (Executive summary — العربية)

راجعتُ المشروع بالكامل بمنهجية تدقيق احترافية وقارنته بمعايير تطبيقات
Meta وMicrosoft. الخلاصة:

- **العميل (`lib/`) نظيف تمامًا:** `flutter analyze` لا يُظهر أي مشكلة في كود
  التطبيق. لا توجد أي `TODO/FIXME/XXX/HACK` أو `UnimplementedError` في `lib/`.
  المشروع مبني بالفعل بمعمارية ناضجة (design system، طبقة `Failure` موحّدة،
  خدمات، مستودعات، مزوّدات).
- **المشاكل الحقيقية كانت في:** (1) اختبارات قديمة تكسر CI، (2) بيانات
  التطبيق/الويب ما زالت على قيَم Flutter الافتراضية، (3) شاشات غير مترجمة
  (الدليل + البحث)، (4) تسريب رسائل أخطاء خام للمستخدم، (5) مسافات/محاذاة
  غير مدركة لـ RTL.
- **تم إصلاح كل ذلك في هذا الـ PR** (انظر قسم "ما تم إصلاحه").
- **ما تبقّى (خارطة طريق):** توطين شاشات المجموعات (103 نصًا) — وهي أكبر فجوة
  متبقية، وموصى بها كأولوية تالية.

---

## Severity legend

| Level | Meaning |
|---|---|
| **Blocker** | Breaks CI/release or ships a broken user path |
| **High** | User-visible defect or trust issue in a core flow |
| **Medium** | Inconsistency, missing polish, technical debt with UX impact |
| **Low** | Cosmetic / nice-to-have |

---

## 1. Build & CI health

| Check | Result |
|---|---|
| `flutter analyze` (app code `lib/`) | ✅ **0 issues** |
| `flutter analyze` (full tree, before) | ❌ 11 issues — all stale test fakes |
| `functions` (`npm run check`, `npm test`) | Present in CI (`ci.yml`), unchanged |
| Rules tests (emulator E2E) | Present in CI, unchanged |

**Finding (Blocker, fixed):** the analyzer reported 11 errors/warnings, **all in
`test/`** fakes that had drifted from the production interfaces. On any branch
that runs `flutter analyze`, CI turns red.

- `reportAnime` was renamed to `reportReview` in
  `AnimeHubSocialProvider` + `AnimeHubSocialRepository`; the test still called
  the removed method.
- `getStaff` / `AnimeStaff` were removed from the `AnimeRepository` interface;
  `FakeAnimeRepository` and the provider-chain test still implemented them.

Fixed by realigning the fakes with the current interfaces (see §6).

---

## 2. App / platform metadata professionalism

| File | Before | After |
|---|---|---|
| `pubspec.yaml` | `description: "A new Flutter project."` | Real product description |
| `web/manifest.json` | `name/short_name: "pubget"`, `description: "A new Flutter project."`, theme `#0175C2` (Flutter blue) | `Pubget`, real description, brand `theme_color #6C3FC5`, `background_color #140C22` |
| `web/index.html` | `description: "Pubget application foundation."`, no `theme-color`, no Apple meta, `lang` unset | Real description, `theme-color`, Apple Web-App meta, `viewport-fit=cover`, `lang="en"`, Apple touch icon, descriptive `<title>` |

The default Flutter-blue PWA chrome shipped next to a royal-purple brand
(`AppColors.royalPurple = #6C3FC5`) — a first-impression mismatch
(Medium → fixed).

---

## 3. Localization (AR/EN) integrity

The repo uses a **custom** copy layer (`AppStrings` + per-feature copy classes
`AnimeCopy`, `FanWorkCopy`, `GameCopy`, `EditCopy`) — not ARB/gen-l10n. Coverage
is high for auth, settings chrome, anime, fan works, games, and events.

**Gap 1 — Search screen chrome (High, fixed).** Result *kind* labels already
resolve through `AppStrings.searchHitLabel`, but the AppBar title, the
"runnable" hint, the empty state, and the `'Pubget user'` fallback were hardcoded
English. A new feature-local `SearchCopy` (mirroring the existing copy pattern)
now localizes all four.

**Gap 2 — Settings → Guide (High, fixed).** The entire page — AppBar, search
hint, empty state, and **18 topic blocks** — was hardcoded English. It also
rendered a raw internal route in its CTA (`"Open /groups"`), leaking routing
internals. Now:
- bilingual `GuideCopy` + `GuideTopic` (EN/AR pairs),
- search filters the **resolved locale** strings,
- CTA is a generic localized "Open" label with an arrow (no route leak).

**Gap 3 — Groups feature (Medium, roadmap).** ~103 hardcoded literals, split
between Arabic-only and English-only, so each locale sees the other language in
places. This is the largest remaining l10n debt and the recommended next PR.

---

## 4. Trust: raw error surfacing

The app has an excellent centralized error taxonomy
(`core/errors/failure.dart`, `firebase_failure_mapper.dart`) whose contract is
explicit: **raw backend text is never surfaced**. Two call sites violated it:

- `features/fan_works/screens/fan_work_screens.dart:859` — `SnackBar(Text(error.toString()))`
  on a picker read failure could show `PlatformException(...)`.
- `features/groups/.../create_group_wizard/step1_identity.dart:268` —
  `_uploadError = error.toString()` rendered the raw exception inline.

Both now show the localized, mapped copy (`copy.uploadFailed` /
`copy.imageUploadFailed`) and log the raw detail via `debugPrint` for
diagnostics only.

---

## 5. RTL correctness

The codebase is mostly RTL-aware (16 `EdgeInsetsDirectional`, 26
`AlignmentDirectional`, `TextAlign.start/end`). Remaining physical-direction
usages were fixed:

| File | Change |
|---|---|
| `edits/widgets/global_edit_upload_bar.dart` | `EdgeInsets.only(right:)` → `EdgeInsetsDirectional.only(end:)` |
| `groups/widgets/sticker_picker_sheet.dart` | `right:` → `end:`; `Alignment.topRight` → `AlignmentDirectional.topEnd` |
| `groups/widgets/wa_composer/wa_emoji_panel.dart` | `left:` → `start:`; `Alignment.topRight` → `AlignmentDirectional.topEnd` |
| `groups/widgets/chat_message_bubble.dart` | `EdgeInsets.only(left:)` → `EdgeInsetsDirectional.only(start:)` |
| `groups/widgets/chat_message_actions_overlay.dart` | scale origin now respects `Directionality` |

*Deliberately left as-is:* the two WhatsApp-style composers intentionally force
`TextDirection.rtl`; that is a design decision, not a bug.

---

## 6. Changes in this PR

```
pubspec.yaml                                                   # real description
web/manifest.json                                              # brand + real metadata
web/index.html                                                 # PWA/Apple meta, real copy
lib/features/search/l10n/search_copy.dart                      # NEW bilingual copy
lib/features/search/screens/search_page.dart                   # localize chrome/empty/fallback
lib/features/settings/l10n/guide_copy.dart                     # NEW bilingual guide copy + topics
lib/features/settings/screens/guide_page.dart                  # localize + drop raw-route CTA
lib/features/fan_works/screens/fan_work_screens.dart           # stop leaking raw error
lib/features/groups/presentation/pages/create_group_wizard/step1_identity.dart  # same
lib/features/edits/widgets/global_edit_upload_bar.dart         # RTL
lib/features/groups/widgets/sticker_picker_sheet.dart          # RTL
lib/features/groups/widgets/wa_composer/wa_emoji_panel.dart    # RTL
lib/features/groups/widgets/chat_message_bubble.dart           # RTL
lib/features/groups/widgets/chat_message_actions_overlay.dart  # RTL
test/anime_hub_social_test.dart                                # realign fake to reportReview
test/anime_test_support.dart                                   # drop removed staff API
test/provider_chain_anime_repository_test.dart                 # drop removed staff API
docs/PRODUCTION_READINESS_AUDIT_2026.md                        # this report
```

---

## 7. Verification

- `dart analyze` on every changed file → **No issues found**.
- `flutter test` targeted suites →
  `guide_page_test`, `search_hit_test`, `search_provider_test`,
  `anime_hub_social_test`, `fan_work_screens_test`,
  `chat_message_actions_overlay_test`, `anime_screens_test`,
  `create_group_upload_search_test` → **All tests passed**.
- Golden tests are excluded from CI on Linux by design (`ci.yml`); not affected
  by these changes except the chat overlay scale origin, which is animated.

---

## 8. Remaining roadmap (prioritized)

1. **Localize `lib/features/groups`** (~103 literals). Highest impact on
   bilingual trust; core to the product. (High)
2. **Replace the draft legal copy** — `AppStrings.termsIntro` currently tells
   users "Final legal copy … will replace this text before public launch."
   (Blocker before public launch)
3. **Remove/unroute developer surfaces** — `design_system_showcase_page.dart`,
   `foundation_home_page.dart`, `placeholder_home_page.dart` (unreferenced).
   (Medium)
4. **Delete dead copy/metadata** — unused `EventTypeSpec.label/hint` English
   strings; `app_shell_drawer.dart` static labels superseded by `drawerLabel`.
   (Low)
5. **Localize remaining `semanticLabel`s** in economy/anime widgets. (Low)

---

## 9. Positives worth preserving

- Zero `TODO/FIXME/UnimplementedError` in production code.
- Centralized `Failure` taxonomy + mapper (single error-mapping chokepoint).
- Consistent design system (`core/widgets/*`, `AppSpacing`, `AppColors`).
- Direction-aware motion, retry/offline states, skeleton loaders, and
  typed repository results (`Result<T>`).
- CI gates for analyze, Flutter tests, Functions, and Firestore/Storage rules.
