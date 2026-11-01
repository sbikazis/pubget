# تقرير معالجة أخطاء Firebase العابرة (internal / unavailable)

## 1) وصف المشكلة

كان المستخدمون يواجهون رسائل خطأ غير مفهومة باللغة الإنجليزية أو نصوص تقنية خام عند تنفيذ عمليات إنشاء متكررة أو إجراءات عادية داخل التطبيق، مثل:

- `internal`
- `unavailable`
- رسائل Stack-style أو نصوص من Firebase Storage.

وكانت هذه الأخطاء تظهر بشكل خاص عند تكرار العمليات (إعادة الضغط على زر، أو إعادة المحاولة بعد انقطاع بسيط في الشبكة)، وبدون أي إعادة محاولة تلقائية للعمليات العابرة.

## 2) الأسباب الجذرية

1. **تسريب الأخطاء الخام إلى الواجهة**: كان معظم مُحوِّلات الاستثناءات داخل المستودعات ينتهي بمسار احتياطي يمرر النص الخام مباشرة، على شكل:
   - `UnknownError(error.toString())`
   - `UnknownError(error.message ?? ...)`
   ممّا جعل أكواد Firebase مثل `internal` و`unavailable` تصل للمستخدم كنص تقني.
2. **غياب إعادة المحاولة للأخطاء العابرة**: لم تكن أخطاء مثل `unavailable` و`deadline-exceeded` و`internal` تُعاد محاولتها، فتفشل العملية من أول مرة رغم أنها قابلة للنجاح عند إعادة المحاولة.
3. **التوافق مع الإصدارات**: بعض الأخطاء تُبلغ بقيم `cancelled` أو `canceled` أو `aborted` أو `data-loss` ولم تكن مُغطّاة.

## 3) الحل المطبَّق

### أ) وحدة توجيه مركزية

أُضيفت وحدة `mapFirebaseFailure(Object error, {String? message})` في:

- `lib/core/errors/firebase_failure_mapper.dart`

وهي تضمن **عدم كشف أي نص خام** مطلقاً، وتوحّد الترجمة بين أنواع الأخطاء:

| كود Firebase | نوع الفشل الناتج | قابل لإعادة المحاولة |
| --- | --- | --- |
| `internal` / `unknown` / `aborted` / `data-loss` | `UnavailableError` | نعم |
| `unavailable` / `deadline-exceeded` / `network-request-failed` | `NetworkError` | نعم |
| `resource-exhausted` / `quota-exceeded` / `too-many-requests` | `RateLimitedError` | نعم |
| `unauthenticated` | `PermissionError` | لا |
| `permission-denied` | `PermissionError` / `UnknownError` حسب الميزة | لا |
| `cancelled` / `canceled` | `CancelledError` | لا |
| `not-found` | `NotFoundError` | لا |
| `invalid-argument` / `failed-precondition` / `already-exists` | `ValidationError` | لا |

### ب) إعادة محاولة مع Backoff

أُضيفت أدوات في:

- `lib/core/errors/retry.dart`
  - `isTransientFailure(Failure)` لتصنيف الأخطاء العابرة.
  - `runWithRetry(action, {required mapError, maxAttempts, delay})` بإعادة محاولة افتراضية **٣ مرات** مع تأخير متصاعد `300ms → 900ms → 2200ms`.

### ج) التطبيق على المستودعات

طُبِّق التوجيه المركزي (وفي الحالات المناسبة الإعادة التلقائية) على المستودعات التالية:

- `lib/features/groups/repositories/firebase_group_repositories.dart`
- `lib/features/groups/repositories/group_catalog_repository.dart`
- `lib/features/groups/repositories/firebase_chat_repository.dart`
- `lib/features/private_chat/repositories/firebase_private_chat_repository.dart`
- `lib/features/events/repositories/firebase_event_repository.dart`
- `lib/features/games/repositories/firebase_game_repository.dart`
- `lib/features/mafia/repositories/firebase_mafia_repository.dart`
- `lib/features/fan_works/repositories/firebase_fan_work_repository.dart`
- `lib/features/economy/repositories/firebase_economy_repository.dart`
- `lib/features/edits/repositories/firebase_edits_repository.dart`
- `lib/features/achievements/repositories/firebase_achievement_repository.dart`
- `lib/features/anime/repositories/firebase_anime_library_repository.dart`
- `lib/features/anime/repositories/firebase_anime_hub_social_repository.dart`
- `lib/features/notifications/repositories/firebase_notification_repository.dart`
- `lib/features/social/repositories/firebase_profile_repository.dart`
- `lib/features/social/repositories/firebase_social_repository.dart`
- `lib/features/authentication/repositories/firebase_user_repository.dart`
- `lib/features/home/repositories/firebase_home_repository.dart`
- `lib/features/home/repositories/discovery_errors.dart`
- `lib/features/reels/repositories/firebase_audio_repository.dart`

## 4) قرارات تصميمية مهمة

- **استُثنيت مستودعات المحادثة من الإعادة التلقائية** عمداً (`firebase_chat_repository.dart` و`firebase_private_chat_repository.dart`)، لأن إرسال الرسائل يملك طبقة إعادة محاولة خاصة في `chat_send_reliability.dart`، ولأن إعادة الإرسال العشوائية قد تُبرز أخطاء `already-exists` كأخطاء تحقّق. تمّ الاكتفاء بتصحيح توجيه الأخطاء ومنع التسريب.
- **لم تُغيَّر دلالات توجيه المصادقة** في `firebase_auth_repository.dart` لأن سلوكها مرتبط بتجربة تسجيل الدخول ومُثبَّت باختبارات دقيقة.
- عند إعادة المحاولة داخل `search` في المستودع الرئيسي، أُعيد بناء استعلامات Firestore داخل دالة الإعادة لضمان أن المحاولة الثانية تُنفَّذ فعلياً من جديد.

## 5) التحقق

- `dart analyze lib`: **لا مشاكل**.
- اختبارات التوجيه المستهدفة: **نجحت ١٩/١٩**:
  - `test/discovery_error_mapping_test.dart`
  - `test/edits_pipeline_hardening_test.dart`
  - `test/auth_failure_mapping_test.dart`

## 6) متابعات مقترحة (خارج نطاق هذا التغيير)

- إضافة حمايات منع الإرسال المزدوج (double-submit guards) في بعض الشاشات: تعليقات Fan Works، صداقة/حظر Social، تعليم الإشعارات كمقروءة، قوائم Anime المخصّصة.
- مراجعة العمليات التي تُنشئ Auto-ID (مثل حفظ المسوّدات والتعليقات) لتقليل خطر التكرار عند إعادة المحاولة.
