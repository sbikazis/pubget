# Axis 15 — Kirari / Reels — Phase 0 Audit (BLOCKING)

> هذه الوثيقة هي **المرفق الأول** المطلوب لكل PR في محور 15.
> تُحدَّث مع كل خطوة، ولا تُحذف.
> لا تُعدَّل `docs/PUBGET_MASTER_SPEC.md` ولا `docs/PUBGET_OPERATING_PROMPT.md`.
> القاعدة: **Server هو الحقيقة**. لا fake، لا placeholder، لا زر ميت.

**Revision مُثبَّتة على:** `origin/main` = `52e5d0b` (Merge PR #129 `feature/17-fanworks-rebuild`)
**Branch العمل:** `feature/15-kirari-restructure`
**Worktree:** `/Users/sbikazis/Documents/Default Project/.worktrees/kirari-restructure`
**كل الأدلة في هذا التقرير مُتحقَّق منها على هذه الـrevision تحديداً.**

---

## 0. Baseline Gate (measured, not assumed)

| Gate | Command | Result |
|---|---|---|
| Static analysis | `dart analyze` (full package) | ✅ **No issues found!** (0) |
| Static analysis (slice) | `dart analyze lib/features/edits lib/features/reels` | ✅ No issues found! |
| Client tests (Reels slice) | `flutter test` × 7 files (edit_upload_manager, edits_feed_optimistic, edits_integration, edits_moderation_respect, edits_pipeline_hardening, edits_rebuild, global_edit_upload_bar) | ✅ **All 30 tests passed!** |
| Functions tests (Reels slice) | `node --test` × 5 files (editsDomain, ranking, recommendationEngine, editOutcomeNotifications, editPipelineAspect) | ✅ **27/27 pass** |

**النقطة الحاسمة:** البوابة خضراء تماماً بينما المنتج مكسور. هذا يثبت أن التغطية الحالية
تختبر *السلوك المكتوب* لا *المواصفة*. كل فجوة في هذا التقرير ستمرّ من تحت البوابة الحالية.

### Gate failures observed in this environment (not code defects)

- `flutter analyze` (full package) **فشل ثلاث مرات** إما بتجاوز 900s أو بـ
  `analysis server exited with code -15`.
  السبب: **جلسة/عملية Flutter أخرى تعمل بالتوازي على نفس الـ SDK**
  (`/Users/sbikazis/pubget` — مشروع *مختلف* عن هذا، يشغّل `flutter test` على مئات الملفات)
  ⇒ contends على `flutter` startup lock + ضغط CPU/ذاكرة.
- **الدليل:** `flutter --version` ردّ `Waiting for another flutter command to release the startup lock...`
- `dart analyze` العادي نجح بلا مشاكل ⇒ **المشكلة بيئية/تزامن، وليست خطأ كود.**
- **Mitigation المعتمد:** استخدم `dart analyze` بدل `flutter analyze` للبوابة السريعة،
  ولا تشغّل بوابة Flutter heavyweight بالتوازي مع جلسات أخرى على نفس الجهاز.

---

## 1. Repository / Branch reality

| Fact | Value |
|---|---|
| Repo root | `/Users/sbikazis/Documents/Default Project/pubget` |
| Local `main` | `11e1069` (2026-09-21) — **قديم / stale** |
| `origin/main` | `c4d8681` (2026-10-01) — PR #127 |
| Session HEAD | `5907fc5` on `fix/picker-initial-state-chat-optimism` |
| HEAD vs origin/main | HEAD **is ancestor of** `origin/main` ⇒ لا يوجد عمل محلي غير مدفوع |
| Working tree | نظيف، عدا untracked `.p02_worktree/` وهو **git worktree مسجَّل** (`codex/pubget-phase-02-...`) |
| Dart files | ~395 |

⚠️ `main` المحلية متأخرة 17 PR عن `origin/main`. أي عمل جديد **يجب** أن يُبنى من `origin/main` بعد `git fetch`، لا من `main` المحلية.

### 1.1 ⚠️ CRITICAL: there is already unmerged Kirari work on two orphaned branches

هذا هو الاكتشاف الأهم في التدقيق، وهو يغيّر خطة التنفيذ: **لا نكتب من الصفر**.

**A) `backup/session-15-kirari`** — commit `b3431f2` *"feat(kirari): Kirari edits/reels/audio system (Axis 15)"*, base `edc5b16` (PR #105). +1863 سطر، 24 ملف:

- `functions/src/audioDomain.js` (347) — ← **هذا الملف موجود فعلاً في شجرة العمل الحالية، ميّت غير موصول**
- `lib/features/reels/models/audio_models.dart` (94)
- `lib/features/reels/providers/audio_provider.dart` (107)
- `lib/features/reels/repositories/audio_repository.dart` (31)
- `lib/features/reels/repositories/firebase_audio_repository.dart` (185)
- `lib/features/reels/screens/audio_page.dart` (185)
- `lib/features/reels/screens/audio_picker_sheet.dart` (252)
- `lib/features/reels/widgets/reels_feed_switcher.dart` (71)
- تعديلات على ملفات edits القائمة: `edit_feed_page.dart` (+103)، `firebase_edits_repository.dart` (+96)، `edits_provider.dart` (+54)، `pubget_app.dart` (+11)، `pubget_links.dart` (+25)، `app_strings.dart` (+9)، `edit_copy.dart` (+9)

**B) `feature/15-kirari-core-system`** — commit `64183f4` *"Axis 15 - audio system, hashtag page, analytics page"*, base `edc5b16` (PR #105). +1832 سطر، 7 ملفات:

- `functions/src/audioDomain.js` (350)
- **`lib/features/edits/screens/analytics_page.dart` (433)** ← لم تصلنا فقط
- **`lib/features/edits/screens/hashtag_page.dart` (319)** ← لم تصلنا فقط
- `lib/features/reels/repositories/audio_repository.dart` (31)
- `lib/features/reels/repositories/firebase_audio_repository.dart` (217)
- `lib/features/reels/screens/audio_page.dart` (198)
- `lib/features/reels/screens/audio_picker_sheet.dart` (284)

**الحقائق المؤسفة:**
1. الفرعان **متباعدان** (core-system ليس ancestor للـ backup) ⇒ فيهما نسختان متعارضتان من audioDomain و audio_page/picker.
2. كلاهما基于 `edc5b16` = **PR #105**، أي متأخر ~22 PR عن `origin/main`.
3. `lib_legacy/` فارغ Kirby-wise؛ **الفرعين لم يلمسا `lib_legacy`** ⇒ لا تعارض مع قيد "لا تعديل lib_legacy".
4. **`analytics_page.dart` و `hashtag_page.dart` غير موجودتين في شجرة العمل الحالية إطلاقاً.**
5. `audioDomain.js` وصل إلى main/current **لكن نُسخ audio UI لم تصل** ⇒ splitter-brain_partial.

**القرار المطلوب من المالك:** أي فرع يُستخدم كمرجع (أو كلاهما يُعاد بناؤه من جديد على `origin/main`). الافتراضي المقترح: **إعادة بناء** لأن الـ22 PR فارق дела، والنسختين لم تُختبرا معيارياً. لكن يجب **قراءة** الـ1863 سطر قبل إعادة الكتابة حتى لا نعيد اختراع ما هو موجود.

## 1.1 Triage of the two orphaned Kirari branches — COMPILE-TESTED

قرار المالك: *«احتفظ بما يعمل جيداً، وأعد بناء ما لا يعمل، والنهاية نظام كامل جاهز للإنتاج»*.

**طريقة القرار: لم أحكم بالنظر — نقلت الكود إلى فرع العمل وشغّلت `dart analyze` عليه.**

النتيجة بعد النقل: `lib/features/reels` + `lib/features/edits` + `lib/core` ⇒ **`No issues found!`** (باستثناء lint واحد).

### 1.1.1 ✅ KEEP — العمل الجيد (مُثبَت بالـcompile test)

| Artifact | LOC | الدليل على أنه جيد |
|---|---|---|
`functions/src/audioDomain.js` *(موجود في main)* | 349 | 6 callables تطابق 1:1 واجهة العميل · `db.runTransaction` للذرّية · فحوص ownership/state/auth · lifecycle `extracting→ready/failed` + `failureReason` · `try/finally` لتنظيف `/tmp` · `audioUsageRef(audioId,reelId)` لمنع التكرار |
`lib/features/reels/models/audio_models.dart` | 94 | compile نظيف، متسق مع `Edit` models |
`lib/features/reels/providers/audio_provider.dart` | 107 | compile نظيف، يتبع `EditsProvider` pattern |
`lib/features/reels/repositories/audio_repository.dart` | 31 | واجهة نظيفة، تستخدم `result_lib.Result<T>` (convention المشروع) |
`lib/features/reels/repositories/firebase_audio_repository.dart` | 185 | ينفّذ الـ6 + `UnavailableAudioRepository` بتدهور صادق (نمط المشروع في `UnavailableEditsRepository`) |
`lib/features/reels/screens/audio_page.dart` | 185 | compile نظيف |
`lib/features/reels/screens/audio_picker_sheet.dart` | 252 | compile نظيف + **lint واحد يُصلَح**: `use_build_context_synchronously:41` |
`lib/features/reels/widgets/reels_feed_switcher.dart` | 71 | **هذا هو 15.16 (For You / Following / Trending) — واجهة كاملة موجودة!** يحتاج `FeedType` enum + `EditsProvider.feedType/setFeedType` (كلاهما 다 في الـglue المنقول) |
`lib/features/reels/screens/reels_feed_page.dart` | 131 | **ليس alias anymore** — صفحة حقيقية بـ5 فلاتر: `audioFilter` / `animeId` / `characterId` / `hashtag` / `creatorId` |
glue (12 ملف) | +~380 | `app_strings.dart`(+9 i18n) · `pubget_links.dart`(+25) · `pubget_inputs.dart`(+6 `maxLength`) · `edit_copy.dart`(+9) · `edit_models.dart`(+2) · `edits_provider.dart`(+54 = `FeedType`) · `edit_upload_manager.dart`(+14) · `edits_repository.dart`(+13) · `firebase_edits_repository.dart`(+96) · `unavailable_edits_repository.dart`(+13) · `edit_feed_page.dart`(+103) · `edit_upload_page.dart`(+42) |
routes hunk من `pubget_app.dart` | +8 | `/reels/anime` · `/reels/character` · `/reels/creator` · `/hashtag` — **جيد، لكن يجب إسقاط** تعديل غير متعلق (`create_group_wizard_page.dart` → `presentation/pages/…`) |

**الخلاصة: ~2000 سطر من العمل السابق صالح ويجب نقله، لا إعادة كتابته.**

### 1.1.2 ❌ REBUILD — عمل ميت لا يُترجم (على `feature/15-kirari-core-system`)

| Artifact | LOC | السبب |
|---|---|---|
`lib/features/edits/screens/analytics_page.dart` | 433 | **`AnalyticsRepository` غير موجودة في أي مكان بالمستودع** (`git grep` = 0 نتيجة). السطر 27 يصرّح بنوعها، 38-40 `as AnalyticsRepository`، 58 `getCreatorAnalytics()` ⇒ **لا يُترجم**. أيضاً غير مُسجَّل كـroute. (نفس الفئة التي حذفها PR #110 `fix(p00): unblock analyze gate - remove 6 dead uncompilable files`) |
`lib/features/edits/screens/hashtag_page.dart` | 319 | **`HashtagRepository` غير موجودة في أي مكان** ⇒ **لا يُترجم**، وغير مُسجَّل كـroute. ومُستبدلة وظيفياً بالـ`/hashtag` → `ReelsFeedPage` الموجود في §1.1.1 |

**ملاحظة للشفافية:**両 صفحة يقرّان في ترويستهما «no placeholder or fabricated metrics» — النية ممتازة، لكن **الـrepository الغائب يجعلها كوداً غير قابل للتنفيذ**. نأخذ التصميم كمرجع، ونعيد بناء الطبقة التي تقرأ من الخادم.

### 1.1.3 ⚠️ FIX (لا Rebuild) — `audioDomain.js` فيه عيوب حقيقية رغم بنائه الجيد

| العيب | الموقع | الأثر |
|---|---|---|
`db.collection("reels")` مكتوب 3 مرات hardcoded رغم وجود helper `reelRef(reelCollection)` | `audioDomain.js:246, 267, 277` | النظام الحي على `edits` ⇒ **ميّت حسب البناء** |
`FieldValue.increment(1)` على كل نداء `useAudio` | `audioDomain.js:255` | **غير idempotent** ⇒ نفس الـreel يُعدّ مرتين. يخالف برمجة المالك |
تنزيل+ffmpeg **inline داخل الـcallable** | `audioDomain.js:117-137` | 60s callable timeout افتراضي ⇒ overrun على فيديو 100MB |
يُرجع `{status:"ready"}` حتى عند فشل الاستخراج | `audioDomain.js:148` | **الخادم يكذب** ⇒ يخالف «Server هو الحقيقة» |
تنزيل الفيديو كاملاً إلى `/tmp` | `audioDomain.js:126` | نفس blocker السقف 512MB (§5.5.1) |
**لا `storage.rules` لـ`reelAudios`** | `storage.rules` | Storage deny-by-default ⇒ **رفع الصوت مرفوض** |
**لا `firestore.rules` لـ`reelAudios`** | `firestore.rules` | قراءة/كتابة الصوت مرفوضة |
**لا index لـ`reelAudios`** | `firestore.indexes.json` | `listAudios`/`searchAudios` سيفشل runtime |
**لا DI wiring** | `pubget_app.dart` (backup) | `grep -i audio` = 0 ⇒ الواجهة والـUI غير مُسجَّلين في أي Provider |

### 1.1.4 ❌ ناقص تماماً في الفرعين (يجب بناؤه من الصفر)

`/reels` و`/reels/upload` routes (الزر الميت + رابط المشاركة) · `/reel/{id}` deep link + OG preview ·
callables الصوت في `functions/index.js` · `reelAudios` rules + indexes · ضمّ ملفات Kirari في
`functions/package.json` scripts (CI coverage) · guest read rules · adaptive rendition ladder.

---


## 2. Map of current Kirari code (Phase 0a)

### 2.1 Collections / Functions / Rules — current wiring

| Surface | Wired? | Location |
|---|---|---|
| Live Firestore collection | ✅ `edits` | `functions/src/editsDomain.js` |
| Live callables | ✅ `startEditUpload`, `getEditFeed`, `getEdit`, `watchEdit`, `finalizeUpload`, `retryProcessing`, `startPlayback`, `sendView`, `setLike`, `addComment`, `listComments`, `setSave`, `setSignal`, `giveRespect`, `reportEdit`, … | `functions/index.js:323-375` |
| `reels` collection (rules) | ⚠️ مكتوب في `storage.rules` + `firestore.indexes.json` فقط | **لا callable ولا client** |
| `FirebaseReelsRepository` | ❌ موجود في `lib/features/reels/repositories/reels_repository.dart` | غير مُسجَّل في DI |
| `functions/src/reelsDomain.js` (347→ adapter) | ❌ **ميّت** — `createEditsDomain` adapter يحوّل `reelId↔editId` | لا `require` في `index.js` |
| `functions/src/reelsConfig.js` | ❌ **ميّت** | لا `require` |
| `functions/src/audioDomain.js` (349) | ❌ **ميّت** | لا `require` في `index.js` |
| `firestore.rules` `/edits` | ✅ | `firestore.rules:1012-1035` |
| `firestore.rules` `/reels` | ❌ **لا وجود له** | — |
| `storage.rules` `/edits`, `/edits-processed` | ✅ | `storage.rules:289-317` |
| `storage.rules` `/reels`, `/reels-processed` | ⚠️ مكتوب لكن لا client's path | `storage.rules:318-338` |
| `firestore.indexes.json` edits | ✅ 4 indexes | — |
| `firestore.indexes.json` reels | ⚠️ 3 indexes لـ collection **غير مستخدم** | — |

### 2.2 Client DI / routing reality

| Fact | Evidence |
|---|---|
| `lib/app/pubget_app.dart` يسجّل `FirebaseEditsRepository` + `EditsProvider` + `EditUploadManager` | — |
| `lib/features/reels/` = 4 wrappers فقط: `reels_brand.dart`, `repositories/reels_repository.dart`, `screens/reels_feed_page.dart`, `screens/reels_upload_page.dart` | 4858 LOC، منها ~20 في reels |
| التنفيذ الحقيقي في `lib/features/edits/` | — |
| `AppShellTabX.path` → `/edits`؛ `canonicalPath` → `/reels` | `app_shell_tab.dart:9-23` |
| `AppShellTab.edits` label = `'Reels'` **hardcoded English** | `app_shell_tab.dart:35` |

### 2.3 🚨 ROOT CAUSE #1 — `/reels` routes غير مسجَّلة ⇒ أزرار ميتة فعلية

`domainPages` في `lib/app/pubget_app.dart:937+` فيه 62 route. **المسارات التالية غير موجودة:**

```
/reels            -> *** MISSING ***
/reels/upload     -> *** MISSING ***
/audio            -> *** MISSING ***
/hashtag          -> *** MISSING ***
/reel             -> *** MISSING ***
/edits            -> ok
/edits/upload     -> ok
```

و `AppRouterDelegate.build` (`lib/app/app_router.dart:199-214`) يسقط إلى
`_ => domainPages['/unknown'] ?? homePage` ⇒ **كل هذه المسارات تُعرض `UnknownLinkPage`.**

**المسارات المكسورة المؤكدة (бот dead buttons):**

| # | Entry point | Evidence | UX_symptom |
|---|---|---|---|
| 1 | **زر "إنشاء ريل"** في create-sheet | `lib/app/app_shell_create_sheet.dart:40` → `AppNavigation.go(host, '/reels/upload')` | يذهب لـ UnknownLinkPage ⇒ **لا يمكن إنشاء ريل إطلاقاً من Create menu** |
| 2 | **Share link** | `edit_feed_page.dart:870` → `PubgetLinks.canonical(ReelsBrand.route)` = `/reels` | كل ريلوشنر يُرسل رابط بلا reel id ⇒ المستلم يرى Unknown |
| 3 | **بطاقة ريل في صفحة الأنمي** | `anime_details_page.dart:967` → `PubgetLinks.reelHighlightPath(edit.id)` = `/reels?highlight=…` | UnknownLinkPage |
| 4 | زر "الرجوع للريل" بعد النشر | `edit_upload_page.dart` `copy.openEdit` → `ReelsBrand.route` = `/reels` | UnknownLinkPage |
| 5 | highlight deep-link من `anime_character_page.dart:621` | → `'/edits'` (.Feed العام، يفقد الـreel) | يفتح feed عشوائي بدل الـreel |

> **هذا هو جذر شكوى "UX سيئ جداً / الملفات غير موجودة / لا شيء يعمل".**
> كل entrances إلى Reels عبر `/reels*` محطّمة، بينما الكود الحقيقي كله على `/edits*`.

### 2.4 Integration surface ( linkages that DO exist today)

| Axis | Location | State |
|---|---|---|
| 02 sharing | `groups/screens/group_chat_page.dart`, `chat_action_sheets.dart`, `chat_message_actions_overlay.dart`, `private_chat/screens/private_chat_screen.dart` | ✅ يستعمل `Edit` models |
| 06 home | `home/screens/home_page.dart`, `home_luxury_tiles.dart`, `firebase_home_repository.dart` | ✅ |
| 09 groups | same as above | ✅ |
| 16 anime | `anime_details_page.dart:107 getAnimeEdits`, `anime_character_page.dart:66 getCharacterEdits` | ✅，但其 التنقل مكسور (§2.3) |
| 18 profile | `social/screens/profile_page.dart:1064 getCreatorEdits` + `_EditsGrid` | ✅ |
| 19 notifications | `notifications/screens/notification_inbox_page.dart` | ⚠️ يعرض Edit |
| 05 discovery | `functions/src/recommendationEngine.js:161` يحمّل `edits` ب池 40 ويسمّيها `edit` | ✅ موجود لكنه **ليس** For You حقيقي |

---

## 3. Status matrix 15.1 → 15.20

الحالة: ✅ مكتمل | ⚠️ جزئي | ❌ ناقص | 🚨 مكسور

| # | البند | الحالة | الدليل المحدد | Root cause | القرار / الإصلاح | المخاطرة |
|---|---|---|---|---|---|---|
| **15.1** | هوية "ريلز"/"كيراري" | 🚨 | `AppStrings.productReelsName` **غير موجود**؛ بدلها `ReelsBrand.name` + `EditCopy.feedTitle` literals. `AppShellTab.label='Reels'` | مصدران+متعدد للنص | إضافة `productReelsName` واحد في `app_strings.dart`، وحذف `ReelsBrand` والduplicate literals |的低: لمس AppStrings فقط |
| **15.2** | مدة/حجم الفيديو | 🚨 | `Limits`+`editsConfig` = **180s / 100MB**؛ `reelsConfig.js:9-17` = 60s (ميّت)؛ المواصفة 3–60s / ≤500MB | 3 مصادرحدود متعارضة؛ لا min 3s | مصدر حدود واحد server-side،	server يتحقق (لا client-only) | تحديث `storage.rules` حد 500MB + server guard + tests |
| **15.3** | بيانات وصفية | ⚠️ | `edit_upload_page` caption + free-text anime فقط؛ لا editor (قص/سرعة/صوت/فلاتر/غلاف) | نموذج `Edit` لا يصفّر pipeline input | توسيع `EditDraft` + metadata | متوسط |
| **15.4** | نظام الصوت | ❌ | `functions/src/audioDomain.js` (349 سطر) **ميّت**؛ لا UI؛ `audio_page.dart`/`audio_picker_sheet.dart` غير موجودتين في الشجرة الحالية | نُقل audioDomain بدون wiring/UI | **إعادة بناء** من `feature/15-kirari-core-system` أو backup، **مع** callable wiring + routes `/audio` | متوسط: يجب حل تعارض النسختين |
| **15.5** | الرفع resumable | ⚠️ | `edit_storage_put_io/web.dart`؛ storage.rules يسمح `update` (protocol resumable) لكن **لا resumable token/state على العميل**، ولا retry-from-offset | عميل بلا resume | `uploadSession` doc + resumable upload API | متوسط-high (Blaze/tenant) |
| **15.6** | المعالجة | 🚨 | `editPipeline.js` ffmpeg-static (موجود، 78,862,176 B، mode 755) ⇒ rendition **واحدة** 1080×1920 CRF25. **لا 360/540/720، لا HLS/adaptive** | لا variant ladder | `MediaService` provider-agnostic + ladder | **BLOCKED محتمل**: تحقّق ffmpeg-static في Cloud Functions production |
| **15.7** | الغلاف (thumbnail) | ⚠️ | `coverFrameMs` يُخزَّن ولا يُستخدم؛ غلاف frame ثابت | pipeline لا يولّد cover من البيانات | توليد cover من أول 3s/اختيار المستخدم | منخفض |
| **15.8** | التوصيات | 🚨 | `ranking.js scoreEdit` = freshness+popularity؛ `creatorQuality` غير موجود (يفضّل 0)؛ `seenIds` **فارغ دائماً**؛ anime تطابق free-text↔IDs ⇒ ≈0 | لا `user_reel_state`/weights ولا seen-ring مكتوب | personalization state + weights + exploration/diversity | متوسط |
| **15.9** | التصفّح (viewer) | 🚨 | `_trackProgress` (edit_feed_page.dart:424-437) `setState` **كل frame**؛ `context.watch<EditsProvider>` (line 159) يعيد بناء الـfeed كل action؛ `prefetchCount=1`؛ `createStorageVideoController` **await `getDownloadURL()` قبل إنشاء الـcontroller** | بناء setState بدل ValueNotifier؛ لا pool | `ValueListenableBuilder` + per-item notifier؛ pool/LRU؛ prefetch bandwidth-aware | **عالية**: توثيق внеш — `video_player` لا يسمح بإعادة تعيين source ⇒ pooling يحتاج package/حلقة جديدة (**موافقة المالك**) |
| **15.10** | التفاعلات | ⚠️ | likes/comments server؛ **الحفظ لا retrievable** (لا `users/{uid}/saved_reels`)؛ لا block/mute/not-interested | لا state model | `ReelUserState` + saved_reels | متوسط |
| **15.11** | التعليقات | ⚠️ | `edit_comments_sheet.dart`؛ ينقص mentions search، pin/creator indicator، block/mute، reply UX، pagination correctness، optimistic like | ناقص | إكمال + i18n | منخفض |
| **15.12** | economy | 🚨 | publish مكافأة ثابتة، **بلا quota**، rewards قابلة للّعب (click farming)؛ لا idempotency semantics | لا rate limit/ledger | `economyTransactions` idempotency + daily quota | متوسط |
| **15.13** | moderation | ⚠️ | `editPipeline` moderation watermark heuristic؛ **بلا needs_review approval path**؛ report → signal `negative` بدل `reel_reports` مصنّفة | لا moderation queue | `reel_reports` + admin queue | متوسط |
| **15.14** | الإحصائيات (creator analytics) | ❌ | `analytics_page.dart` (433 سطر) موجود على `feature/15-kirari-core-system` فقط، **غير موجود بالشجرة الحالية** | نُقل ولم يُدمج | Port + توصيل `/creators/{id}/analytics` | منخفض |
| **15.15** | hashtag | ❌ | `hashtag_page.dart` (319) على core-system فقط؛ لا collection `hashtags` في rules | نُقل ولم يُدمج | `hashtags` + `/hashtag/{tag}` | منخفض |
| **15.16** | feeds (For You/Following/Trending) | ❌ | **لا For You حقيقي، لا Following، لا TrendingVelocity**؛ `reelsFeed` لا switcher في الشجرة الحالية | feed واحد فقط | 3 استراتيجيات + switcher (مقترح: `reels_feed_switcher.dart` من backup) | متوسط |
| **15.17** | guest viewing | 🚨 | `startPlayback` callable يتطلب auth؛ `firestore.rules:1012` `allow read: if signedIn()`؛ `storage.rules` `/reels/{userId}` read `if signedIn()` |两道 signup gate | public read للـpublished reels (rate-limited) + anonymous view attribution | متوسط-privacy |
| **15.18** | deep links `/reel/{id}` | ❌ | لا route `/reel/{id}` في `domainPages`؛ hosting rewrites فيها `/group/**`,`/g/**`,`**` فقط؛ **لا rich preview OG** | لم يُبنَ | parameterized route + OG meta | منخفض |
| **15.19** | i18n عربي كامل | ⚠️ | `AppStrings.pick(en,ar)` = inline literals (لا .arb)؛ `EditCopy.failureFor` يقول **3 دقائق** بينما validator يقول 60s؛ تعارض 100MB/500MB؛ 4 hardcoded UI strings في widgets | نصوص متكررة ومتناقضة | تصحيح النصوص + مصدر واحد | منخفض |
| **15.20** | performance/zero-wait | 🚨 | §15.9. **توصيات خارجية**: prefetching Escalate = prefetch chunk **الأول فقط** من الـK التالية؛ fast swipes تهدر **>40%** من bandwidth؛ hardware decoder slots محدودة (5–16) والعثور عليها **crashes صامت** على أندرويد؛ iOS AVPlayer لا يدعم WebM/VP9 ⇒ ladder يجب أن يحوي H.264 baseline | تصميم setState + controller--per-cell | per-item notifiers + activeWindow صغير + ladder متعدد | **عالية**: player pooling يحتاج قرار معماري |

---

## 4. Root-cause matrix (symptom ← cause ← fix ← risk)

| # | Symptom (what the owner sees) | Root cause | File / line | Proposed fix | Risk |
|---|---|---|---|---|---|
| 1 | "لا أستطيع إنشاء ريل" / UnknownLinkPage | routes `/reels*` غير مسجَّلة | `pubget_app.dart:937` | تسجيل routes أو redirect إلى `/edits*` مؤقتاً | منخفض |
| 2 | "الريلوشنر ما يشتغل" | share URL = `/reels` بلا id | `edit_feed_page.dart:870` | share `/reel/{id}` | منخفض |
| 3 | "بطاقات الأنمي تفتح صفحة غلط" | `/reels?highlight=` ميّت؛ character page تذهب `/edits` | `anime_details_page.dart:967`, `anime_character_page.dart:621` | Deep link route | منخفض |
| 4 | "الضيف ما يقدر يشوف" | signedIn两道 | `firestore.rules:1012`, `storage.rules:318`, callable auth | public read + anon view | privacy |
| 5 | "ما أقدر أنشر 5 دقائق" | 100MB حد | `storage.rules:323`, `editsConfig` | 500MB | تكلفة bandwidth |
| 6 | "التطبيق يقطع/يحدث عند التمرير" | setState كل frame + rebuild واسع | `edit_feed_page.dart:159,437` | ValueListenableBuilder | **عالية** |
| 7 | "التطبيق يطير على أجهزة ضعيفة" | controller per cell، decoder slots | `edit_feed_page.dart:365`, `storage_video_controller_io.dart` | pool/LRU + activeWindow | **عالية** |
| 8 | "نفس الفيديو يُشارك بلا فايدة" | rendition واحدة | `editPipeline.js` | ladder + HLS | **BLOCKED محتمل** |
| 9 | "مافيش اقتراحات شخصية" | لا user state | `ranking.js`, `recommendationEngine.js` | personalization | متوسط |
| 10 | "الحفظ ما يظهرش" | لا saved_reels | `editsDomain.js` | collection + query | منخفض |
| 11 | "الصوت والحاشيحة غير موجودين" | audioDomain ميّت، hashtag page غير موجودة | `functions/src/audioDomain.js` | **إعادة بناء** من فرع أو من الصفر | متوسط |
| 12 | "الصوت غير موجود بالـCI" | `package.json` test/check **لا تغطي** audioDomain/reelsDomain/reelsConfig/editOutcomeNotifications/editPipelineAspect | `functions/package.json` | إضافة للـscripts | منخفض (**مهم**) |

---

## 5. Research references (external, non-imitative)

المراجعTeleportation مستخدمة لتصميم الـarchitecture، **لا لتقليد** أي منتج:

1. **Prefetching for Short Video Streaming (SIGCOMM 2026)** — لـprefetching logic + viewing-time estimation؛ production A/B على مئات الملايين: +0.38% stay time، −14.7% bandwidth.
2. **Wisely Optimizing Short Video Streaming (ACM MM '22, Douyin/Kuaishou measurements)** — المنصات **prefetch أول chunk فقط** من الـvideos التالية؛ fast swipes تهدر **>40%** من تكلفة bandwidth. ⇒ لا prefetch عدواني.
3. **Bandwidth-Efficient Multi-video Prefetching (ACM MM '22)** — multi-buffer per video؛ tradeoff startup-delay vs wastage vs rebuffer.
4. **QoE-Aware Short Video Preload Framework (Springer MNW 2026)** — bandwidth prediction + buffer threshold + early-departure modeling.
5. **Flutter cookbook — play-video** — `video_player` lifecycle: create in `initState`, `initialize()`, `dispose()`; ExoPlayer (Android) / AVPlayer (iOS).
6. **Flutter video feed controller pooling** — `video_player` **يربط الـcontroller بـURL واحد** ⇒ create/dispose كل swipe = bottleneck/crash؛ الحل pool ثابت + LRU keyed by URL + per-item `ValueNotifier`/`ValueListenableBuilder`؛ `activeWindow` صغير (3–4 streams).
7. **Media3 `PreloadManager` (Android)** — re-USE `ExoPlayer` عبر `setDataSource` + `setCurrentPlayingIndex`؛ priority حسب القرب.
8. **Very Good Ventures — video feed at scale** — decoder slots محدودة (5–16) والعثور عليها **crashes صامت** على أندرويدBudget؛ iOS AVPlayer لا WebM/VP9 ⇒ ladder H.264/HEVC مطلوب.

**الخلاصة المعمارية:** مع `video_player` لا يمكن pool الـplayers. إمّا نقبل create/dispose مع discipline صارمة،
أو نضيف package/platform-channel يدعم إعادة تعيين source. **هذا قرار يحتاج موافقة المالك قبل كتابته.**

---

## 5.5 Environment verification (measured against live project `pubget-aaf27`)

بأمر المالك: «تحقق من البيئة أولاً». هذه نتائج الفحص الفعلي، لا تقدير.

| Check | Method | Result |
|---|---|---|
| Firebase CLI + auth | `firebase login:list` | ✅ `zakariasbika253@gmail.com` |
| Project | `firebase projects:list` | ✅ `pubget-aaf27` (project #452313838148) |
| **Billing plan** | `firebase functions:list` | ✅ **Blaze مُفعَّل.** الدليل الحاسم: `processEditVideo` منشور بـ **1024 MB** ذاكرة — أي قيمة فوق الـ256MB الافتراضية **غير مسموحة على Spark**. ⇒ لا blocker فوترة. |
| Deploy size limit | zip قياس فعلي | ✅ **396 KB** مضغوطاً (396K بدون `node_modules` لأن `firebase.json` يتجاهله)، و**39 MB** لو ضمّينا `node_modules`. الحد 250MB ⇒ **غير blocker**. |
| ffmpeg-static على القرص | `ls -la node_modules/ffmpeg-static/ffmpeg` | ✅ `78,862,176` B، mode `755` |
| كيف يصل ffmpeg للسيرفر | `firebase.json` `functions.ignore` = `["node_modules", ...]` | ⚠️ الـbinary **لا يُرفع**؛ يُنزَّل على Google's build env عبر `npm ci` → postinstall من **GitHub releases**. ⇒ يعتمد على إمكان reachability لـGitHub من بيئة بناء Google — **لا يمكن التحقق منه offline.** |
| Functions topology | `firebase functions:list` | ⚠️ **ثلاث مناطق مختلفة:**<br>• callables → `us-central1` (256 MB)<br>• `processEditVideo`, `processGroupChatMedia` → **`europe-west3`** (1024 MB)<br>• 14× Firestore triggers → **`europe-west1`** (256 MB) |
| Client region pin | `lib/app/pubget_app.dart:222-768` | ✅ كل الـFunctions instanceFor = `us-central1` ⇒ يطابق callables، **لا يطابق** `europe-west3`. |
| Pipeline ephemeral usage | `functions/src/editPipeline.js:337-342` | 🚨 `mkdtemp(os.tmpdir())` ثم **`bucket.file(...).download({destination: source})`** ⇒ ينزّل الفيديو **بالكامل** إلى `/tmp` |
| **Cloud Functions gen2 `/tmp`** | حد الثقة الرسمي | 🚨 **512 MB** |
| Production transcode logs | `firebase functions:log` | ⚠️ `"No log entries found"` — الأمر **لا يدعم gen2** ⇒ يتعذّر إثبات أن ffmpeg اشتغل فعلياً في production. |

### 5.5.1 🚨 BLOCKED #1 — سقف `/tmp` (512MB) يتعارض مع حد 500MB في المواصفة

```
lib/../functions/src/editPipeline.js
  337:  const dir = await fsp.mkdtemp(path.join(os.tmpdir(), "pubget-edit-"));
  338:  const source    = path.join(dir, "source.mp4");
  339:  const thumbnail = path.join(dir, "thumbnail.jpg");
  340:  const processed = path.join(dir, "processed.mp4");
  342:  await bucket.file(object.name).download({ destination: source });
```

عند رفع 500 MB (الحد الذي تفرضه المواصفة):

| البند | الحجم |
|---|---|
| `source.mp4` | ~500 MB |
| `processed.mp4` 1080×1920 | ~20–60 MB |
| `thumbnail.jpg` | ~0.2 MB |
| watermark frames (`wm_frame`, `wm_br`, `wm_bl`, `edge_*`) | ~1 MB |
| ffmpeg working files | متغيّر، عادة 10–50% من المصدر |
| **المجموع** | **يتجاوز 512MB ⇒ فشل شبه مضمون (ENOSPC / OOM)** |

الحد الحيّ الحالي 100MB (`storage.rules:288,323`) ⇒ يعمل اليوم بالمصادفة.
**رفع الحد إلى 500MB كما تطلب المواصفة يكسر الـpipeline عند الطرف الأعلى من المدى.**

**الحلول الممكنة (قرار للمالك):**
1. **نقل الـtranscoding إلى Cloud Run** — قرص ephemeral حتى 30GB أو working dir على GCS ⇒ الحل الوحيد الذي يحقق 500MB بشكل صحيح.
2. **Stream من Storage بدل التنزيل** — `createReadStream` كـstdin لـffmpeg، أو تمرير رابط `getDownloadURL` مباشرة لـffmpeg (`-i https://…`). يوفّر مساحة لكن ي fragile مع mp4 (moov atom) ولا ينفع على مصادر تحتاج seek.
3. **تخفيض حد المواصفة** إلى ما يتسع في 512MB (مثلاً 150MB) — يخالف نص المواصفة ⇒ يحتاج موافقة صريحة.
4. **Transcoder API** — لا ينقل الفيديو داخلياً (يبثّ من GCS) ⇒ يتجاوز حد `/tmp`، لكنه يحتاج تكلفة/Blaze-quota.

### 5.5.2 ⚠️ BLOCKED #2 — لا يمكن إثبات أن ffmpeg اشتغل في production

- `firebase functions:log` لا يدعم gen2 ⇒ لا سجلات.
- `ffmpeg-static` لا يُرفع مع الكود (يُتجاهل في `firebase.json`) ⇒ يُنزَّل من GitHub أثناء بناء Google.
- ⇒ **لا يوجد دليل ميداني** بأن الـpipeline أنتجت rendition واحدة في production.

### 5.5.3 ⚠️ Region sprawl (٣ مناطق)

`us-central1` (client + callables) · `europe-west3` (معالجة الفيديو) · `europe-west1` (Firestore triggers).
السماح عبر المناطق يعمل، لكن كل كتابة على Firestore أصلها من `europe-west3` بينما المستخدم في `us-central1` = round-trips إضافية + تكلفة + تعقيد تشخيص.
يُنصح بتوحيد منطقة الـmedia pipeline مع `us-central1` (أو كل شيء على `europe-west1`) في PR لاحق — **ليس في foundation** لأنه تغيير بنية تحتية.

---

## 6. Explicit risks / BLOCKED candidates (أُبلّغ ولا أُخفي)

| Risk | Status | Detail |
|---|---|---|
| **Cloud Functions gen2 `/tmp` = 512MB** | 🚨 **BLOCKED مؤكد** | `editPipeline.js:342` ينزّل الفيديو كاملاً إلى `/tmp`. حد المواصفة 500MB > 512MB ⇒ فشل عند الطرف الأعلى. الحل: Cloud Run (§5.5.1). |
| ffmpeg-static في production | 🚨 **BLOCKED مؤكد (إثبات)** | `firebase functions:log` لا يدعم gen2 ⇒ لا سجلات. والـbinary يُنزَّل من GitHub وقت البناء ⇒ لا دليل ميداعي. |
| **Billing / Blaze** | ✅ **NOT blocked** | مُفعَّل (دليل: `processEditVideo` بـ 1024MB). |
| **Deploy size** | ✅ **NOT blocked** | 396KB مضغوطاً (الحد 250MB). |
| Adaptive bitrate / rendition ladder | ⚠️ قرار معماري | MediaService provider-agnostic أولاً، ثم ladder. يعتمد على قرار §5.5.1. |
| Resumable upload > 100MB | ⚠️ | يحتاج تأكيد Firebase Storage resumable + pricing على Blaze. |
| Player pooling | ✅ **موافق عليه من المالك** | package جديد يدعم source reassignment (اقتراح: `media_kit`/libmpv أو ExoPlayer PreloadManager). يجب توثيقه كـdependency جديدة في PR. |
| CI coverage gap | �️ مؤكد | `functions/package.json` scripts لا تغطي 5 ملفات Kirari. |
| Concurrent Flutter sessions | ⚠️ بيئي | جلسة أخرى على `/Users/sbikazis/pubget` تحتجز SDK lock ⇒ `flutter analyze` غير مستقر. استخدم `dart analyze`. |
| `local main` stale | ✅ حُلّ | `main`=PR#110، `origin/main`=`52e5d0b` (PR#129). الفرع مبني على `origin/main`. |
| Region sprawl (٣ مناطق) | ⚠️ | لا يعطّل، لكن يُعالَج في PR بنية تحتية لاحق. |

---

## 7. Proposed execution plan (respecting split sequence)

الفرع: `feature/15-kirari-restructure` من `origin/main` بعد `git fetch`.

| PR | المحتوى | Size |
|---|---|---|
| `15-kirari-foundation` | `AppStrings.productReelsName`، تسجيل/توحيد routes (`/reels`,`/reel/{id}`,`/audio`,`/hashtag`)، تصحيح النصوص المتعارضة، حدود 3–60s/≤500MB، rules registration لـ`reels`، **CI يغطي كل ملفات Kirari**، shared models/state machine | متوسط |
| `15-kirari-upload-pipeline` | `MediaService` (rendition ladder + provider-agnostic)، resumable upload، cover generation، state machine، quota/idempotency | كبير |
| `15-kirari-viewer-interactions` | guest read، per-item notifiers، activeWindow/pool، التفاعلات + saved_reels + block/mute، comments full | كبير |
| `15-kirari-feeds-reco` | For You / Following / TrendingVelocity، `user_reel_state` + weights + seen-ring، switcher | كبير |
| `15-kirari-audio-hashtags` | إعادة بناء audioDomain + audio page/picker، hashtags collection + pages | متوسط |
| `15-kirari-analytics-moderation` | creator analytics page، moderation queue + `reel_reports`، economy quota/ledger | متوسط |

**شرط قبل PR #1:** موافقة المالك على (a) أي package جديد للـplayer pooling، (b) خطة الـrenditions (ffmpeg vs Transcoder)، (c) أي فرع من الفرعينorphan كمصدر.

---

---

## 8. Defects found during Foundation build — found, fixed, tested

This section is the honest record of what Phase 0 turned up once the code was
actually exercised. Each defect was reproduced with a test, fixed, and the test
kept. "Server is the truth" means none of these were papered over client-side.

| # | Defect | Where | Fix | Test that pins it |
|---|---|---|---|---|
| D1 | Server accepted any `durationMs`; the `3–60s` bound existed only in the client | `functions/src/editPipeline.js` | exported `classifyDuration` / `durationFailureReason`; server now rejects out-of-range before processing | `functions/test/editPipelineAspect.test.js` |
| D2 | Nested `Scaffold`: the audio detail page hosted the feed, which rendered its own Scaffold + AppBar ⇒ doubled chrome | `edit_feed_page.dart`, `reels_feed_page.dart`, `audio_page.dart` | explicit `embedded` flag; host owns chrome, feed returns the bare body | `test/reels_feed_embed_test.dart` (6) |
| D3 | `EditFeedPage._readRouteHighlight` called `Router.of`, which **throws** outside a Router — the `is! AppRouterDelegate` guard was unreachable, so embedding crashed | `edit_feed_page.dart:115` | `Router.maybeOf(context)?.routerDelegate` | `test/reels_feed_embed_test.dart` |
| D4 | `startUpload` accepted any `audioId` string with no existence/readiness check ⇒ dangling audio references | `functions/src/editsDomain.js` | validates the doc exists and `status === "ready"` before accepting the id | `functions/test/editsDomain.test.js` (3 new) |
| D5 | Client never sent `audioId` at all — the field existed only on `getFeed` | `edits_repository.dart` + implementations, `edit_upload_manager.dart`, `edit_upload_page.dart` | `audioId` flows picker → job → draft persistence → `startEditUpload` payload; offline shows a notice, not a dead picker | `test/edit_upload_manager_test.dart` |
| D6 | `scoreReelTrending` saturated on high counts (divide-after-compress) and returned non-zero for engagement-less Reels | `functions/src/ranking.js` | divide by age before compression; zero when there is no engagement; negative feedback penalizes | `functions/test/ranking.test.js` (14) |
| D7 | Feed scope was applied *after* a global `top 200` fetch ⇒ Followings and scopes starved | `functions/src/editsDomain.js` | scope pushed into the Firestore query; following chunked `in` queries of 30; trending = newest slice then velocity | `functions/test/editsDomain.test.js` (12) |
| D8 | Rules guarded `/usage/{reelId}` while the code writes `/reelAudioUsage/{reelId}` | `firestore.rules` | corrected path | `functions/test/firestore.rules.test.js` (4, **passing**) |
| D9 | `getAudio` / `searchAudios` did not require auth and reached into Reels without a bound collection | `functions/src/audioDomain.js` | auth guard + injected reel collection | `functions/test/audioDomain.test.js` (9) |

### Verification snapshot (this revision)

| Gate | Command | Result |
|---|---|---|
| Functions tests | `npm --prefix functions test` | ✅ **451/451 pass** |
| Functions static | `npm --prefix functions run check` | ✅ exit 0 |
| Firestore rules | `firebase emulators:exec --only firestore,storage …` (JDK 21) | ⚠️ **75 / 65 pass / 0 fail / 10 skipped** — Axis 15 audio rules pass; 9 storage tests skipped on a verified emulator capability probe (see blocker below) |
| Client static | `dart analyze lib` + `dart analyze test` | ✅ No issues found |
| Client tests | `flutter test` (full) | ✅ **823/823 pass** |
| Android build | `flutter build apk --debug` | ✅ exit 0 |

### Still BLOCKED (not a code defect)

- **Rules emulator**: resolved. `firebase-tools` needed **JDK 21+**; a portable
  Temurin **21.0.12.1** was used via `JAVA_HOME` scoped to the emulator command only
  (no system-wide install). The gate now actually executes.
- **Storage rules cross-service limitation (9 tests skipped, not passed).** The
  gate's first-ever real run was **74 tests / 65 pass / 9 fail**, all 9 in
  `storage.rules.test.js` (avatars, group media, private chat, character images,
  fan work, profile covers) — none Axis 15.

  **Root cause, measured — not a rules defect.** Those rules are guarded by
  `firestore.get()` / `firestore.exists()` (`isGroupOwner`, `isGroupMember`,
  `isPrivateParticipant`, `publicProfileAvatar`, and the Fan Work visibility
  gate). The **Storage emulator cannot evaluate cross-service Firestore reads**:

  | Probe (Storage rule) | Result |
  |---|---|
  | `allow create: if true` (control, no Firestore) | ✅ allowed |
  | `allow create: if firestore.exists(/…/groups/group-owner)` | ❌ denied |
  | `allow create: if firestore.get(/…/groups/…).data.founderId == uid` | ❌ denied |
  | `allow create: if firestore.exists(/…/users/public-user)` | ❌ denied |

  A direct Firestore probe shows the *Firestore* side is fine (an authenticated
  user may `get`/`list` `groups` and `groups/{id}/members`, and is correctly denied
  `users/{other}`), so the denial is isolated to Storage→Firestore evaluation.
  Reproduced identically with inline rules, with `firebase.json`-loaded rules, and
  on both `firebase-tools` 15.30.1 and 15.32.1 ⇒ not a version bug.

  **The rules were deliberately NOT weakened to make these pass.** That would be a
  fake-green: the Flutter client genuinely writes the guarded paths
  (`groups/$groupId/media/…_original.$ext` in `firebase_chat_repository.dart:227`,
  `privateChats/$chatId/media/…_original.$ext` in
  `firebase_private_chat_repository.dart:286`), and dropping the Firestore checks
  would let any signed-in user overwrite another member's media and let any
  authenticated user read a private avatar.

  Instead the 9 tests are gated on a **runtime probe** (`crossServiceWorks`) that
  attempts a *permitted* cross-service write and records the capability. They skip
  with an explicit reason when the emulator cannot evaluate, and **run
  automatically** on any runtime that can. A dedicated capability test logs
  `SUPPORTED` / `NOT SUPPORTED`, so the skips are self-explaining and lift by
  themselves if the emulator gains support. Net: **these 9 security assertions
  remain unverified locally and are reported as such — they are not "passed".**
- **`/tmp` 512MB vs spec 500MB** (see §5.5.1) — deferred to `15-kirari-upload-pipeline`.

---

*Phase 0 audit complete. Foundation fixes D1–D9 landed on `feature/15-kirari-restructure`.
Next: open PR `15-kirari-foundation`. The 9 skipped storage-rules assertions stay
reported as unverified until they run on a runtime with working cross-service
evaluation.*
