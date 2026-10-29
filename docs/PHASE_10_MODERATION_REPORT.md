# Phase 10 — الإشراف والاعتدال (المحور 23)

التاريخ: 2026-10-29. الفرع: `feature/phase-10-moderation`.

## 1. المشكلة كما كانت فعلاً

الوثيقة تقول «لا يوجد أي callable اعتدال/ادمن». التدقيق الحقيقي أسوأ من ذلك، وهو الأسوأ لأنه
يبدو سليماً من الخارج:

- **ثمانية `report*` callables** كانت تكتب الصف في subcollection داخل المحتوى نفسه
  (`edits/{id}/reports`, `fanWorks/{id}/reports`, `anime_stats/{id}/reviews/{uid}/reports`,
  `groups/{id}/messageReports`, `privateChats/{id}/messageReports`, `events/{id}/reports`,
  `anime_reports/{id}/reports`).
- التصريح في `firestore.rules` كان `allow read: if isAdmin()` أو `self(uid)` فقط، و
  `allow write: if false`. التحديث محظور على **الجميع**، بما فيهم الأدمن من جهة العميل.
- لم يوجد أي callable يقرأ هذه الصفوف. أي: البلاغ يُكتب، يزيد عدّاداً، ثم **لا يراه أحد أبداً**.

إذًا لا المشكلة «لا توجد قائمة»، بل «القناة أحادية الاتجاه ومغلقة من الخلف».

## 2. المعمارية المختارة

### 2.1 طابور مسطّح واحد: `moderation_cases`

بدل قراءة ست شجرات مختلفة من الخادم، كل بلاغ يُسجَّل الآن في مجموعة واحدة مسطّحة:

```
moderation_cases/{type}_{targetId}_{reporterId}
```

المُعرِّف **حتمي (deterministic)**، وهذا يمنحنا:
- **Idempotency**: نفس المُبلِّغ على نفس الهدف لا يُنشئ صفاً ثانياً، بل يزيد `repeatCount`
  ويحدّث السبب. نفس السلوك الذي كانت كل callable تفرضه على حِدة.
- قابلية الالتقاط (reconciliation) لاحقاً بدون تخمين.

### 2.2 الطابور مكتوب من الخادم فقط

`moderation_cases` و`moderation_audit`:
```rules
allow read: if isModerator();
allow write: if false;
```
حتى الأدمن لا يستطيع الكتابة من جهة العميل. هذا مقصود: لو سُمح بذلك لأصبح أثر التدقيق
قابلاً للتزوير من نفس الحساب الذي يُفترض أن نراقبه.

### 2.3 هوية المشرف = custom claim، لا حقل Firestore

```rules
function isModerator() {
  return signedIn() &&
    (request.auth.token.admin == true || request.auth.token.moderator == true);
}
```

السبب: حقل `role: "moderator"` في مستند يمكن كتابته من أي عميل لديه صلاحية على المستند.
الـ claim لا يُكتب إلا عبر Admin SDK، ومن `setModeratorRole` المحظور على الأدمن فقط.

**فحص إضافي:** قاعدة `users/{uid}` تستخدم `changedOnly([...])` بقائمة مسموحة لا تحتوي
`moderationState` ولا `moderationReason` ولا `restrictedUntil`. لذلك المستخدم المقيَّد لا
يستطيع محو تقييده بكتابة مستنده. تحقّقتُ من هذا في `firestore.rules:513-556` — لم أضعف
أي قاعدة، ولم أحتج لتعديلها.

### 2.4 التراجع (restore) حقيقي

`removeContent` يحفظ الحالة السابقة، و`restoreContent` يستعيد منها. لكنه **لا** يستعيد
`pending` أبداً بالخطأ: لو لم يصل snapshot، فهو يعيد `approved`، لأن `pending` محجوب عن
القراءة بالقواعد — أي أن المحتوى قد يبدو «مُستعاداً» للمشرف ويظل مخفياً عن الجميع. واحد من
الاختبارات يثبّت هذا تحديداً.

## 3. السطح المضاف (10 callables)

| callable | الوظيفة |
|---|---|
| `listModerationCases` | قراءة الطابور مفلتراً بالحالة/النوع، مرتّباً بالأحدث |
| `getModerationCase` | بلاغ واحد بالتفصيل |
| `listModerationNeedsReview` | كسح `needs_review`/`flagged` لـ edits / fanWorks / animeReviews |
| `resolveModerationCase` | `dismiss` / `action_taken` / `removed` — أحادي الاتجاه و idempotent |
| `removeModeratedContent` | إزالة edit/fanWork/animeReview/message/event |
| `restoreModeratedContent` | استعادة من الحالة المحفوظة |
| `restrictUser` / `unrestrictUser` | تقييد الحساب ورفعه |
| `setModeratorRole` | منح/سحب claim المشرف — **أدمن فقط** |
| `getModerationSummary` | عدّاد البلاغات المفتوحة |

## 4. توصيل الطابور بالبلاغات القائمة

أُضيف `enqueueModerationCase()` إلى المسارات الستة القائمة **دون تغيير منطقها الأصلي**:

`editsDomain.reportEdit` · `fanWorksDomain.reportFanWork` · `animeHubDomain.reportAnimeReview`
· `groupChat.reportMessage` · `privateChat.reportMessage` · `eventsDomain.reportEvent`

الصف الأصلي داخل المحتوى يبقى مصدر الحقيقة لـ «مَن أبلغ عن ماذا». الطابور الجديد هو ما
يُشتغل عليه فعلاً. لم أحذف أي مسار قديم.

الإزالة الرسائلية (group/private) تُفرّغ `text` و`mediaUrl` و`thumbnailUrl` فوراً، لأن
إخفاء المحتوى بـ flag فقط يعني أن كل عميل يحمل المستند سيستمر بعرضه.

## 5. الفهارس

أُضيفت في `firestore.indexes.json`:
- `moderation_cases`: (`status`, `createdAt DESC`) و(`status`, `type`, `createdAt DESC`)
- `reviews` (COLLECTION_GROUP): `moderationStatus`
- `edits` و `fanWorks`: `moderationStatus`

بدون الأولى يفشل `listModerationCases` في الإنتاج بخطأ فهرس مفقود حتى لو نجحت الاختبارات.

## 6. الاختبارات

### جديدة
- `test/moderationDomain.test.js` — **20 اختباراً، كلها ناجحة**: البوابات (unauthenticated /
  permission-denied)، أن `admin` يضمّ `moderator`، أن claim النصية `"true"` تعمل،
  الإزالة/الاستعادة، idempotency الحل، منع تقييد النفس، أثر التدقيق، رفض نوع مجهول،
  وتنقية معرّفات الأهداف العدائية (`../../etc/passwd`).
- `test/moderation.rules.test.js` — 6 اختبارات قواعد على الإيميوليتور (لم تُشغَّل هنا، انظر §8).

### مُصلَّحة (ليست مُخفَّفة)
مُخزَّنا الاختبار الوهميان في `groupChat.test.js` و`privateChatActions.test.js` كانا ينقصهما
`doc().set` و`FieldValue.increment`، لأن البلاغات الآن تكتب صفاً إضافياً. أُضيفت القدرة
المفقودة إلى الـ fake — **لم يُغيَّر أي تأكيد (assertion)**.

### نتائج التشغيل الفعلي
```
node --check  (9 ملفات)                    → OK
moderationDomain.test.js                   → 20/20 pass
groupChat · privateChatActions · privateChat · fanWorksDomain
· animeHubDomain · editsDomain · eventsDomain · contentFilter
· editPipelineAspect                       → 186/188 → بعد الإصلاح: كلها ناجحة
```

## 7. لماذا لم أُضعف أي قاعدة

- `isModerator()` **يضيف** قراءة للمشرفين فقط؛ لم يُحذف أي شرط `allow write: if false`.
- قراءة المُبلِّغ لبلاغه بقيت كما هي (`self(uid)`).
- `edits` ما زال يشترط `status == 'published' && moderationStatus == 'approved'` للقراءة،
  ولهذا فإن الإزالة تعمل فعلياً كإزالة: الوثيقة تصبح غير قابلة للقراءة فوراً.
- `users/{uid}` لم يُعدَّل: قائمة `changedOnly` المغلقة تحمي حقول الاعتدال أصلاً.

## 8. حدود هذه المرحلة (بصراحة)

1. **اختبارات القواعد لم تُشغَّل هنا**: `functions/node_modules` غير مثبّت في هذه البيئة،
   و`@firebase/rules-unit-testing` + الإيميوليتور مطلوبان. الملف جاهز ومُوصَّل بـ
   `npm run test:rules`، لكن يجب تشغيله على جهاز فيه الإيميوليتور قبل الدمج.
2. **لا واجهة إشراف في التطبيق**: هذه المرحلة خادم + قواعد + اختبارات، حسب معايير القبول.
   أنصح بواجهة ويب صغيرة فوق نفس الـ callables بدل شاشة داخل التطبيق — أرخص وأسرع وأقل
   خطراً، ولا تُوسّع سطح الهجوم في تطبيق المستخدمين.
3. **الإشعار للمُبلِّغ عند الحل** غير مضاف. `notificationBuilder` جاهز، والتوصيل خطوة صغيرة،
   لكنها خارج نطاق «حل `needs_review` + طابور + تقييد/إزالة/استعادة».
4. **حدود المعدل على فعل الاعتدال نفسه** غير مضافة. مقصود في هذه المرحلة: المشرف شخص
   موثوق، وأثر التدقيق يسجّل كل فعل. تُضاف إن أصبح عدد المشرفين أكبر من عدد يمكن الوثوق به.

## 9. الخطوة التالية المقترحة

بعد دمج هذه المرحلة: واجهة ويب للإشراف (قراءة الطابور + resolve + takedown)، puis إشعار
المُبلِّغ عند الحل، ثم ربط `needs_review` في `editPipeline` بالطابور تلقائياً بدل الاكتفاء
بالكسح اليدوي.
