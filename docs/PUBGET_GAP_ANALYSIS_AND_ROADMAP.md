# PUBGET — تحليل الفجوات مقابل الوثيقة المرجعية + خارطة الطريق للإنتاج

المرجع الوحيد: `docs/PUBGET_MASTER_SPEC.md` (Locked). التاريخ: 2026-09-17. المراجعة المدققة: `195670c`.
الطريقة: قراءة الوثيقة كاملة + تدقيق مباشر لشجرة `lib/` و`functions/` و`firestore.rules` و`storage.rules` + `flutter analyze` + `node --check`.
ملاحظة: هذا تقرير تحليل فقط — لا تعديل كود. أي تنفيذ يبدأ بفرع `feature/` وبوابة PR كاملة حسب PROMPT التشغيل.

---

## أولاً: الخلاصة التنفيذية (أهم 5 حقائق)

1. **التطبيق لا يُبنى**: `flutter analyze` = **34 خطأ** (مع 2 warnings + 1 info). السبب الجذري الرئيسي: **مكدّسا Mafia مكرران** (`features/games/mafia` + `features/mafia`) مستوردان معاً في `pubget_app.dart:100-112` → `ambiguous_import` لـ `MafiaProvider`/`MafiaRepository`، إضافة getters ناقصة في `GameStrings` (`nightResult`, `voteResult`, `yourRole`, `alive`, `eliminated`, `noKill`, `saved`, `spectating`, `waitingNight`, `kill`, `investigate`, `protect`, `vote`, `selectTarget`, `mafiaWins`, `townWins`)، `final mafia` غير مُهيأ في `game_models.dart:135`، و`test/mafia_screens_test.dart` لا يحوّل ضد الواجهات الجديدة.
2. **الـ Backend لا يُنشر**: `functions/index.js:159` يعيد تعريف `const mafiaDomain` (خط 145 أيضاً) → SyntaxError قبل أي deploy. و`functions/src/gamesDomain.js:678-717` جملة `transaction.create` غير مغلقة + متغير `created` غير معرّف — **كل callables الألعاب (createGame…endGame) ميتة**.
3. **نظام الألعاب ومكافآته معطّل كلياً** بسبب النقطة 2 — بما يعني: لا مكافآت ألعاب، و3 ملفات اختبار تفشل من «الاستيراد»، و`npm test` = 177 ناجح / 5 فاشل.
4. **نظام الإعلانات MOCK/مثلّج**: موضع `homeFeed` فقط يُرسم وبطاقة `Sponsored` placeholder (`economy_widgets.dart:144-161`)، و`restorePremiumPurchases` يرجع `payment_provider_not_configured`، و**لا يوجد نظام أكواد تفعيل Premium** (المطلوب في المحور 19.4)، و`rewardedCoinsEnabled: false`.
5. **نظام Kirari (الريلز) شبه غائب**: يوجد "edits" v1 (رفع/معاينة/اعتدال نصي/respect/score ranking) لكن **لا إعادة أُعيد**: لا Hashtags، لا صفحات صوت/تسجيل صوتي، لا خلاصات For You/Following/Trending، لا محرك توصيات سلوكي، لا Trending-Velocity، لا تحليلات صانع، لا نسخ احتياطي 10 ريلز/يوم، لا مسودات. والمجال `reelsDomain.js` موجود في `functions/` لكنه **غير مستورد = ميت**.

---

## ثانياً: تصنيف المحاور (00–27)

الرموز: ✅ = مُنفَّذ فعلاً · 🔶 جزئي/يحتاج تطوير · 🔴 غير مُنفَّذ/معطّل/مُشوَّه · ⚠️ يجب إصلاحه قبل الإنتاج.

| المحور | الحالة | الأدلة الرئيسية | ما يلزم |
|---|---|---|---|
| **00 التعريف والمبادئ** | 🔶 | Core loop متحقق جزئياً (discovery/groups/economy)؛ لا بيانات وهمية في المسارات الحية عدا 3 حالات أدناه | إزالة الموك (انظر 07) |
| **01 المعمارية + Design System** | ✅/🔶 | طبقات UI→Provider→Repo→Firebase سليمة؛ Design System موجود (`app_colors.dart`, `pubget_design_system.dart`, `/design-system` في debug فقط)؛ عزل domains جيد (مافيا مستقلة، events تستورد chatCardWriter فقط) | تبقى بعض الشاشات بسطحية Material |
| **02 قواعد عابرة (حالات/Offline/روابط/Anti-abuse/عملات)** | 🔶 | `NetworkService` جاهز؛ كل شاشة لم تُدقق؛ **الروابط العميقة قديمة**: `/profile?uid=` لا `/profile/{username}`، لا `/reel`, `/work`, `/hashtag`, `/audio`, `/group/{id}` موجود، **`/g/**` بلا parser**؛ ledger العملات Server-side ✅ | محاذاة مسارات DL مع 2.3 + فحص حالات الشاشات |
| **03 المصادقة والانضمام** | ✅/🔶 | Login/Register/Forgot/Splash/Terms عبر AppStrings + AuthPageShell؛ Google ✅؛ فحص username فوري/uniqueness Server-side ✅ | `onboarding_page` **EN كاملة بلا AppStrings** + "أول 10 دقائق" غير موجود |
| **04 الأشرطة والقوائم** | 🔶 | 5 تبويبات سفلية ✅ (Discover/Groups/Joined/Private/Edits)؛ Drawer ✅ فيه Dragon Store، unread badges؛ قائمة الإنشاء: سطر `AppEngine` يرمي `/reels/upload` **غير مسجَّل** → ينتهي بـ UnknownLinkPage (ميّت) | تسجيل `/reels/upload` أو ربطه بمحرر الرفع + ترتيب الشريط العلوي حسب 4.1 |
| **05 Home/اكتشف** | 🔶 | Home = strips حية (promoted/rising/community/events 3+more)؛ إن **بقي** ناقص: ريلات مخصصة، ريلات أنمي الحالي/الأسبوع، شخصيات شعبية، نشاط الأصدقاء، صنّاع صاعدون، إنجازات/تقدم، "عرض المزيد"→صفحات أقسام، ترتيب عشوائي ذكي | توسيع الأقسام + صفحة قسم لكل strip |
| **06 البحث** | 🔶 | بحث عالمي: مجموعات/أشخاص/أحداث/أعمال/أنمي (Jikan) ✅ + filtering بلوك؛ **لا**: فلتر نوع كيان، لا ريلز، لا شخصية، لا هاشتاغ، لا صوت، لا Fuzzy، لا سجل حديث | ترقية البحث لمتطلبات 6 |
| **07 المجموعات** | 🔶 | Wizard/تفاصيل/join/requests/roles + لوحة تحكم موحدة بالرتب (PR #99)؛ Rising عبر discoveryEngine ✅ | **موك**: `_mockCharacters` 4 شخصيات RP (`firebase_group_repositories.dart:621`) + join يضع `uid:''` — يجب حذف الموك وربط شخصيات حقيقية من قاعدة الشخصيات |
| **08 الرتب والصلاحيات** | ✅ | الرتب 7 موجودة Client+Server، مصفوفة صلاحيات server-side، صفحة `role_permissions_page`؛ ادعاء "changeRole دائماً senpai" **قديم** — لم يعد موجوداً | تدقيق عرض الرتبة فقط بسياق المجموعة |
| **09 دردشة المجموعة** | ✅/🔶 | Phase B محصّن: retry/media/reconnect، تسجيل صوتي hold-to-talk، ملصقات، كاميرا، react/رد/تثبيت، حالات قراءة؛ لا توجد snackbars "Prepared for later" المذكورة في وثيقة قديمة | `chat_game_activity.actionLabel` hardcoded EN |
| **10 الخاص والعلاقات** | ✅/🔶 | Respect 0-7 + fan@5 + friends + قفل المحادثة الخاصة بالمعجب المتبادل + whoCanMessageMe + حظر ✅ | `give_respect_sheet` خليط AR، قائمة الخاصة صعبة Translation |
| **11 Roleplay** | 🔶 | حجز/تحرير Server-side ✅ | لا اختيار شخصية حقيقي — موك 4 شخصيات فقط؛ لا اقتراحات ذكية/بحث |
| **12 الألعاب** | 🔴 | **معطّل كلياً**: `gamesDomain.js` لا يُحل + index.js لا يُحل → كل callables الألعاب ميتة والمكافآت لا تُمنح؛ 3 محركات rebirth موجودة (guessCharacter/animeChain/emojiAnimeGuess) لكن نفقعة | إصلاح بناء الجملة + إعادة الـ`created`؛ تنظيف مكدّس `games_center_v2` اليتيم (فيه placeholder "Mafia ستصل في Prompt 2") |
| **13 Mafia** | 🔴 | **المحرك الكامل موجود في `src/mafia/`** (دولا، مراحل، انتصارات، مكافآت 10/2، archive) لكن **العميل لا يحوّل** بسبب مكدّسي Mafia المكررين + GameStrings الناقص؛ **انحراف عن الوثيقة**: الحد الأدنى للحوزة في الكود = 4 (الوثيقة 13.2: **7–15**) والحد الأقصى 8 | إصلاح العميل + محاذاة 7–15 + تدقيق خصوصية الأدوار |
| **14 الأحداث** | 🔶 | الأنواع 12 + منطق كامل Server-side + lifecycle scheduler + resolve/analytics ✅ | **خطأ**: `eventsDomain.js:1827` → في الـ Prediction يكتب `winnerIds: [winnerOptionId]` أي OptionID لا UserID؛ شاشة الإنشاء hardcoded EN |
| **15 Kirari (الريلز)** | 🔴 | "edits" v1 يعمل (pipeline/اعتدال نصي/respect/score/views) | **الأغلب الغائب** كما في الخلاصة 5؛ و`reelsDomain.js` ميت غير مستورد؛ لا نمط: hashtag/صوت/3 feeds/توصيات سلوكية/Trending/تحليلات/حد 10/مسودات؛ `needs_review` بلا حل اعتدال |
| **16 Anime Hub** | 🔶 | Jikan HTTP خلف `CachedAnimeRepository` + قوائم عبر callables + تقييم + إحصاءات + شخصيات + بلاغ مراجعة | لا cache Firestore (16.2: cache داخلي كـfallback أنيق)؛ `anime_details_page:1126` 'Report' EN hardcoded؛ لا رسالة `needs/flagged` resolution |
| **17 الأعمال الخاصة** | ✅/🔶 | الأنواع 7 + دورة حياة + وسائط + بلاغ/إزالة ✅ | نسخ EN hardcoded بكثافة ('Source:', 'Add page'…) |
| **18 الملف الشخصي** | ✅/🔶 | إعادة تصميم 5 أقسام (PR #100) + زر تعديل يعمل + fan-works list/ghost bio fix | `edit_profile_page` + `friend_requests_page` hardcoded EN |
| **19 الاقتصاد/متجر/Premium/إعلانات** | 🔴 | Ledger/ربح/caps/متجر (7 عناصر) ✅؛ **الإعلانات MOCK** (أعلاه)؛ **لا أكواد تفعيل Premium**؛ لا طبقة Billing معزولة؛ لا ندرة Common..Mythic؛ لا قسم "توسعات تقنية" | بناء Billing Layer + أكواد تفعيل Admin + إصلاح إعلانات كاملة (مقاس Cooldown no-fill Rewarded) + ندرة + توسعات |
| **20 الإنجازات** | ✅/🔶 | المحرك server-authoritative + كتلوج 10 + `getAchievements` + Hard Verify (emulator) | صفحة تقدم لكل إنجاز (7/10) + ندرة + حالة مقفل/حديث |
| **21 الإشعارات والدوائر الحمراء** | ✅/🔶 | Builder idempotent + markRead/All + FCM + UnreadEngine عبر التبويبات/Drawer ✅ | تجميع ذكي ("3 مستخدمين أعجبوا") غير مؤكد؛ عنوان الصندوق hardcoded EN |
| **22 الإعدادات والدليل** | 🔶 | إعدادات ملوّنة (حساب/مظهر/لغة/مساعدة/حول) | فئات ناقصة (إشعارات/خصوصية/أمان/بيانات) حسب 22؛ **الدليل منشور EN** وخالٍ من مواضيع (Chat/Roles/Roleplay/Respect/Moderation) |
| **23 الأمان والإشراف** | ✅/🔶 | Rules قوية (User+Ownership+Membership+Role+Action، حسّاسات مقفلة)، Storage صارم | **لا يوجد أي callable اعتدال/ادمن**: `needs_review` و`flagged` (edits/anime/fan works) بلا حل — بلاغات بلا queue؛ Server Rules على chat/media صلبة |
| **24 قاعدة البيانات** | 🔶 | مجموعات حول Domains؛ عضوية المجموعة في `groups/{id}/members` (الوثيقة تقول `group_members`أعلى مستوى)؛ لا `schemaVersion` معمّم | توثيق/توحيد الأسماء + reels schema |
| **25 ميزانية الأداء** | 🔶 | Pagination/Lazy/Cache واسع؛ لا قياس | تدقيق: لا rebuild كامل، Video preload+dispose، هدف 300ms |
| **26 الاختبارات** | 🔶 | Functions 177✅/5❌ (3 بسبب الأخطاء النحوية + 2 نقص node_modules)؛ Rules E2E ✅؛ Flutter 117 ملفاً عبر المناطق | **لا يمكن أن ينجح flutter test قبل إصلاح الـ34 خطأ**؛ لا Widget tests لمافيا/تشغيل edit/inbox retry/roleplay؛ لا CI تشغّل analyze/test |
| **27 سير عمل GitHub** | ✅ | PRs 97–103 دُمجت؛ بوابة PR معروفة في PROMPT | لا CI لبوابة analyze/test/publish — فقط build.yml (APK) |

---

## ثالثاً: قائمة مجموعات المحاور (أ + ب)

أوامر صالحة حسب PROMPT:
- المحاور ✅ تُحقَّق/تُدقق دون تغيير كود إلا إصلاح خلل مثبت: 08، 20.
- المحاور 🔶 تصلح لـ"طوّر" أوامر مجزأة: 01، 02، 03(onboarding)، 04، 05، 06، 10(social)، 18، 21، 22، 25، 26.
- المحاور 🔴 تحتاج تنفيذاً كاملاً: 12، 13، 15، 19، و23 (صفة الوسلطة).

---

## رابعاً: خارطة الطريق حتى الإنتاج (بالترتيب الإلزامي)

كل خطوة = فرع مستقل + بوابة PR كاملة (analyze=0, tests✅, build✅, rules-tests إن لُمست القواعد) + تقرير بالقالب.

### المرحلة 0 — فك الانسداد (شرط كل ما بعده)
- **0.1 | إصلاح العميل (34 خطأ)**: توحيد مكدّس Mafia (حذف/دمج المكرر)، إضافة getters الناقصة في `GameStrings`، تهيئة `final mafia`, إصلاح `game_widgets.dart:180`, تحديث `test/mafia_screens_test.dart` لواجهات `GameRepository`/`GroupRepository` الجديدة. → analyze=0, flutter test✅, `flutter build apk --debug`✅.
- **0.2 | إصلاح الـ Backend**: حذف تعريف `mafiaDomain` المكرر في `index.js`؛ إصلاح `gamesDomain.js:678-717` (إغلاق `transaction.create` + إزالة `.created` المزدوجة/غير المعرّفة). → `node --check` ✅ + `npm test`✅ (177→ناجح كامل بعد نصب node_modules) + `firebase deploy --only functions` works.
- **0.3 | إصلاح الخللين الدقيقين**: `guessCharacter.js:274` (الخاسر في مرحلة الإجابة يُمنح الدور خطأً) + `eventsDomain.js:1827` (winnerIds يجب أن تعيّن UserIDs).
- **0.4 | CI Gate**: إضافة step تشغّل `flutter analyze`+`flutter test`+`npm test`+`test:rules` قبل أي deploy (يناسب Axis 26/27).

### المرحلة 1 — سلامة التنقل وحذف الموك (Axis 04، 07، 11)
- **1.1 | Navigation**: تسجيل مسار `/reels/upload`، حذف مسارات `/games/waiting` و`/games/room` الميتة، تنظيف مكدّس games_v2 اليتيم + placeholder "Mafia ستصل في Prompt 2"، محاذاة الشريط العلوي لترتيب 4.1.
- **1.2 | Mock Removal**: حذف `_mockCharacters` ووصل الحجز بشخصيات حقيقية من قاعدة الشخصيات (Roleplay axis 11)؛ معالجة join `uid:''` إلى كتابة عضوية صحيحة.

### المرحلة 2 — Kirari (المحور 15 — الأكبر)
رتّب كمرّات فرعية:
- 15.1 flow: `+ ← ريلز` يعمل، فحص (مدة≤60ث عمودي ≤500MB)، محرر خفيف (قص/سرعات/غلاف/نص بسيط).
- 15.2 Metadata غني: Hashtags + anime/character tags من قاعدة الأنمي (لا كتابة حرة) + Mentions + صوت.
- 15.3 نظام الصوت: صفحة صوت/أصل/إعادة استخدام/إسناد + MediaService abstraction.
- 15.4 المشاهدة الموحدة + Preload/Cache/جودة تكيفية.
- 15.5 الخلاصات الثلاث: For You (توصيات سلوكية exploit 70–90/explore 10–30) · Following · Trending (Velocity).
- 15.6 Hashtags/ترند/مشاهدات (≥3ث، منع bot) + Counters server-safe.
- 15.7 إدارة الرفع العالمية (حد 10/يوم، retry، idempotency، لا حجب UI).
- 15.8 تحليلات الصانع (لا أرقام وهمية) + حالة/اعتدال (needs_review بحاجة لحل).
- 15.9 Règles البيانات: subcollections مستقلة + Indexes.
- ترقية `reelsDomain.js` من ميت إلى مستورد + rules فهرسة.

### المرحلة 3 — الألعاب + Mafia (المحور 12، 13)
- **3.1** بعد فك 0.2: تشغيل Game Center من الدردشة فقط، حد 2/يوم، Waiting rooms، Pipeline، مكافآت idempotent، أرشيف نتائج أنيق.
- **3.2** Mafia: إصلاح العميل (محاذاة 13.12، عربي كامل)، **تعديل حدود اللاعبين إلى 7–15** (الكود الآن 4–8)، تدقيق خصوصية الأدوار ونافذة العودة/الخمول Server-side.

### المرحلة 4 — Home + Search (المحور 05، 06)
- أكمل أقسام Home الناقصة + "عرض المزيد"→صفحات + ترتيب عشوائي ذكي.
- البحث: فلتر كيان، ريلز/شخصية/هاشتاغ/صوت، Fuzzy، سجل حديث، Deep links، لغة.

### المرحلة 5 — الأحداث + Anime Hub + Fan Works (14، 16، 17)
- إصلاح Prediction winnerIds، تحسين شاشة الإنشاء l10n، تحقيق قفل النتائج/Locked.
- Anime Hub: cache Firestore fallback أنيق، l10n، حل flagged المراجعات.
- Fan Works: l10n كامل.

### المرحلة 6 — الاقتصاد/متجر/Premium/إعلانات (المحور 19)
- Billing Layer Provider-agnostic + **نظام أكواد تفعيل Admin** (Activation Code).
- إصلاح الإعلانات كاملاً: مواضع مدروسة + تردد/Cooldown + تحميل/No-fill + Rewarded + تحليلات + عطل لا يكسر الشاشة.
- ندرة Common..Mythic + قسم التوسعات التقنية + تعويض المنشآت سابقاً (عملات + عنصر نادر + إشعار — بحاجة Data Migration موثقة كما في 0.5).

### المرحلة 7 — الإنجازات + الإشعارات + الإعدادات (20، 21، 22)
- صفحات تقدم وإن وندرة للإنجازات.
- تجميع ذكي للإشعارات + مراجعة UnreadEngine + l10n الصندوق.
- توسيع الإعدادات للفئات (إشعارات/خصوصية/أمان/بيانات) + دليل شامل بالعربية + مواضيع ناقصة.

### المرحلة 8 — الأمان والإشراف (المحور 23)
- بناء سطح اعتدال/ادمن Server-side (حل needs_review/flagged، قرمة بلاغات، تقييد/إزالة/استعادة) مع **عدم إضعاف Rules إطلاقاً** + اختبارات Emulator.

### المرحلة 9 — الجودة الشاملة (02، 25، 26، التعريب)
- مسح لغة شامل: كل EN-hardcoded المذكورة أعلاه → AppStrings (onboarding، search، private list، notifications، edit profile، friend requests، guide، events create، games، fan works، anime 'Report'، mafia أقسام AR-only، chat_game_activity، give_respect، members council، games_v2).
- حالات شاشة موحدة (Skeleton/Loaded/Empty/Error/Offline كل مكان) + عمق Links حسب 2.3 (مسارات جديدة).
- ميزانية الأداء: قياس + إصلاح (لا rebuild، preload+dispose، لا listeners مكررة).
- اختبارات: Widget لمافيا/تشغيل إيديت/Inbox retry/حجز Roleplay + Integration متعددة المستخدمين للـ Mafia + Regression.

### المرحلة 10 — فحص بصري نهائي وتسلّم (M من الملحق ب)
- مراجعة FAB فخامة/أنقة الألوان/وضع داكن-فاتح عمداً/RTL كامل، مقابل 0.3 + 1.3.

---

## خامساً: بنود BLOCKED (لا يمكن تنفيذها من المستودع)
- AdMob activation + Auth providers + App Check + FCM Web credentials — إعدادات **console-side**، خارج الشجرة.
- ترمي إصلاح الإعلانات لاحقاً إلى توفر باقة Blaze عند الحاجة.
- لا يوجد نظام دفع حقيقي — الوثيقة تقصره على أكواد تفعيل Admin (19.4) + Billing Provider-agnostic لاحق.

---

## سادساً: تنبيهات على وثائق قديمة
- `CURRENT_STATE_MASTER.md` كُتب عند `8f34d21` — **أجزاء قديمة**: عددتبوابات (الآن 5 وليست 4), ادعاء "changeRole دائماً senpai" لم يعد موجوداً, snackbars "Prepared for a later prompt" اختفت (كلها ملوّنة الآن), فحص العدّادات والإخفاء.
- `GAP_AUDIT.md` و`PUBGET_1_0_REBUILD_MATRIX.md` ضد الوثيقة القديمة (`PUBGET_1_0_SPEC.md`) — تُستأنس بهما فقط.
- المصدر الحالي للتصنيف أعلاه هو شجرة `195670c` الحية + الوثيقة المرجعية الجديدة.