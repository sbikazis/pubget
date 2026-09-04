PUBGET 1.0
الوثيقة المرجعية النهائية للنسخة الجديدة
الحالة: Master Specification / مرجع البناء
المنتج: Pubget
الهوية: منصة اجتماعية متخصصة لعشاق الأنمي والمجتمعات
المنصات الحالية: Android
اللغات: العربية + الإنجليزية
المبدأ الأساسي: الجودة أولًا — سرعة، سلاسة، منطق، جمال، أمان، وعمق اجتماعي.

0. الرؤية الكبرى
Pubget ليس مجرد:
تطبيق مجموعات.
تطبيق دردشة.
تطبيق أنمي.
تطبيق فيديوهات.
متجر.
أو تطبيق ألعاب.
بل هو:
مجتمع رقمي متكامل لعشاق الأنمي، يجمع الأشخاص والمجموعات والمحتوى والإبداع والألعاب والأحداث والصداقات والاهتمامات في عالم واحد.
الهدف ليس فقط أن يدخل المستخدم ويستهلك المحتوى.
بل أن يبني داخل Pubget:
أصدقاء + مجموعات + اهتمامات + أنميات مفضلة + إبداعات + ذكريات + إنجازات + مكانة اجتماعية.
بحيث يصبح لديه سبب طبيعي للعودة يوميًا.

1. مبادئ Pubget الأساسية
كل قرار في النسخة الجديدة يجب أن يمر على هذه المبادئ.
1.1 الجودة قبل كثرة الميزات
لا نضيف ميزة لمجرد أن التطبيق «يحتوي على الكثير». الميزة يجب أن تكون: مفيدة، مفهومة، سريعة، جميلة، مستقرة، قابلة للتوسع، وتخدم دورة استخدام حقيقية.
1.2 السرعة والسلاسة
هذه أولوية مطلقة. يجب ألا يشعر المستخدم أن التطبيق: ثقيل، متثاقل، ينتظر بلا سبب، يعيد بناء الشاشات بشكل مزعج، يجمّد الواجهة، يكرر التحميل، أو ينهار عند ضعف الإنترنت. كل العمليات الممكنة يجب أن تكون: Optimistic / Cached / Lazy / Paginated / Debounced / Background بحسب طبيعتها.
1.3 لا توجد حالات منطقية مهملة
كل ميزة يجب أن تحدد مسبقًا: حالة النجاح، التحميل، الفشل، عدم وجود البيانات، عدم الاتصال، انتهاء الجلسة، الصلاحية المرفوضة، المحتوى المحذوف، المستخدم المحظور، المستخدم الذي غادر، العنصر المنتهي، التعارض بين عمليتين، إعادة المحاولة.
1.4 أقل عدد ضغطات ممكن
قاعدة UX أساسية: أي فضاء مهم يجب أن يكون قريبًا من المستخدم. ولا ندفن الميزات داخل قوائم متداخلة بلا داعٍ.

2. هوية Pubget
2.1 الشخصية
Pubget يجب أن يشعر بأنه: Anime, Premium, Social, Dynamic, Youthful, Immersive, Professional. وليس تطبيقًا إداريًا أو منتدى تقليديًا.
2.2 الألوان
الهوية الأساسية: Royal Purple + Gold مع Dark Theme و Light Theme، والألوان يجب أن تُستخدم كنظام موحد، وليس كل شاشة بتصميم مستقل.
2.3 اللغة
اللغات الرسمية: العربية، English مع دعم كامل RTL و LTR. ولا يجب أن يكون دعم العربية مجرد ترجمة للنصوص؛ بل يجب أن تكون الواجهات مصممة فعليًا للاتجاهين.

3. بنية التطبيق الرئيسية
Pubget يتكون من منظومة مترابطة: Authentication, Onboarding, Home/Discovery, Groups, Group Chat, Private Chat, Social Graph, Respect/Fans/Friends, Notifications, Edits, Events, Games, Mafia, Anime Hub, Fan Works, Economy, Store, Premium, Search, Settings, Deep Links, Sharing, Permissions, Background Notifications, Analytics/Ranking, Security, Reliability, Offline/Retry, Moderation, Migration.

4. Authentication
Login: Email, Password, Login, Google Sign-In, Create Account, Forgot Password — مع Validation، Loading، Error mapping، Network handling، Session restoration.
Register: Email, Password, Confirm Password, Create Account, Google, Login link — مع تحقق كامل.
First Launch: Splash → Firebase bootstrap → Authentication state ثم: مستخدم غير مسجل → Login؛ مستخدم مسجل ولم يكمل الحساب → Onboarding؛ مستخدم مسجل ومكتمل → Home. ولا توجد شاشة وسيطة غريبة أو غير مفهومة.

5. Onboarding
المستخدم الجديد لا يجب أن يشعر أنه يملأ «استمارة». بل يبدأ ببناء عالمه. الحد الأدنى: Username, Profile image, Basic identity, Anime interests. ويُفضّل أن يسمح النظام لاحقًا بتوسيع الملف دون إجبار المستخدم على ملء كل شيء.

6. أول عشر دقائق
مرحلة استراتيجية. يجب أن يساعد التطبيق المستخدم على: الانضمام إلى مجموعة نشطة؛ رؤية Edits قوية ومبهرة؛ المشاركة في Event/Game؛ اكتشاف أشخاص مناسبين له؛ بدء بناء Friends/Fans/Interests؛ اختيار أنميات وشخصيات واهتمامات. الهدف: لا يغلق المستخدم Pubget بعد أول دخول لأنه لم يجد شيئًا يفعله.

7. Home
أهم شاشة في المنتج. ليست Dashboard ثابتة، بل Discovery Feed متجدد باستمرار.
7.1 المحتوى: يمكن أن تحتوي الصفحة على Promoted Groups, Rising Groups, Recommended Groups, Edits, Events, Anime of the Week, Trending Anime, Fan Works, Suggested Friends, Suggested Creators, User interests, Active communities, New creators, Popular discussions, Anime releases, Community highlights وغيرها.
7.2 الترتيب: لا يوجد ترتيب ثابت. كل جلسة يمكن أن تختلف. يعتمد النظام على Interests, Activity, Engagement, Freshness, Relevance, Social graph, Group membership, Anime interests, Velocity, Quality, Promoted status. مع عدم حذف نوع كامل من المحتوى فقط لأن اهتمام المستخدم به انخفض.
7.3 دعم المجموعات الصغيرة: المجموعة الجديدة لا يجب أن تختفي إلى الأبد داخل قاعدة البيانات. يجب بناء آلية Discovery/Rising Groups تساعد المجتمعات الصغيرة والجديدة على الظهور والوصول إلى المستخدمين. ليس فقط للمجموعات المدفوعة.

8. Main Navigation
Discover, My Groups, Joined, Private, Edits — مع إمكانية الوصول إلى بقية المنظومة عبر Home/Drawer/contextual actions.

9. Drawer
يجب أن تكون مساحة تحكم حقيقية. تشمل على الأقل: My Profile, Private Chats, My Groups, Joined Groups, Suggested Groups, Dragon Store, Premium, Settings, Guide وغيرها من الميزات التي تثبت فائدتها.

10–21. Groups
أنواع المجموعات الأساسية الحالية: A. Public Normal Group؛ B. Anime Roleplay Group (مرتبطة بأنمي محدد)؛ C. Open Roleplay Group (Roleplay مفتوح لعالم الأنمي عمومًا). هذه الأنواع تبقى حاليًا ولا نحذف نوعًا لمجرد تقليل عدد الأنواع، لكن البنية الداخلية يجب أن تجعل إضافة أنواع مستقبلية ممكنة.
Group Creation: Name, Image, Description, Type, Anime, Rules, Join mode, Capacity, Roleplay settings, Permissions, Privacy, Discovery settings — مع جعل العملية سهلة جدًا للمستخدم العادي.
Group Access: غير عضو يرى Group Details؛ مؤسس يرى Group Details الخاصة بالمؤسس؛ عضو عادي يدخل مباشرة إلى Chat — وهذا يقلل الاحتكاك غير الضروري.
Group Details: Group image, Name, Description, Anime, Members, Status, Join, Request, Chat, Share, Rules, Information, Members, Media, Events, Management بحسب الصلاحية.
Group Roles: النظام يجب أن يكون Role-based + Permission-based؛ أي أن الرتبة مرتبطة بالمجموعة، وليس بالمستخدم عالميًا. الرتب الحالية: Founder, Shogun, Commander, Captain, Sensei, Senpai, Member. يمكن إعادة ضبط الرتب أو إضافة/حذف رتب إذا أثبت التصميم الجديد أن ذلك يحسن النظام، لكن Founder/Shogun يبقيان جوهر الإدارة.
Founder: صاحب السلطة الأساسية، لكن العمليات الحساسة (تفكيك المجموعة، نقل السلطة، تغييرات حساسة) يجب أن تتطلب Confirmation وPermission validation.
Permissions: لا نستخدم نظام صلاحيات غامض. كل رتبة يجب أن يكون لها Permissions واضحة مثل Manage members, Manage roles, Edit group, Manage requests, Delete messages, Moderate, Manage events, Manage group settings وغيرها.
Members: قائمة ديناميكية، جميلة، قابلة للبحث والفلترة, مرتبة حسب الرتبة/النشاط عند الحاجة، وتغيير الرتب يجب أن يكون سريعًا + مفهومًا + محميًا بالصلاحيات + مع تأكيد عند العمليات الحساسة.
قاعدة عامة للصور الشخصية: في أي مكان يظهر فيه Avatar المستخدم، الضغط عليه → Profile (Chat, Members, Comments, Edits, Fan Works, Notifications, Search وغيرها).
Join System: يجب أن يدعم Open, Request, Invite بحسب إعداد المجموعة.
Roleplay Join: يجب أن يكون سهلًا جدًا؛ المستخدم يستطيع رؤية الشخصيات، البحث، اقتراحات، اختيار شخصية بنفسه، لكن النظام لا يفرض عليه شخصية.

22–29. Group Chat
الهدف: دردشة اجتماعية غنية وليست مجرد Text Chat.
Chat Header: Group Avatar, Group Name, Back, Three-dot/Menu؛ إذا كان الاسم طويلًا Marquee/scrolling title.
Chat Background: كل مجموعة يمكن أن يكون لها Background؛ يوجد Default Pubget Background عند أول دخول، ويستطيع المستخدم/الإدارة تغييرها وفق صلاحيات النظام.
Message Rendering: المرجع UX الأساسي WhatsApp + تحسينات Pubget الخاصة. الرسالة النصية تظهر Avatar, Name, Role badge, Role color, Message, Time, Delivery status (🔴 لم تصل، 🟡 وصلت ولم تقرأ، 🟢 تمت قراءتها).
أنواع الرسائل: Text, Image, Video, Sticker, GIF, Audio/Voice, Replies, System messages, Game/Event cards وغيرها.
Message Actions: بحسب نوع الرسالة والصلاحية — Reply, Copy, Delete, Pin, Edit, React, Forward/Share حيث يكون منطقيًا وغيرها. ولا نضيف أدوات لمجرد التقليد.
Stickers: نظام غني وسريع مع Picker, Saved/Favorites, Recent, Categories, Creator/custom stickers مستقبلًا, Theme integration.
Chat Performance: paginated, cached, incremental, efficient, stable, optimized for long conversations. ولا يتم تحميل آلاف الرسائل بلا داعٍ.

30–37. Games داخل Chat / Mafia
القاعدة: الألعاب لا تسيطر على Chat. التدفق: Game Button → Events/Games Menu → Create → Announcement Card → Waiting Room → Collect Players → Private Game Room → Game Engine → Results → System/Event Card داخل Chat.
قاعدة الألعاب: كل لعبة يجب أن تكون مستقلة، State-driven، قابلة للاستعادة، لا تكسر Chat، لا تعدل Chat internals مباشرة، ترسل أحداثًا عبر contracts.
Guess Character: 1 vs 1 مع matchmaking, waiting, round state, timer, scoring, result, anti-abuse, replayability.
Anime Chain: نفس قواعد State management, Turn management, timeout, scoring, cancellation, recovery.
Emoji Anime Guess: 2–4 لاعبين، لاعب يرسل 3–4 emojis بدون كلام، والبقية يخمنون، الصحيح يحصل على نقطة، ثم ينتقل الدور — مع timer, score, round system, turn rotation, anti-spam, end-game state, results.
Mafia: نظام مستقل معقد داخل Pubget، state machine, server authoritative, phase-controlled, timer controlled, reconnect-safe, disconnect-safe, role-safe, action-safe, anti-cheat. المراحل: Lobby → Role assignment → Night → Actions → Resolution → Day → Discussion → Voting → Resolution → Win check → Next phase → Finish → Rewards → History، وكل Role له logic مستقل.
Mafia UX: تجربة ممتعة وليست شاشة تقنية — Waiting Room, Role presentation, Phase banners, Timers, Action sheets, Voting, Results, Suspense, System messages, Game history.

38–41. Events
ليست مجرد Poll، بل نظام تفاعلي مؤقت. الأنواع المحتملة: Poll, Comparison, Theory, Quiz, Challenge, Prediction, Ranking, Discussion, Community question وغيرها. الحد الأقصى للمدة: 7 أيام (قابلة للتحديد ضمن هذا النطاق). يمكن إطلاق Events داخل المجموعة وتنتج Notifications, Activity, Results, Rewards, Chat cards. Chat يعرض الحدث لكن Event domain مستقل.

42–49. Edits
منصة فيديو داخل Pubget، وليس مجرد صفحة منشورات. المحتوى الأساسي: Video فقط، مع Upload, Validation, Processing, Compression, Thumbnail, Metadata, Moderation, Publish.
Edit Feed: يعتمد على خوارزمية Ranking (Relevance, Freshness, Watch time, Completion, Engagement, Quality, Creator signals, User interests, Social graph, Velocity, Diversity). لا يوجد قتل للمحتوى: انخفاض الاهتمام لا يعني الاختفاء التام — توزيع مع الحفاظ على Discovery diversity.
Edit UI: TikTok-level interaction logic + Pubget visual identity، دون نسخ الهوية البصرية.
Edit interactions: على الأقل View, Like, Comment, Reply, Share, Save, Creator profile, Respect.
Comments: مساحة اجتماعية حقيقية — Replies, Likes, Stickers, Sorting, Pagination, Loading, Empty, Moderation.
Views: نظام دقيق ومقاوم للتلاعب — ليس مجرد +1 كل فتح، بل قواعد واضحة لما يعتبر View.

50–52. Creator/Fan System, Respect, Friends
لا يوجد Follow التقليدي كعنصر أساسي، بدلًا منه Respect → Fans: عند وصول الاحترام الممنوح لشخص إلى 5+ يدخل المستخدم في Fans relationship ويستطيع رؤية الجديد الخاص بالمبدع.
Respect: نظام اجتماعي أساسي، يُمنح لمستخدم آخر، يمكن تراكمه وعرضه واستخدامه في العلاقات وفتح Private Chat، مع منع spam وfarming وabuse.
Friends: نظام صداقات كامل، ليس مجرد Fans. العلاقات تصبح منظومة User → Respect → Fan → Friend → Social graph بحسب القواعد التي سيحددها النظام.

53–54. Private Chat
نظام مستقل عن Group Chat. يشمل Conversation list, Last message, unread, delivery state, media, replies وغيرها. حسب النظام الحالي: يمكن فتح التواصل الخاص وفق شروط Respect، ويجب أن يكون ذلك واضحًا للمستخدم بدل ظهور زر لا يعمل.

55–58. Notifications
نظام مركزي. أي حدث يخص المستخدم يجب أن يصل إليه حسب نوعه: Join request, Request accepted, Role changes, Group events, Group dismantling, Likes, Comments, Replies, Views milestones, New edits, Respect, Fans, Friends, Messages, Events, Games, Premium, Store وغيرها.
Notification Routing: كل إشعار يجب أن يعرف إلى أين يأخذ المستخدم (Group, Chat, Edit, Profile, Event, Search/Offer).
Unread System: أي شيء غير مقروء يجب أن يمتلك Red badge/indicator بحسب السياق (Groups, Joined, Private, Notifications وغيرها).
Background Notifications: Android حاليًا، مع Push notifications, Background delivery, Notification tap routing, Deep links, session-safe handling.

59–60. Anime Hub
نظام مستقل شبيه بفكرة Anime List مدمج داخل Pubget. الوظائف: New releases, Anime information, Ratings, Characters, Genres, Seasons, Recommendations, Lists, Favorites, User ratings, Anime interests, Character interests. المستخدم يستطيع بناء Anime identity في Profile: Favorite anime, Favorite characters, Ratings, Lists, Interests — يُستخدم أيضًا لتحسين Discovery.

61–63. Fan Works
فضاء للإبداع. الأنواع: Manga, Drawing, Story, Character, AI-assisted Character, Worldbuilding وغيرها. المستخدم يستطيع Publish, Browse, Rate, Like, Comment, Reply, Share, Save, Open creator profile. النظام يجب أن يحافظ على ownership metadata, creator attribution, timestamps, reporting, moderation, حقوق المستخدمين.

64–72. Economy, Store, Premium
العملة هي وقود نمو Pubget. مصادر الكسب متعددة: meaningful participation, Events, Games, Content creation, Community contribution, referrals, achievements, creator milestones, engagement loops وغيرها، مع منع farming/spam/fake engagement.
قاعدة مهمة: إذا وسعنا مصادر الدخل من العملات، يجب أن نخلق مصادر إنفاق كافية؛ المتجر يجب ألا يكون فارغًا.
أقسام المتجر: 1) Technical Extensions (Group capacity, limits, feature extensions)؛ 2) Physical Products (مؤجل حاليًا، لكن Architecture قابلة للتوسع)؛ 3) Luxury/Cosmetics — الجزء الأهم: مفيدة، جميلة، مرغوبة، Anime-inspired، نادرة عند الحاجة، ذات قيمة اجتماعية/جمالية (profile cosmetics, frames, badges, chat cosmetics, backgrounds, stickers, effects, themes, group cosmetics, creator cosmetics). كلما كان العنصر مشهورًا/نادرًا/مميزًا، يمكن أن تكون قيمته أعلى.
Advertising: قرار نهائي — الإعلانات مصدر دخل التطبيق. لا توجد خاصية تعطيل الإعلانات مقابل Coins؛ يجب إزالة هذا المنطق من النسخة الجديدة. يجب إصلاح نظام الإعلانات بالكامل ليظهر فقط في الأماكن المنطقية مع frequency control, placement rules, premium behavior, loading/failure state, fallback, no accidental duplicate ads.
Premium: عضوية حقيقية تمنح Badge, Additional limits, Exclusive cosmetics, Additional features, Reduced friction وغيرها.
Monetization: حاليًا لا Google Play Billing ولا دفع حقيقي داخل التطبيق عبر النظام الرسمي، لكن Architecture يجب أن تكون جاهزة مستقبلًا لإضافة Subscriptions + Digital Purchases بدون إعادة بناء الاقتصاد.

73–76. Settings, Guide, Search
Settings يجب أن يصبح مركز تحكم حقيقي: Account (info, email, password, profile, privacy, security, logout)، Appearance (System/Light/Dark)، Language (System/العربية/English)، Notifications (permission, behavior, categories)، Privacy (profile visibility, activity visibility, messaging).
Guide: دليل شامل يشرح Groups, Chat, Games, Events, Edits, Respect, Fans, Friends, Coins, Store, Premium, Anime, Fan Works, Settings وغيرها.
Search: ليست شاشة واحدة فقط — بحث عام (Users, Groups, Events, Anime, Fan Works, Edits عندما يصبح لها contract مناسب) وContextual Search (Search members inside group, Search anime, Search characters, Search content, Search stickers وغيرها).

77–84. Deep Links, Sharing, Profile, Social Graph
كل عنصر مهم يجب أن يمتلك رابطًا قابلًا للمشاركة (Group, Profile, Edit, Fan Work, Event, Anime, Game, Store وغيرها). المشاركة يجب أن تكون Copy link, Native share, Canonical URL, Deep link — ولا يجب تسريب private data, IDs الحساسة, balances, roles الداخلية, event private data.
Profile: تقرير وهوية المستخدم — Avatar, Username, Premium, Bio, Stats, Respect, Fans, Friends, Anime, Characters, Ratings, Edits, Fan Works, Groups, Achievements, Activity حيث يسمح المستخدم. كل معلومة ليست ضرورية يجب أن تكون قابلة للتحكم؛ المستخدم يقرر ما يظهر.
Social Graph: شبكة اجتماعية فعلية، ليست مجرد Follow، بل Respect → Fan → Friend → Community relationships مع privacy, blocking, anti-abuse, relationship state.
Group Invitation: من Chat → Add Members → فتح Private Chats → اختيار الأشخاص → إرسال رسالة ترحيب فخمة تحتوي اسم المجموعة، الوصف، معلومات مختصرة، الرابط، دعوة واضحة.
Group Menu (الثلاث خطوط): Add members, Copy group link, Group information, Group media, Members, Edit group, Leave group, Dismantle group (Shogun/authorized role), Events, Settings وغيرها حسب الصلاحية.
Group Media: فضاء لعرض Images, Videos, Stickers/media حسب الحاجة مع pagination.

85–96. Offline, Performance, UI System, Accessibility, Security
Offline/Network ليست ميزة إضافية بل جزء من النظام: كل شاشة يجب أن تعرف ماذا تفعل عند No Internet (Cached content, Retry, Offline banner, Queue, Graceful degradation).
Device Performance: تحسين memory, image loading, video loading, Firestore reads, rebuilds, animations, scrolling, caching, pagination, network requests. Adaptive Media Quality حسب الاتصال والجهاز.
UI System: Design System موحد (Buttons, Cards, Text fields, Dialogs, Bottom sheets, Snackbars, Empty states, Error states, Loading, Avatars, Badges, Role indicators, Media containers, Navigation, Typography).
Visual Quality: Hierarchy + spacing + typography + motion + depth + consistency، دون مؤثرات في كل مكان.
Motion: قصيرة، ذات معنى، سلسة، غير مزعجة.
Accessibility: text scaling, touch targets, contrast, RTL, screen sizes, keyboard, motion tolerance حيث يلزم.
Security: كل شيء حساس (Coins, Rewards, Premium, Roles, Permissions, Game results, Economy, ownership) يجب أن يكون Server-authoritative. لا يعتمد العميل على أنه «لن يرسل طلبًا خاطئًا» — القواعد والخدمات الخلفية يجب أن تمنع ذلك.
Storage: الملفات يجب أن تكون validated, size-limited, type-limited, access-controlled, organized, moderated حيث يلزم.
Anti-Abuse: أنظمة ضد spam, respect farming, coin farming, fake views, fake likes, malicious uploads, message abuse, game abuse, referral abuse.
Moderation: بنية تسمح مستقبلًا بـ report, moderation, blocking, content removal, user restrictions.

97–101. Architecture, Domain Isolation, Legacy Migration
المبدأ: UI → Provider/Controller → Repository/Service → Firebase/API/External Service، ولا توضع business logic داخل Widgets.
Domain Isolation: كل Domain مستقل — مثلًا Chat لا يملك Mafia، وMafia لا يعدل Chat internals بل يرسل عبر Game Event/Contract → Chat Activity Card. نفس المبدأ لـ Events, Games, Anime, Fan Works, Economy, Notifications.
Legacy Migration: النسخة القديمة ليست شيئًا يُتخلص منه عشوائيًا — نحتفظ بالبيانات المفيدة وليس بالأخطاء المعمارية (استخراج، Mapping، Validation، Transformation، Migration، Verification). إذا كانت بيانات قديمة لا تتوافق مع النظام الجديد ولا يمكن ترجمتها منطقيًا، يمكن حذفها.
Legacy Code (`lib_legacy/`): يبقى محفوظًا أثناء إعادة البناء ما لم نقرر لاحقًا التخلص منه بعد التأكد، ولا يسمح للكود القديم بتلويث architecture الجديدة.
Data Migration: كل نوع بيانات يجب أن يمتلك Old Schema → Mapping → New Schema مع validation, deduplication, missing fields, invalid references, orphan cleanup.

102–105. Testing, Production States, Analytics
Testing: Unit tests للمنطق، Integration tests للتدفقات، Security tests للقواعد، Regression tests لمنع كسر الميزات السابقة، Real-device verification.
Production States: كل شاشة يجب أن تغطي Loading, Success, Empty, Error, Offline, Unauthorized, Forbidden, Deleted, Expired, Retry, Partial data حسب الحاجة.
Analytics: نقيس opens, completion, engagement, retention, content interaction, group discovery, event participation, game participation, sharing — بدون انتهاك الخصوصية.

106–110. الحلقات (Loops)
Retention Loop: Pubget يجب أن يبني أسبابًا طبيعية للعودة (Friend activity, New Edit, New Event, Group discussion, Anime release, Fan Work, Game, Respect, Notification, Achievement) دون تحويل التطبيق إلى ماكينة إشعارات مزعجة.
Discovery Loop: See content → Interact → Discover person/group → Join → Participate → Create → Gain respect/fans/friends → Earn coins → Spend coins → Become more invested → Return.
Creator Loop: Create Edit/Fan Work → Publish → Discovery → Views → Likes/Comments → Respect → Fans → More visibility → More creation.
Group Loop: Discover group → Join → Chat → Friends → Events → Games → Community identity → Return.
Economy Loop: Contribute → Earn Coins → Spend Coins → Cosmetics/Extensions → Higher investment → More participation، مع منع Pay-to-win.
110. الأشياء التي لن نفعلها: Pay-to-win, Gambling, Loot boxes, Crypto, P2P money transfer, شراء Coins لإزالة الإعلانات.

111–115. القيود الحالية وجودة التجربة
Physical Store: مُهمَل/مؤجل حاليًا، لا نسمح له بتعقيد النسخة الحالية، لكن Architecture لا تمنع إضافته مستقبلًا.
Google Play Billing: غير مستخدم حاليًا، لكن النظام الاقتصادي يجب أن يكون قابلًا للإضافة مستقبلًا.
Android: المنصة الحالية، ويجب ألا نُحمّل النسخة الحالية تعقيدات منصات لا نحتاجها، لكن architecture قابلة للتوسع.
جودة التجربة: المستخدم يجب أن يشعر بأن التطبيق سريع، الانتقال فوري، الرسائل واضحة، الأزرار مفهومة، المعلومات في مكانها، الخطأ لا يربكه، لا توجد شاشات ميتة، كل شيء له سبب.

116–119. قواعد التطوير والجودة والأسطورة
قاعدة التصميم الأهم: لا نريد Beautiful but useless ولا Functional but ugly، بل Beautiful + Fast + Logical + Useful.
قاعدة التطوير: صلاحية الإضافة/الحذف/التعديل/إعادة الهيكلة ليست صلاحية لإضافة Features عشوائية. أي إضافة يجب أن تجتاز: هل تزيد القيمة؟ هل تزيد retention؟ هل تزيد usability؟ هل تحسن discovery؟ هل تخدم الاقتصاد؟ هل تخدم المجتمع؟ هل تستحق تكلفة التعقيد؟ إذا كانت الإجابة لا، لا نضيفها.
معيار «الجودة»: عند وجود خيارين — أكثر ميزات لكنه معقد، مقابل أقل ميزات لكنه واضح وسريع وممتع — الأفضل غالبًا الخيار الثاني.
معيار «الأسطورة»: Pubget لا يصبح مميزًا بكثرة الميزات، بل من خلال تكامل الميزات (Anime → Profile → Group → Chat → Event → Edit → Respect → Friend → Fan → Coins) بحيث يشعر المستخدم أنه جزء من عالم واحد.
المرجع البصري: نستفيد من أفضل الممارسات المعروفة في WhatsApp (Chat UX), TikTok (video feed mechanics), Instagram (social discovery), Discord (المجتمعات), MyAnimeList (anime information) — لكن لا ننسخ أي تطبيق؛ نأخذ أفضل المبادئ ونبني Pubget identity.

120. أهم Priority في إعادة البناء
Tier 1 — Core Experience: Performance, Architecture, Home, Groups, Chat, Social graph, Edits.
Tier 2 — Engagement: Events, Games, Mafia, Notifications, Friends/Fans/Respect.
Tier 3 — Content Ecosystem: Anime Hub, Fan Works, Search, Discovery.
Tier 4 — Economy: Coins, Store, Premium, Ads.
Tier 5 — Platform: Settings, Deep Links, Sharing, Security, Migration, Analytics, Hardening.

121. القرار النهائي بشأن النسخة الحالية
لا نبدأ بإصلاح كل شاشة عشوائيًا. الخطوة التالية بعد تثبيت هذه الوثيقة: PRODUCT COMPLIANCE & GAP AUDIT — نأخذ النسخة الحالية ونقارنها بهذه الوثيقة، ونصنف كل شيء: 🟢 PASS (مطابق), 🟡 PARTIAL (موجود لكن ناقص), 🟠 MAJOR GAP (يحتاج إعادة عمل مهمة), 🔴 CRITICAL (يكسر الرؤية/المنطق/الأمان), ⚪ MISSING (غير موجود), ⚫ REMOVE (يجب حذفه), 🔵 IMPROVE (موجود لكن يحتاج تحسين). ثم نضيف Systemic/Local: هل المشكلة في صفحة واحدة؟ أم Design System كامل؟ أم architecture؟ أم backend contract؟ أم navigation؟

122. ما أصبح «مقفلاً» من الآن (قرارات Product وليست اقتراحات عابرة)
Pubget منصة اجتماعية للأنمي والمجتمعات. الجودة أولوية مطلقة. السرعة والسلاسة غير قابلة للتفاوض. Groups + Chat + Edits + Events هي أعمدة أساسية. Home ديناميكية وليست ثابتة. المجموعات الصغيرة تحصل على فرص Discovery. أنواع المجموعات الثلاثة تبقى حاليًا. Roleplay له Join flow متخصص. Chat غني وليس مجرد مساحة رسائل. Games مستقلة عن Chat. Mafia نظام مستقل عالي التنظيم. Respect هو أساس Social Graph. 5 Respect → Fan relationship. Friends system كامل. Edits فيديو فقط. Events حتى 7 أيام. Anime Hub داخل التطبيق. Fan Works. Economy واسعة. Coins وقود التفاعل والنمو. Store رقمي + Cosmetics/Extensions. Physical products مؤجلة. الإعلانات مصدر دخل ولا تُزال بالعملات. Premium مستقل. Search في الأماكن التي يحتاجها المستخدم. Deep Links. Sharing. Privacy controls. Arabic + English. Android حاليًا. Offline/error/retry جزء من كل Domain. كل البيانات القديمة المفيدة تُنقل. البيانات غير القابلة للترجمة منطقيًا يمكن التخلص منها. لا إعادة بناء عشوائية للنسخة القديمة. لا Prompt 18 قبل الـ Audit.

123. أهم قرار في المشروع كله
لن نعتبر أي أداة تطوير ناجحة لأنها قالت "كل الاختبارات نجحت". الاختبارات مهمة جدًا لكنها لا تثبت أن Pubget أصبح Pubget الذي وصفته. نفصل بين ست زوايا للحكم على أي مرحلة:
Technical Correctness — هل الكود يعمل؟
Product Correctness — هل بنى المنتج الذي نريده؟
UX Correctness — هل استخدامه ممتاز؟
Visual Correctness — هل يبدو بالمستوى الذي نريده؟
Business Correctness — هل توجد حلقات نمو واحتفاظ واقتصاد سليمة؟
Production Correctness — هل يتحمل الواقع؟
معيار "شبه-نهائي" واقعي لأي مرحلة مستقبلية من هذا النوع: لا توجد فجوة معروفة أو متعمدة مقابل مواصفات Pubget 1.0 لنطاق تلك المرحلة، ولا feature وهمية، ولا placeholder غير معلن، ولا backend ناقص تم إخفاؤه، وكل ما يمكن اختباره آليًا يتم اختباره، وكل مسارات المنتج الحرجة لتلك المرحلة تمر باختبار حقيقي.
