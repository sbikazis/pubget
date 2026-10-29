import 'package:flutter/widgets.dart';

import '../../../core/l10n/app_strings.dart';

/// Localized copy for Settings → Guide.
///
/// The guide used to be hardcoded English — including a raw app route in the
/// call-to-action ("Open /groups"). Both are fixed here: chrome resolves
/// through [AppStrings], and each [GuideTopic] carries an English/Arabic pair
/// so the body text is translated while staying searchable in either locale.
final class GuideCopy {
  const GuideCopy(this._s);

  final AppStrings _s;

  static GuideCopy of(BuildContext context) =>
      GuideCopy(AppStrings.of(context));

  static GuideCopy forLocale(Locale? locale) =>
      GuideCopy(AppStrings.forLocale(locale));

  String get title => _s.pick('Guide', 'الدليل');
  String get searchHint => _s.pick('Search the guide', 'ابحث في الدليل');
  String get emptyTitle => _s.pick('No matching topics', 'لا توجد مواضيع مطابقة');
  String get emptyMessage => _s.pick(
    'Try a different word, like groups or Respect.',
    'جرّب كلمة أخرى، مثل المجموعات أو الاحترام.',
  );
  String get clearSearch => _s.pick('Clear search', 'مسح البحث');
  String get clearSearchSemantic =>
      _s.pick('Clear guide search', 'مسح بحث الدليل');

  /// Call-to-action for a topic that links somewhere. Deliberately generic so
  /// the internal route path is never shown to the member.
  String get openLabel => _s.pick('Open', 'فتح');

  String topicTitle(GuideTopic topic) => topic.title(_s);
  String topicBody(GuideTopic topic) => topic.body(_s);

  List<GuideTopic> get topics => GuideTopic.all;
}

final class GuideTopic {
  const GuideTopic({
    this.route,
    required this.titleEn,
    required this.titleAr,
    required this.bodyEn,
    required this.bodyAr,
  });

  final String? route;
  final String titleEn;
  final String titleAr;
  final String bodyEn;
  final String bodyAr;

  String title(AppStrings s) => s.pick(titleEn, titleAr);
  String body(AppStrings s) => s.pick(bodyEn, bodyAr);

  static const all = <GuideTopic>[
    GuideTopic(
      titleEn: 'Groups',
      titleAr: 'المجموعات',
      bodyEn:
          'Groups are communities. Open a group to chat if you are a member, '
          'or read details first if you are not.',
      bodyAr:
          'المجموعات مجتمعات. افتح مجموعة للدردشة إذا كنت عضواً، أو اطّلع على '
          'التفاصيل أولاً إن لم تكن كذلك.',
      route: '/groups',
    ),
    GuideTopic(
      titleEn: 'Chat',
      titleAr: 'الدردشة',
      bodyEn:
          'Group chat supports text, media, replies, and delivery colors: '
          'red failed, yellow delivered, green read.',
      bodyAr:
          'دردشة المجموعة تدعم النصوص والوسائط والردود وألوان التسليم: '
          'أحمر فشل، أصفر تم التسليم، أخضر تمت القراءة.',
    ),
    GuideTopic(
      titleEn: 'Roles',
      titleAr: 'الرتب',
      bodyEn:
          'Roles are group-scoped. You can be Shogun in one group and a '
          'Member in another. Permissions stay explicit.',
      bodyAr:
          'الرتب مرتبطة بكل مجموعة على حدة. يمكنك أن تكون شوغون في مجموعة '
          'وعضواً في أخرى. تبقى الصلاحيات واضحة.',
    ),
    GuideTopic(
      titleEn: 'Roleplay',
      titleAr: 'تقمّص الأدوار',
      bodyEn:
          'Roleplay identity is separate from your global username. Pubget '
          'never silently assigns a character — you choose.',
      bodyAr:
          'هوية تقمّص الأدوار منفصلة عن اسمك العام. لا يمنح Pubget شخصية '
          'تلقائياً — أنت من يختار.',
    ),
    GuideTopic(
      titleEn: 'Games',
      titleAr: 'الألعاب',
      bodyEn:
          'Games live in their own domain. Start them from a group, then play '
          'in a dedicated room. Chat shows activity cards, not the game state.',
      bodyAr:
          'الألعاب في مجالها الخاص. ابدأها من مجموعة ثم العب في غرفة مخصصة. '
          'تظهر في الدردشة بطاقات النشاط وليس حالة اللعبة.',
      route: '/games',
    ),
    GuideTopic(
      titleEn: 'Mafia',
      titleAr: 'المافيا',
      bodyEn:
          'Mafia is a private-role game. The server owns timers, roles, and '
          'results. Your client never receives another player’s secret role.',
      bodyAr:
          'المافيا لعبة أدوار سرية. يتولّى الخادم المؤقتات والأدوار والنتائج. '
          'لا يستقبل جهازك دور لاعب آخر السري.',
      route: '/games',
    ),
    GuideTopic(
      titleEn: 'Achievements',
      titleAr: 'الإنجازات',
      bodyEn:
          'Milestones unlock on the server when you create a group, publish, '
          'make a friend, or win. Rewards are granted once.',
      bodyAr:
          'تُفتح الإنجازات على الخادم عند إنشاء مجموعة أو النشر أو تكوين '
          'صداقة أو الفوز. تُمنح المكافآت مرة واحدة.',
      route: '/achievements',
    ),
    GuideTopic(
      titleEn: 'Events',
      titleAr: 'الفعاليات',
      bodyEn:
          'Events are interactive posts such as polls, quizzes, and versus '
          'matchups. They close after at most seven days.',
      bodyAr:
          'الفعاليات منشورات تفاعلية مثل الاستطلاعات والمسابقات والمواجهات. '
          'تُغلق بعد سبعة أيام كحد أقصى.',
      route: '/events',
    ),
    GuideTopic(
      titleEn: 'Reels',
      titleAr: 'الريلز',
      bodyEn:
          'Reels are short videos, not a photo gallery. Views count only after '
          'real watch time — opening a page is not a view.',
      bodyAr:
          'الريلز مقاطع فيديو قصيرة وليست معرض صور. تُحتسب المشاهدات بعد '
          'وقت مشاهدة حقيقي — مجرد فتح الصفحة ليس مشاهدة.',
      route: '/edits',
    ),
    GuideTopic(
      titleEn: 'Respect and Fans',
      titleAr: 'الاحترام والمعجبون',
      bodyEn:
          'Respect is social currency you give. Five or more Respect can become '
          'a Fan relationship. A Fan is not the same as a Friend.',
      bodyAr:
          'الاحترام عملة اجتماعية تمنحها. خمسة احترامات أو أكثر قد تتحول إلى '
          'علاقة معجب. المعجب ليس بالضرورة صديقاً.',
    ),
    GuideTopic(
      titleEn: 'Friends',
      titleAr: 'الأصدقاء',
      bodyEn:
          'Friend requests can be sent, accepted, rejected, cancelled, or '
          'removed. Blocking has real effects on messaging and discovery.',
      bodyAr:
          'يمكن إرسال طلبات الصداقة وقبولها أو رفضها أو إلغاؤها أو إزالتها. '
          'للحظر آثار حقيقية على المراسلة والاكتشاف.',
      route: '/friend-requests',
    ),
    GuideTopic(
      titleEn: 'Anime Hub',
      titleAr: 'مركز الأنمي',
      bodyEn:
          'Discover current, upcoming, trending, and seasonal anime. Save lists '
          'and favorites without leaking API details into the rest of the app.',
      bodyAr:
          'اكتشف الأنمي الحالي والقادم والرائج والموسمي. احفظ القوائم '
          'والمفضلات دون تسريب تفاصيل الواجهة إلى بقية التطبيق.',
      route: '/anime',
    ),
    GuideTopic(
      titleEn: 'Fan Works',
      titleAr: 'أعمال المعجبين',
      bodyEn:
          'Share manga, drawings, stories, and worlds with creator attribution. '
          'Reports and copyright complaints go to moderation.',
      bodyAr:
          'شارك المانغا والرسومات والقصص والعوالم مع نسبة العمل لأصحابه. تصل '
          'الإبلاغات وشكاوى حقوق النشر إلى فريق الإشراف.',
      route: '/fan-works',
    ),
    GuideTopic(
      titleEn: 'Coins and Store',
      titleAr: 'العملات والمتجر',
      bodyEn:
          'Coins come from meaningful participation, never spam. The Store is '
          'digital: cosmetics and extensions. Coins cannot remove ads.',
      bodyAr:
          'تُكسب العملات من المشاركة الحقيقية لا من الإزعاج. المتجر رقمي: '
          'مظاهر وإضافات. لا يمكن للعملات إزالة الإعلانات.',
      route: '/store',
    ),
    GuideTopic(
      titleEn: 'Premium',
      titleAr: 'النسخة المميزة',
      bodyEn:
          'Premium can add a badge, cosmetics, and extra limits. It is not '
          'pay-to-win, and the free app stays usable.',
      bodyAr:
          'تضيف النسخة المميزة شارة ومظاهر وحدوداً إضافية. ليست دفعاً مقابل '
          'الفوز، ويبقى التطبيق المجاني قابلاً للاستخدام.',
      route: '/premium',
    ),
    GuideTopic(
      titleEn: 'Privacy',
      titleAr: 'الخصوصية',
      bodyEn:
          'Profile, activity, and messaging visibility are real settings with '
          'server enforcement. Hidden profiles stay out of Search.',
      bodyAr:
          'ظهور الملف والنشاط والمراسلة إعدادات حقيقية مُطبَّقة على الخادم. '
          'الملفات المخفية لا تظهر في البحث.',
      route: '/profile/edit',
    ),
    GuideTopic(
      titleEn: 'Moderation',
      titleAr: 'الإشراف',
      bodyEn:
          'Report content, mute or restrict in groups, and block users. '
          'Blocking is not just a hidden button.',
      bodyAr:
          'أبلِغ عن المحتوى، واكتم أو قيّد داخل المجموعات، واحظر المستخدمين. '
          'الحظر ليس مجرد زر مخفي.',
    ),
  ];
}
