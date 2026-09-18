# المهمة المعلّقة — Premium عبر Coins (لم تُنفَّذ بعد — محفوظة للمراجعة)

> الحالة: **محفوظة فقط — لا تنفيذ.** الوثيقة مُسلّمة، وتُعاد إليها كل مرة يطلَب فيها تنفيذ هذه المهمة.
> التحذير من المالك: "لا تقم بإتلاف أي شيء — التغيير الوحيد أمامك، وكل ما تبقى يبقى كما هو."

---

## 1. الهدف
نفّذ تعديلًا محدودًا ومدروسًا على نظام Premium الموجود حاليًا في Pubget.

ممنوع إعادة تصميم Premium من الصفر. ممنوع تغيير بنية النظام الحالية أو حذف ميزاته الأخرى.

المطلوب هو تغيير طريقة الحصول على Premium فقط:

**Premium يصبح Entitlement رقميًا يتم تفعيله مقابل Coins داخل Pubget بدل الدفع المالي المباشر.**

## 2. الإعلانات
عدّل Premium بحيث:

- احذف ميزة إزالة الإعلانات / No Ads / Ad-Free من مزايا Premium نهائيًا.
- الإعلانات يجب أن تبقى ظاهرة للمستخدمين، بما في ذلك مستخدم Premium.
- لا تضف أي وسيلة أخرى تسمح لمستخدم Premium بإيقاف الإعلانات.
- لا تضف "Coins مقابل إزالة الإعلانات".
- لا تنشئ اشتراكًا منفصلًا لإزالة الإعلانات.
- السبب التجاري: الإعلانات هي مصدر الدخل الأساسي/الوحيد الحالي لـ Pubget، ولذلك لا يجوز أن يقوم Premium بإلغائها.

## 3. طريقة الحصول على Premium
بدل `Real Money → Premium` يصبح: `Pubget Coins → Premium`.

المستخدم يذهب إلى صفحة Premium، يرى الخطط الحالية ومدتها وتكلفتها بالـCoins، ثم يدفع الـCoins من رصيده.

- يجب أن يتم خصم Coins server-side فقط.
- لا تسمح للعميل Flutter بتعديل رصيد Coins أو منح Premium لنفسه.

## 4. لا تغيّر مزايا Premium الأخرى
احتفظ بجميع مزايا Premium الموجودة في الـMaster Spec والنظام الحالي، باستثناء إزالة الإعلانات.

- Premium Badge · الحدود/السعات الموسعة · تخصيصات Premium · خيارات الملف الشخصي الخاصة · العناصر الحصرية · وأي Premium entitlement آخر موجود فعليًا في النظام — تبقى كما هي.
- لا تخترع مزايا جديدة. لا تحذف مزايا موجودة لمجرد إعادة هيكلة الدفع.
- **قبل تعديل الكود، افحص implementation الحالي وحدد بدقة جميع Premium entitlements الموجودة حاليًا.**

## 5. لا تفترض تكلفة Premium بالـCoins (نقطة إلزامية)
لا تضع رقمًا عشوائيًا (مثل 1,000 أو 10,000 Coins) قبل دراسة اقتصاد Pubget. قم أولًا بتحليل:

- جميع مصادر Coins الموجودة حاليًا.
- كمية Coins التي يحصل عليها المستخدم من كل مصدر.
- القيود اليومية/الأسبوعية لكل مصدر.
- الوقت المتوقع لمستخدم عادي للوصول إلى رصيد معين.
- الفرق بين المستخدم النشط جدًا والمستخدم العادي.
- هل توجد مصادر Coins يمكن إساءة استخدامها.
- معدل تضخم Coins المتوقع.
- أي أسعار أو حدود موجودة حاليًا في Economy/Store.
- قيمة الخطط الحالية لـ Premium ومددها.
- أي بيانات استخدام حقيقية موجودة في المشروع، دون اختلاق بيانات غير موجودة.

إذا كانت البيانات الحقيقية غير كافية لتحديد السعر، لا تخترع بيانات. استخدم نموذجًا اقتصاديًا واضحًا وافتراضيًا، واذكر أن الرقم مبني على assumptions وليس على بيانات استخدام فعلية.

## 6. البحث الخارجي
قم ببحث حديث عن اقتصاد التطبيقات التي تستخدم عملات افتراضية واشتراكات/ميزات Premium يتم الوصول إليها عبر العملات داخل التطبيق. استخدم مصادر موثوقة، وركز على:

- طرق تسعير العملات الافتراضية.
- العلاقة بين معدل كسب العملة وتكلفة الـPremium.
- منع التضخم الاقتصادي.
- جعل الهدف achievable للمستخدم العادي دون جعله سهلًا لدرجة تدمير قيمة Premium.

لا تنسخ أسعار تطبيق آخر مباشرة. البحث يستخدم كمرجع اقتصادي فقط.

## 7. الهدف الاقتصادي للسعر
يجب أن تحقق تكلفة Premium توازنًا بين ثلاثة أشياء:

- **A — Accessibility**: المستخدم العادي يستطيع الوصول إلى Premium من خلال النشاط الطبيعي داخل Pubget.
- **B — Value**: الوصول إلى Premium يجب أن يحتاج إلى جهد حقيقي، حتى لا يصبح شيئًا يحصل عليه الجميع بسهولة.
- **C — Economy Stability**: تكلفة Premium لا يجب أن تؤدي إلى: تضخم Coins، استنزاف اقتصاد التطبيق، farming سهل، bot abuse، انتقال سريع جدًا إلى Premium، أو جعل Premium شبه مستحيل للمستخدم العادي.

حدد السعر بناءً على هذه المبادئ.

## 8. التسعير حسب المدة
افحص الخطط الموجودة حاليًا. إذا كان النظام الحالي يحتوي مثلًا على Monthly / Yearly / Lifetime، فلا تحذف الخطط. حوّل قيمتها إلى Coins بطريقة منطقية.

يجب أن تكون هناك علاقة واضحة بين مدة Premium وتكلفة Coins، بحيث لا يكون Lifetime مجرد مجموع بسيط غير مدروس للأشهر. إذا كانت بنية الخطط الحالية مختلفة، حافظ عليها ولا تغيّرها إلا إذا كان التغيير ضروريًا لهذا النموذج.

## 9. Server-side transaction
تنفيذ شراء Premium بالـCoins يجب أن يكون عملية ذرية Idempotent.

المسار:
```
User → Premium Plan → Create Premium Purchase Request
→ Server validates: authenticated user · valid plan · current coin balance · eligibility · plan availability
→ Atomic transaction:
   ├── deduct Coins
   ├── create/update Subscription/Entitlement
   └── create Economy Ledger Entry
→ Premium Activated
```
إذا فشلت أي خطوة: لا يتم خصم Coins ولا يتم منح Premium. لا تسمح بحالة: `Coins deducted + Premium not activated` أو `Premium activated + Coins not deducted`.

## 10. Economy Ledger
كل عملية Premium يجب أن تظهر في Coin Ledger. مثال:
```
type: PREMIUM_PURCHASE
userId: ...
planId: ...
coinsSpent: ...
timestamp: ...
transactionId: ...
balanceBefore: ...
balanceAfter: ...
```
يجب أن يكون السجل server-generated وغير قابل للتعديل من العميل.

## 11. منع الاستغلال
تحقق من: double tap · repeated purchase requests · replay attacks · duplicate transactions · insufficient balance · invalid plan IDs · expired plans · manipulated client values · negative coin amounts · integer overflow · race conditions · concurrent purchases من أجهزة متعددة.

**السعر النهائي يجب أن يأتي من server-side plan configuration وليس من قيمة يرسلها Flutter.**

مثال:
- ❌ العميل يقول: `coins = 100` → لا تثق به.
- ✅ `Client → planId` · `Server → يعرف السعر الحقيقي للخطة` · `Server → يتحقق من الرصيد` · `Server → يخصم السعر الحقيقي`.

## 12. Premium Entitlement
لا تجعل `isPremium = true` هو مصدر الحقيقة. يجب أن يعتمد Premium على Entitlement/Subscription الموجود في النظام مثلًا:
- `planId` · `startedAt` · `expiresAt` · `status` · `source = coins` · `transactionId`

وعند انتهاء المدة: `ACTIVE → EXPIRED` تلقائيًا server-side.

## 13. التجديد
لا تفترض وجود Auto-Renewal بالمال. لأن Premium يتم شراؤه بالـCoins، يجب أن يكون التجديد عملية جديدة باستخدام Coins. إذا كان المستخدم لا يملك Coins كافية عند انتهاء Premium: Premium ينتهي طبيعيًا. لا تخصم Coins مستقبلية. لا تسمح برصيد سلبي. لا تمنح Premium مجانًا.

## 14. Lifetime
إذا كانت خطة Lifetime موجودة، يجب التعامل معها بشكل مختلف:
- `expiresAt = null` · `status = ACTIVE` · `planType = LIFETIME` · ولا يتم تمديدها شهريًا.

إذا كان Lifetime غير موجود في implementation الحالي، لا تضفه من تلقاء نفسك.

## 15. واجهة المستخدم
حدّث واجهة Premium بحيث تكون واضحة جدًا:

- بدل عرض `$X / month` اعرض `X Coins / month` وما إلى ذلك.
- أظهر للمستخدم: رصيده الحالي من Coins · تكلفة الخطة · عدد Coins الناقصة إن لم يكن لديه ما يكفي · مدة Premium · جميع المزايا · تنبيه واضح بأن Premium لا يزيل الإعلانات.
- لا تستخدم أي نص يوحي بأن Premium بدون إعلانات.

## 16. عدم تغيير Coin Sources
لا تغيّر مصادر Coins الموجودة حاليًا لمجرد تنفيذ هذه المهمة. إذا اكتشفت أن مصدرًا معينًا يجعل farming Premium سهلًا جدًا، لا تحذف المصدر مباشرة. بدل ذلك: وثّق المشكلة · اذكر معدل الكسب الحالي · اشرح تأثيره على Premium · اقترح تعديلًا منفصلًا إذا كان ضروريًا. لا توسع Scope المهمة بدون ضرورة.

## 17. Ad System
لا تعدّل نظام الإعلانات إلا بالقدر الضروري لإزالة منطق `Premium → remove ads`. يجب ألا تتأثر: Ad loading · Ad frequency · Ad provider · Ad placements · Ad analytics · Ad eligibility — إلا إذا كان هناك كود مرتبط مباشرةً بشرط `if premium then hide ad`، في هذه الحالة أزله بحيث تستمر الإعلانات أيضًا لمستخدمي Premium.

## 18. Billing Architecture
لا تحذف Billing abstraction الموجودة. غيّر مصدر Premium فقط إلى `source = COINS` واجعل النظام قابلًا للتوسع مستقبلًا. لا تربط Premium مباشرة بواجهة Flutter.

الهدف:
```
Premium Domain → Entitlement → Purchase Source → COINS
```
وفي المستقبل يمكن إضافة مصدر آخر دون إعادة بناء Premium.

## 19. لا تستخدم Real-Money Billing في هذه المهمة
لا تضف: Google Play Billing · Stripe · CMI · PayPal · WhatsApp payment · activation codes — كطريقة شراء Premium في هذه المهمة. Premium الحالي في Pubget يجب أن يعتمد على Coins فقط.

## 20. Acceptance Criteria
لا تعتبر المهمة مكتملة إلا إذا تحققت كل النقاط التالية:

- [ ] Premium لا يزيل الإعلانات.
- [ ] Premium يمكن تفعيله باستخدام Coins.
- [ ] لا يوجد شراء Premium بأموال حقيقية في هذا المسار.
- [ ] تكلفة الخطط محددة server-side.
- [ ] السعر مبني على تحليل Economy وليس رقمًا عشوائيًا.
- [ ] تم تحليل مصادر Coins الحالية.
- [ ] تم تحليل معدل الكسب للمستخدم العادي.
- [ ] تم توثيق assumptions إذا لم توجد بيانات حقيقية كافية.
- [ ] Coin deduction server-side.
- [ ] Premium activation server-side.
- [ ] العملية atomic.
- [ ] العملية idempotent.
- [ ] Ledger entry موجود لكل عملية.
- [ ] لا يمكن للعميل تحديد سعر Premium.
- [ ] لا يمكن للمستخدم الحصول على Premium دون دفع Coins المطلوبة.
- [ ] انتهاء Premium يعمل.
- [ ] Lifetime، إن كان موجودًا، يعمل بشكل صحيح.
- [ ] لا توجد ثغرة double-spend.
- [ ] لا توجد ثغرة double activation.
- [ ] Flutter UI يعرض السعر بالـCoins.
- [ ] Flutter UI يعرض الرصيد.
- [ ] لا يوجد نص يوحي بأن Premium يزيل الإعلانات.
- [ ] لا توجد بيانات وهمية.
- [ ] الاختبارات الحالية لا تنكسر.

---

## تعليمات المالك النهائية (المسجلة حرفيًا)

> "الان لا تقوم بتنفيذ اي شيء فقط قم بحفظ كل شيء وكل شيء في وثيقه ترجع عليها لي في كل مره وقم بحفظ وتبني كل المعطيات التي تمت اعطائها لك وارجوك لا يعني الي تدوخ يعني ولا تقوم لا تقوم ارجوك يعني لا تقوم بان تتلف كل شيء في موضوع التغيير تغيير الوحيد امام كل ما تبقى فيبقى كما هو"

**الفهم المسجل:** لا تنفيذ الآن. حفظ كامل للمعطيات. العودة للوثيقة في كل مرة قبل أي عمل. التغيير الوحيد المصرّح به (عند تنفيذه) هو Premium ← Coins. كل ما عدا ذلك يبقى كما هو.