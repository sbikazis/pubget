import 'package:flutter/widgets.dart';

/// Single source of truth for every Anime Hub string.
///
/// Nothing in the Anime feature is allowed to hardcode Arabic or English
/// copy: each catalog term is looked up in one of the named maps below and
/// each piece of UI chrome is exposed as a getter on this class. Lookups are
/// locale driven, so switching the app language re-renders the whole hub.
///
/// API payloads (original titles, Japanese names, MAL ids) are never
/// translated, they are passed through untouched. Unknown keys also pass
/// through so a newly added Jikan tag stays visible instead of disappearing.
final class AppTranslationMapping {
  AppTranslationMapping._(this.locale, this._ar) {
    genreMap = _ar
        ? const <String, String>{
            'action': 'أكشن',
            'adventure': 'مغامرة',
            'avant garde': 'طليعي',
            'award winning': 'حائز على جوائز',
            'comedy': 'كوميديا',
            'drama': 'دراما',
            'fantasy': 'فانتازيا',
            'gourmet': 'طعام',
            'historical': 'تاريخي',
            'horror': 'رعب',
            'mystery': 'غموض',
            'romance': 'رومانسية',
            'sci-fi': 'خيال علمي',
            'sci fi': 'خيال علمي',
            'science fiction': 'خيال علمي',
            'slice of life': 'شريحة من الحياة',
            'sports': 'رياضة',
            'supernatural': 'خارق',
            'suspense': 'إثارة',
            'thriller': 'إثارة',
            'adult cast': 'طاقم بالغ',
            'anthropomorphic': 'مجسّم',
            'cgdct': 'فتيات لطيفات',
            'childcare': 'رعاية أطفال',
            'combat sports': 'رياضات قتالية',
            'delinquents': 'منحرفون',
            'detective': 'تحقيق',
            'educational': 'تعليمي',
            'gag humor': 'كوميديا سريعة',
            'gore': 'دموي',
            'harem': 'حريم',
            'high stakes game': 'لعبة عالية المخاطر',
            'idols (female)': 'آيدول (إناث)',
            'idols (male)': 'آيدول (ذكور)',
            'isekai': 'إيسكاي',
            'iyashikei': 'إياشيكي',
            'love polygon': 'مثلث حب',
            'magical sex shift': 'تحول سحري',
            'mahou shoujo': 'فتاة سحرية',
            'martial arts': 'فنون قتالية',
            'mecha': 'ميكا',
            'medical': 'طبي',
            'military': 'عسكري',
            'music': 'موسيقى',
            'mythology': 'أساطير',
            'organized crime': 'جريمة منظمة',
            'otaku culture': 'ثقافة الأوتاكو',
            'parody': 'محاكاة ساخرة',
            'performing arts': 'فنون أدائية',
            'pets': 'حيوانات أليفة',
            'psychological': 'نفسي',
            'racing': 'سباق',
            'reincarnation': 'تناسخ',
            'reverse harem': 'حريم عكسي',
            'romantic subtext': 'إيحاء رومانسي',
            'samurai': 'ساموراي',
            'school': 'مدرسي',
            'showbiz': 'عرض فني',
            'space': 'فضاء',
            'strategy game': 'لعبة استراتيجية',
            'super power': 'قوى خارقة',
            'survival': 'بقاء',
            'team sports': 'رياضات جماعية',
            'time travel': 'سفر عبر الزمن',
            'urban fantasy': 'فانتازيا حضرية',
            'vampire': 'مصاص دماء',
            'video game': 'لعبة فيديو',
            'villainess': 'شريرة',
            'visual arts': 'فنون بصرية',
            'workplace': 'مكان عمل',
            'boys love': 'حب فتيان',
            'girls love': 'حب فتيات',
            'ecchi': 'إيتشي',
            'erotica': 'إروتيكا',
            'hentai': 'هنتاي',
            'josei': 'جوسي',
            'kids': 'أطفال',
            'seinen': 'سينين',
            'shoujo': 'شوجو',
            'shounen': 'شونين',
          }
        : const <String, String>{};
    statusMap = _ar
        ? const <String, String>{
            'finished airing': 'مكتمل',
            'finished': 'مكتمل',
            'currently airing': 'يُعرض حالياً',
            'airing': 'يُعرض حالياً',
            'not yet aired': 'لم يبدأ العرض',
            'upcoming': 'قادم',
            'canceled': 'ملغى',
            'cancelled': 'ملغى',
            'paused': 'متوقف مؤقتاً',
            'plan to watch': 'أرغب بمشاهدتها',
            'watching': 'أشهدها حالياً',
            'completed': 'تم مشاهدتها',
            'plan to watch later': 'أكملها لاحقاً',
            'dropped': 'لا أرغب بمشاهدتها',
            'on hold': 'معلّق',
            'favorites': 'المفضلة',
          }
        : const <String, String>{};
    listStatusMap = _ar
        ? const <String, String>{
            'want_to_watch': 'أرغب بمشاهدتها',
            'watching': 'أشاهدها حالياً',
            'completed': 'تم مشاهدتها',
            'watch_later': 'أكملها لاحقاً',
            'not_interested': 'لا أرغب بمشاهدتها',
          }
        : const <String, String>{
            'want_to_watch': 'Want to watch',
            'watching': 'Watching',
            'completed': 'Completed',
            'watch_later': 'Watch later',
            'not_interested': 'Not interested',
          };
    sourceMap = _ar
        ? const <String, String>{
            'manga': 'مانغا',
            'light novel': 'رواية خفيفة',
            'novel': 'رواية',
            'original': 'أصلي',
            'visual novel': 'رواية بصرية',
            'web manga': 'مانغا ويب',
            'web novel': 'رواية ويب',
            'game': 'لعبة',
            'card game': 'لعبة بطاقات',
            'book': 'كتاب',
            'picture book': 'كتاب مصور',
            'music': 'موسيقى',
            'radio': 'راديو',
            'tv': 'تلفزيون',
            'movie': 'فيلم',
            'other': 'أخرى',
            'unknown': 'غير معروف',
          }
        : const <String, String>{};
    ageRatingsMap = _ar
        ? const <String, String>{
            'g': 'جميع الأعمار',
            'g - all ages': 'جميع الأعمار',
            'all ages': 'جميع الأعمار',
            'pg': 'إشراف أولياء الأمور',
            'pg - children': 'مناسب للأطفال',
            'pg - children 10 and older': 'مناسب للأطفال من 10 سنوات فأكثر',
            'pg-13': '13+ مراهقون',
            'pg-13 - teens 13 or older': '13+ مراهقون',
            'pg-13 - teens 13 or older (explicit nudity)':
                '13+ مراهقون (عري صريح)',
            'r': '17+',
            'r - 17+ (mild nudity)': '17+ (عري خفيف)',
            'r+ - mild nudity': '17+ (عري خفيف)',
            'r - 17+ (explicit nudity)': '17+ (عري صريح)',
            'rx': '18+ بالغين',
            'rx - adult': '18+ بالغين',
            'none': 'بدون تصنيف',
          }
        : const <String, String>{};
    seasonMap = _ar
        ? const <String, String>{
            'winter': 'شتاء',
            'spring': 'ربيع',
            'summer': 'صيف',
            'fall': 'خريف',
            'autumn': 'خريف',
          }
        : const <String, String>{};
    characterAttributeMap = _ar
        ? const <String, String>{
            'age': 'العمر',
            'birthday': 'تاريخ الميلاد',
            'birth date': 'تاريخ الميلاد',
            'birthdate': 'تاريخ الميلاد',
            'height': 'الطول',
            'weight': 'الوزن',
            'blood type': 'فصيلة الدم',
            'bloodtype': 'فصيلة الدم',
            'hair color': 'لون الشعر',
            'eye color': 'لون العينين',
            'gender': 'الجنس',
            'species': 'الفصيلة',
            'race': 'الفصيلة',
            'affiliation': 'الانتماء',
            'occupation': 'المهنة',
            'nickname': 'اللقب',
            'nicknames': 'الألقاب',
            'arabic': 'الاسم العربي',
            'arabic name': 'الاسم العربي',
            'english': 'الاسم الإنجليزي',
            'english name': 'الاسم الإنجليزي',
            'japanese name': 'الاسم الياباني',
            'rank': 'الرتبة',
            'ranked': 'الترتيب',
            'likes': 'المفضلات',
            'dislikes': 'غير المفضلات',
            'sign': 'البروج',
            'family': 'العائلة',
            'also known as': 'يُعرف أيضًا بـ',
            'status': 'الحالة',
            'statuses': 'الحالات',
            'residency': 'الإقامة',
            'residencies': 'الإقامات',
            'devil fruit': 'فاكهة الشيطان',
            'zoro\'s crew': 'طاقم زورو',
            'love interest': 'الشخصية المحبوبة',
            'seiyuu': 'الصوت',
            'favorite': 'المفضلة',
            'male': 'ذكر',
            'female': 'أنثى',
            'non-binary': 'غير ثنائي',
            'human': 'بشري',
            'non-human': 'غير بشري',
            'humanoid': 'بشري الشكل',
            'demon': 'شيطان',
            'demons': 'شياطين',
            'god': 'إله',
            'gods': 'آلهة',
            'alien': 'كائن فضائي',
            'robot': 'روبوت',
            'android': 'روبوت',
            'spirit': 'روح',
            'youkai': 'يوكاي',
            'dragon': 'تنين',
            'beast': 'وحش',
            'beasts': 'وحوش',
            'sage': 'حكيم',
            'unkown': 'غير معروف',
            'unknown': 'غير معروف',
            'black': 'أسود',
            'brown': 'بني',
            'light brown': 'بني فاتح',
            'blond': 'أشقر',
            'blonde': 'أشقر',
            'blond hair': 'أشقر',
            'blue': 'أزرق',
            'green': 'أخضر',
            'red': 'أحمر',
            'white': 'أبيض',
            'silver': 'فضي',
            'pink': 'وردي',
            'orange': 'برتقالي',
            'purple': 'بنفسجي',
            'grey': 'رمادي',
            'gray': 'رمادي',
            'calico': 'ثلاثي الألوان',
            'a': 'A',
            'b': 'B',
            'ab': 'AB',
            'o': 'O',
            'years old': 'سنة',
            'year old': 'سنة',
            'months old': 'شهر',
            'cm': 'سم',
            'kg': 'كجم',
            'time-wise ranking': 'ترتيباً زمنياً',
            'time wise ranking': 'ترتيباً زمنياً',
            'this season': 'هذا الموسم',
            'overall ranking': 'الترتيب العام',
            'ranking': 'الترتيب',
          }
        : const <String, String>{};
    formatMap = _ar
        ? const <String, String>{
            'tv': 'تلفزيون',
            'tv special': 'تلفزيون خاص',
            'tv short': 'تلفزيون قصير',
            'movie': 'فيلم',
            'ova': 'أوفا',
            'ona': 'أونا',
            'special': 'خاص',
            'music': 'موسيقى',
            'pv': 'إعلان',
            'cm': 'إعلان',
            'unknown': 'غير معروف',
          }
        : const <String, String>{};
    relationMap = _ar
        ? const <String, String>{
            'sequel': 'تكملة',
            'prequel': 'ما قبل',
            'parent story': 'القصة الأم',
            'side story': 'قصة جانبية',
            'spin-off': 'عمل متفرّع',
            'alternative setting': 'إعداد بديل',
            'alternative version': 'نسخة بديلة',
            'full story': 'القصة الكاملة',
            'summary': 'ملخّص',
            'adaptation': 'اقتباس',
            'character': 'شخصية',
            'other': 'أخرى',
            'unknown': 'غير معروف',
          }
        : const <String, String>{};
    roleMap = _ar
        ? const <String, String>{
            'main': 'رئيسية',
            'supporting': 'مساعدة',
            'background': 'من الطاقم',
            'unknown': 'غير معروف',
          }
        : const <String, String>{};
    voiceLanguageMap = _ar
        ? const <String, String>{
            'japanese': 'اليابانية',
            'english': 'الإنجليزية',
            'korean': 'الكورية',
            'chinese': 'الصينية',
            'mandarin': 'الصينية',
            'spanish': 'الإسبانية',
            'french': 'الفرنسية',
            'german': 'الألمانية',
            'italian': 'الإيطالية',
            'portuguese': 'البرتغالية',
            'brazilian': 'البرتغالية',
            'portuguese (br)': 'البرتغالية',
            'arabic': 'العربية',
            'hungarian': 'المجرية',
            'hebrew': 'العبرية',
            'filipino': 'الفلبينية',
            'tagalog': 'الفلبينية',
            'russian': 'الروسية',
            'dutch': 'الهولندية',
            'polish': 'البولندية',
          }
        : const <String, String>{};
    criterionMap = _ar
        ? const <String, String>{
            'story': 'القصة',
            'art': 'الرسم',
            'characters': 'الشخصيات',
            'action': 'أكشن',
            'sound': 'الصوت',
            'enjoyment': 'المتعة',
          }
        : const <String, String>{};
  }

  final Locale locale;
  final bool _ar;

  static final english = AppTranslationMapping._(Locale('en'), false);
  static final arabic = AppTranslationMapping._(Locale('ar'), true);

  static AppTranslationMapping of(BuildContext context) =>
      forLocale(Localizations.localeOf(context));

  static AppTranslationMapping forLocale(Locale? locale) =>
      locale?.languageCode == 'ar' ? arabic : english;

  static AppTranslationMapping forLanguageCode(String? code) =>
      code == 'ar' ? arabic : english;

  bool get isArabic => _ar;

  String pick(String en, String ar) => _ar ? ar : en;

  /// `null` and blanks are returned as an empty string so callers can treat
  /// "field absent" and "field empty" the same way.
  String _lookup(Map<String, String> map, String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return '';
    return map[value.toLowerCase()] ?? value;
  }

  // ---------------------------------------------------------------------------
  // Named catalog maps
  // ---------------------------------------------------------------------------

  /// Jikan genres, themes, demographics and explicit tags.
  /// See [_ar ? 'Arabic' : 'English'] variant, filled in the constructor.
  late final Map<String, String> genreMap;

  /// Airing status of a title, plus the personal list states.
  /// See [_ar ? 'Arabic' : 'English'] variant, filled in the constructor.
  late final Map<String, String> statusMap;

  /// The member's own five personal states, keyed by their wire value.
  /// Unlike [statusMap] this map is never empty in English: these are
  /// interface labels, not API terms, so both sides are spelled out.
  late final Map<String, String> listStatusMap;

  /// Original work the anime is based on.
  /// See [_ar ? 'Arabic' : 'English'] variant, filled in the constructor.
  late final Map<String, String> sourceMap;

  /// Content advisories, matched on the code before the dash when possible.
  /// See [_ar ? 'Arabic' : 'English'] variant, filled in the constructor.
  late final Map<String, String> ageRatingsMap;

  /// Release season.
  /// See [_ar ? 'Arabic' : 'English'] variant, filled in the constructor.
  late final Map<String, String> seasonMap;

  /// Character profile fact labels and their common values, including the
  /// composite forms Jikan returns such as `18 (Human)` or
  /// `> 133 (Time-wise ranking)`.
  /// See [_ar ? 'Arabic' : 'English'] variant, filled in the constructor.
  late final Map<String, String> characterAttributeMap;

  /// Broadcast format.
  /// See [_ar ? 'Arabic' : 'English'] variant, filled in the constructor.
  late final Map<String, String> formatMap;

  /// Story relation to other titles.
  /// See [_ar ? 'Arabic' : 'English'] variant, filled in the constructor.
  late final Map<String, String> relationMap;

  /// Role a character plays inside an anime.
  /// See [_ar ? 'Arabic' : 'English'] variant, filled in the constructor.
  late final Map<String, String> roleMap;

  /// Voice actor language, shown as `Arabic / Japanese` in Arabic.
  /// See [_ar ? 'Arabic' : 'English'] variant, filled in the constructor.
  late final Map<String, String> voiceLanguageMap;

  /// Rating dimensions.
  /// See [_ar ? 'Arabic' : 'English'] variant, filled in the constructor.
  late final Map<String, String> criterionMap;

  // ---------------------------------------------------------------------------
  // Typed lookups
  // ---------------------------------------------------------------------------

  String genre(String? raw) => _lookup(genreMap, raw);

  String status(String? raw) => _lookup(statusMap, raw);

  /// Display name of one of the five personal states.
  String personalState(String? wireValue) => _lookup(listStatusMap, wireValue);

  String source(String? raw) => _lookup(sourceMap, raw);

  String season(String? raw) => _lookup(seasonMap, raw);

  String format(String? raw) => _lookup(formatMap, raw);

  String relation(String? raw) => _lookup(relationMap, raw);

  String role(String? raw) => _lookup(roleMap, raw);

  String criterion(String? raw) => _lookup(criterionMap, raw);

  /// Age advisories arrive as `PG-13 - Teens 13 or older`. Try the full
  /// string, then the code, so both the verbose and short forms localize.
  String ageRating(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return '';
    final exact = ageRatingsMap[value.toLowerCase()];
    if (exact != null) return exact;
    final code = value.split(' - ').first.trim().toLowerCase();
    final byCode = ageRatingsMap[code];
    if (byCode != null) {
      if (_ar) {
        final suffix = value.substring(code.length).trim();
        if (suffix.isNotEmpty) return '$byCode ($suffix)';
      }
      return byCode;
    }
    return value;
  }

  /// Character fact labels, values and compound values.
  ///
  /// `18 (Human)` becomes `18 (بشري)`, `> 133 (Time-wise ranking)` becomes
  /// `> 133 (ترتيباً زمنياً)`, and `Blood type: A` keeps its letter while the
  /// label is localized.
  String characterAttribute(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return '';
    final direct = characterAttributeMap[value.toLowerCase()];
    if (direct != null) return direct;

    final compound = RegExp(
      r'^(.*\((.*)\)|.*\s([A-Za-z][A-Za-z ]*))$',
    ).firstMatch(value);
    if (compound != null) {
      final inner =
          compound.group(2)?.trim() ??
          compound.group(3)?.trim() ??
          compound.group(1)?.trim() ??
          '';
      final prefix = value.substring(0, value.length - inner.length).trim();
      final translated = characterAttributeMap[inner.toLowerCase()];
      if (translated != null && prefix.isNotEmpty) {
        return _ar ? '$prefix ($translated)' : value;
      }
    }
    return value;
  }

  /// `Arabic / Japanese` in Arabic so the source language stays recognizable.
  String voiceLanguage(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return '';
    final localized = voiceLanguageMap[value.toLowerCase()];
    if (localized == null) return value;
    if (_ar) return '$localized / $value';
    return value;
  }

  // ---------------------------------------------------------------------------
  // Hub chrome
  // ---------------------------------------------------------------------------

  String get hubTitle => pick('Anime Hub', 'مركز الأنمي');
  String get latestUpdates => pick('Latest updates', 'آخر التحديثات');
  String get latestUpdatesTitle => pick('Anime Hub', 'مركز الأنمي');
  String get seeAll => pick('See all', 'عرض الكل');
  String get searchHint => pick('Search anime', 'ابحث عن أنمي');
  String get openSearch => pick('Search', 'بحث');
  String get closeSearch => pick('Close search', 'إغلاق البحث');
  String get applyFilters => pick('Apply', 'تطبيق');
  String get resetFilters => pick('Reset', 'إعادة تعيين');
  String get filters => pick('Filters', 'الفلاتر');
  String get resultsCount => pick('Results', 'النتائج');
  String get nothingFound => pick('No Anime Found', 'لا يوجد أنمي');
  String get nothingFoundMessage => pick(
    'Try another title or browse the catalog.',
    'جرّب اسماً آخر أو صفّح الكتالوج.',
  );
  String get unableToLoad =>
      pick('Unable to load anime right now.', 'تعذّر تحميل الأنمي الآن.');
  String get checkConnection => pick(
    'Please check your connection and try again.',
    'تحقق من الاتصال وحاول مرة أخرى.',
  );
  String get retry => pick('Retry', 'إعادة المحاولة');
  String get cachedBanner => pick('Showing cached data', 'عرض بيانات محفوظة');
  String get offlineCached => pick(
    'You are offline. Showing cached data.',
    'أنت غير متصل. عرض بيانات محفوظة.',
  );
  String get genresTitle => pick('Browse by genre', 'تصفح حسب التصنيف');
  String get seasonsTitle => pick('Browse by season', 'تصفح حسب الموسم');
  String get charactersTitle => pick('Characters', 'الشخصيات');
  String get synopsisTitle => pick('Synopsis', 'القصة');
  String get detailsSection => pick('Details', 'التفاصيل');
  String get detailsMissing =>
      pick('This anime could not be found.', 'تعذّر العثور على هذا الأنمي.');
  String get emptyCatalog =>
      pick('Nothing in this list yet.', 'لا شيء في هذه القائمة بعد.');
  String get emptyLibrary => pick('Your list is empty', 'قائمتك فارغة');
  String get charactersEmpty =>
      pick('No favorite characters yet', 'لا توجد شخصيات مفضلة بعد');
  String get endOfList =>
      pick('You have reached the end.', 'وصلت إلى نهاية القائمة.');
  String get favorite => pick('Favorite', 'المفضلة');
  String get favorited => pick('In favorites', 'في المفضلة');
  String get addFavorite => pick('Add to favorites', 'أضف إلى المفضلة');
  String get removeFavorite =>
      pick('Remove from favorites', 'إزالة من المفضلة');
  String get trailer => pick('Trailer', 'الإعلان');
  String get links => pick('External links', 'روابط خارجية');
  String get copied => pick('Link copied', 'تم نسخ الرابط');
  String get share => pick('Share anime', 'مشاركة الأنمي');
  String get shareAnime => pick('Share', 'مشاركة');
  String get reportLabel => pick('Report', 'إبلاغ');
  String get reportTitle => pick('Report this anime', 'الإبلاغ عن هذا الأنمي');
  String get sensitiveContent => pick(
    'This title contains sensitive content.',
    'هذا العنوان يحتوي على محتوى حساس.',
  );
  String get sensitiveContentBody => pick(
    'Check the age rating before browsing the details.',
    'راجع التصنيف العمري قبل تصفح التفاصيل.',
  );
  String get rankLabel => pick('Rank', 'الترتيب');
  String get popularityLabel => pick('Popularity', 'الشعبية');
  String get membersLabel => pick('Members', 'الأعضاء');
  String get broadcastLabel => pick('Broadcast', 'البث');
  String get durationLabel => pick('Duration', 'المدة');
  String get episodesLabel => pick('Episodes', 'الحلقات');
  String get airedLabel => pick('Aired', 'العرض');
  String get studiosLabel => pick('Studios', 'الاستوديو');
  String get producersLabel => pick('Producers', 'الإنتاج');
  String get sourceLabel => pick('Source', 'المصدر');
  String get typeLabel => pick('Type', 'النوع');
  String get genreLabel => pick('Genre', 'التصنيف');
  String get statusLabel => pick('Status', 'الحالة');
  String get seasonLabel => pick('Season', 'الموسم');
  String get ageRatingLabel => pick('Age rating', 'التصنيف العمري');
  String get showMore => pick('Show more', 'عرض المزيد');
  String get showLess => pick('Show less', 'عرض أقل');
  String get recommendations => pick('Recommendations', 'توصيات');
  String get downloads => pick('Downloads', 'التنزيلات');
  String get favoriteLimit => pick(
    'You can save up to 50 favorite anime.',
    'يمكنك حفظ حتى 50 أنمي في المفضلة.',
  );
  String get favoriteCharacter => pick('Favorite character', 'تفضيل الشخصية');
  String get aggregatedResults =>
      pick('More results across Pubget', 'نتائج إضافية في Pubget');
  String get loadingProfile =>
      pick('Loading full profile…', 'جاري تحميل الملف الكامل…');
  String get malFavorites => pick('MAL favorites', 'مفضلات MAL');
  String get pubgetFavorites => pick('Pubget favorites', 'مفضلات Pubget');

  String overallScore(String value) =>
      pick('Overall $value', 'الإجمالي $value');

  // Entity names reused by global search results.
  String get entityGroup => pick('Group', 'مجموعة');
  String get entityPerson => pick('Person', 'شخص');
  String get entityEvent => pick('Event', 'حدث');
  String get entityAnime => pick('Anime', 'أنمي');
  String get entityFanWork => pick('Fan Work', 'عمل خاص');
  String get entityCharacter => pick('Character', 'شخصية');
  String get entityReel => pick('Reel', 'ريل');

  // ---------------------------------------------------------------------------
  // Tabs
  // ---------------------------------------------------------------------------

  String get tabDetails => pick('Details', 'التفاصيل');
  String get tabCharactersCast => pick('Characters & cast', 'الشخصيات والطاقم');
  String get tabStatistics => pick('Statistics', 'الإحصائيات');
  String get tabInfo => pick('Info', 'معلومات');
  String get tabCharacters => pick('Characters', 'شخصيات');
  String get tabRelated => pick('Related', 'مرتبط');
  String get scoreDistribution => pick('Score distribution', 'توزيع التقييمات');
  String get criteriaBreakdown =>
      pick('What members rated', 'ما الذي يقيّمه الأعضاء');
  String get inMyList => pick('In my list', 'في قائمتي');
  String get criteriaStory => pick('Story', 'القصة');
  String get criteriaArt => pick('Art', 'الرسم');
  String get criteriaCharacters => pick('Characters', 'الشخصيات');
  String get criteriaAction => pick('Action', 'الحركة');
  String get criteriaSound => pick('Sound', 'الصوت');
  String get criteriaEnjoyment => pick('Enjoyment', 'الاستمتاع');
  String get tabLibrary => pick('My list', 'قائمتي');
  String get tabRatings => pick('Ratings', 'تقييمات');
  String get tabLists => pick('Lists', 'قوائم');
  String get tabCustomList => pick('Custom', 'مخصصة');
  String get tabFavorites => pick('Favorites', 'المفضلة');
  String get tabPopular => pick('Popular', 'الشائعة');
  String get favoriteCharactersTab =>
      pick('Favorite characters', 'شخصيات مفضلة');
  String get favoriteAnimeTab => pick('Favorite anime', 'أنمي مفضل');
  String get listsTab => pick('Lists', 'قوائم');
  String get ratingsTab => pick('Ratings', 'تقييمات');
  String get reportReview => pick('Report review', 'مراجعة الإبلاغ');

  // ---------------------------------------------------------------------------
  // Ratings and statistics
  // ---------------------------------------------------------------------------

  String get rateAnime => pick('Rate this anime', 'قيّم هذا الأنمي');
  String get editRating => pick('Edit rating', 'تعديل تقييمك');
  String get communityScore => pick('Pubget score', 'تقييم Pubget');
  String get malScore => pick('MAL', 'تقييم MAL');
  String get ratingsTitle => pick('Ratings', 'التقييمات');
  String get votesTitle => pick('Vote distribution', 'توزيع الأصوات');
  String get communityStats => pick('Community stats', 'إحصاءات المجتمع');
  String get statusDistribution => pick('Following status', 'حالات المتابعة');
  String get listedCountLabel => pick('Listed by', 'أضافه');
  String get ratingCountLabel => pick('Ratings', 'عدد التقييمات');
  String get noRatingsYet => pick(
    'Be the first to rate this anime on Pubget.',
    'كن أول من يقيّم هذا الأنمي على Pubget.',
  );
  String get scoreSourceApp => pick('Pubget', 'Pubget');
  String get scoreSourceMal => pick('MAL', 'MAL');
  String get overallScoreLabel => pick('Overall', 'الإجمالي');
  String get noStatsYet =>
      pick('No community activity yet.', 'لا يوجد نشاط مجتمعي بعد.');

  // ---------------------------------------------------------------------------
  // My list
  // ---------------------------------------------------------------------------

  String get libraryTitle => pick('My list', 'قائمتي');
  String get libraryEmpty =>
      pick('No titles in this list yet', 'لا عناوين في هذه القائمة بعد');
  String get libraryEmptyMessage => pick(
    'Add anime from a details page. Lists are saved on the server.',
    'أضف أنمي من صفحته. تُحفظ قائمتك على الخادم.',
  );
  String get listStatus => pick('Your list', 'حالتك');
  String get removeFromList => pick('Remove from list', 'إزالة من القائمة');
  String get changeStatus => pick('Change status', 'تغيير الحالة');
  String get addToList => pick('Add to list', 'أضف إلى القائمة');
  String get searchInList => pick('Search in your list', 'ابحث في قائمتك');
  String get viewGrid => pick('Grid', 'شبكة');
  String get viewNetwork => pick('Network', 'شبكة مترابطة');
  String get sortBy => pick('Sort', 'الترتيب');
  String get sortRecentlyUpdated => pick('Recently updated', 'آخر تحديث');
  String get sortTitleAsc => pick('Title A–Z', 'العنوان أ–ي');
  String get sortTitleDesc => pick('Title Z–A', 'العنوان ي–أ');
  String get sortRatingDesc => pick('Highest rated', 'الأعلى تقييماً');
  String get sortRatingAsc => pick('Lowest rated', 'الأدنى تقييماً');
  String get sortPopularityDesc => pick('Most popular', 'الأكثر شعبية');
  String get sortYearDesc => pick('Newest year', 'الأحدث سنة');
  String get sortYearAsc => pick('Oldest year', 'الأقدم سنة');
  String get formatFilter => pick('Format', 'النوع');
  String get formatAll => pick('All formats', 'كل الأنواع');
  String get signInToSaveList =>
      pick('Sign in to save your list.', 'سجّل الدخول لحفظ قائمتك.');
  String get statusWantToWatch => pick('Want to watch', 'أرغب بمشاهدتها');
  String get statusWatching => pick('Watching', 'أشاهدها حالياً');
  String get statusCompleted => pick('Completed', 'تم مشاهدتها');
  String get statusWatchLater => pick('Watch later', 'أكملها لاحقاً');
  String get statusNotInterested => pick('Not interested', 'لا أرغب بمشاهدتها');

  // ---------------------------------------------------------------------------
  // Characters
  // ---------------------------------------------------------------------------

  String get popularCharactersTitle =>
      pick('Popular characters', 'الشخصيات الأكثر شعبية');
  String get favoriteCharactersTitle =>
      pick('My favorite characters', 'شخصياتي المفضلة');
  String get characterAbout => pick('About', 'نبذة');
  String get characterNicknames => pick('Nicknames', 'ألقاب');
  String get characterAnime => pick('Anime appearances', 'الأنميات المرتبطة');
  String get characterManga => pick('Manga appearances', 'الظهور في المانغا');
  String get characterVoices => pick('Voice actors', 'أداء صوتي');
  String get characterFacts => pick('Profile facts', 'بيانات الشخصية');
  String get characterMalId => pick('MAL ID', 'معرف MAL');
  String get characterRole => pick('Role', 'الدور');
  String get characterRank => pick('Community rank', 'الترتيب العالمي');
  String get characterYourRating => pick('Your rating', 'تقييمك');
  String get characterReels => pick('Related reels', 'ريلز وريولبلي');
  String get characterDiscussions =>
      pick('Community discussion', 'نقاشات المجتمع');
  String get characterDiscussionHint => pick(
    'Share your thoughts about this character',
    'شارك رأيك في هذه الشخصية',
  );
  String get characterDiscussionEmpty => pick(
    'No discussion yet. Start the conversation.',
    'لا يوجد نقاش بعد. ابدأ الحديث.',
  );
  String get characterNotFound => pick(
    'This character could not be found.',
    'تعذّر العثور على هذه الشخصية.',
  );
  String get characterFavorites => pick('Favorites', 'الإعجابات');
  String get characterOptional => pick('Optional', 'اختياري');
  String get noFavoriteCharacters =>
      pick('No favorite characters yet', 'لا توجد شخصيات مفضلة بعد');
  String get noFavoriteCharactersMessage => pick(
    'Tap the heart on any character to keep them here.',
    'اضغط على القلب في أي شخصية للاحتفاظ بها هنا.',
  );
  String get viewAllCharacters => pick('View all', 'عرض الكل');
  String get noCharactersFound => pick('No characters found', 'لا توجد شخصيات');
  String get searchCharacters => pick('Search characters', 'ابحث في الشخصيات');
  String get roleplay => pick('Roleplay', 'ريولبلي');
  String get reels => pick('Reels', 'ريلز');
  String get post => pick('Post', 'نشر');
  String get delete => pick('Delete', 'حذف');
  String get removedFromFavorites =>
      pick('Removed from favorites', 'أُزيلت من المفضلة');
  String get removedFromList =>
      pick('Removed from your list', 'أُزيل من قائمتك');
  String get statusUpdated => pick('Status updated', 'تم تحديث الحالة');

  // Anime detail fact grid.
  String get factType => pick('Type', 'النوع');
  String get factEpisodes => pick('Episodes', 'الحلقات');
  String get factDuration => pick('Duration', 'المدة');
  String get factAired => pick('Aired', 'العرض');
  String get factStudios => pick('Studios', 'الاستوديو');
  String get factSource => pick('Source', 'المصدر');
  String get factBroadcast => pick('Broadcast', 'البث');

  // Character fact grid.
  String get englishName => pick('English name', 'الاسم الإنجليزي');
  String get arabicName => pick('Arabic name', 'الاسم العربي');
  String get age => pick('Age', 'العمر');
  String get birthday => pick('Birthday', 'تاريخ الميلاد');
  String get height => pick('Height', 'الطول');
  String get weight => pick('Weight', 'الوزن');
  String get bloodType => pick('Blood type', 'فصيلة الدم');
  String get hairColor => pick('Hair color', 'لون الشعر');
  String get eyeColor => pick('Eye color', 'لون العينين');
  String get gender => pick('Gender', 'الجنس');
  String get species => pick('Species', 'الفصيلة');
  String get affiliation => pick('Affiliation', 'الانتماء');
  String get occupation => pick('Occupation', 'المهنة');

  // ---------------------------------------------------------------------------
  // Rankings and hub sections
  // ---------------------------------------------------------------------------

  String get malRankingTitle =>
      pick('Global MAL ranking', 'التقييم العالمي حسب MAL');
  String get communityRankingTitle =>
      pick('Pubget community ranking', 'تقييم المجتمع حسب Pubget');
  String get myAnimeTitle => pick('My Anime', 'أنميّاتي');
  String get theirAnimeTitle => pick('Anime', 'أنمي');
  String get reviewsTitle => pick('Reviews', 'المراجعات');
  String get relatedTitle => pick('Related', 'مرتبط');
  String get relatedReels => pick('Related reels', 'ريلز مرتبط');
  String get relatedEvents => pick('Related events', 'أحداث مرتبط');
  String get noReelsFound => pick('No reels found', 'لا توجد ريلز');
  String get noEventsFound => pick('No events found', 'لا توجد أحداث');
  String get relatedFanWorksTitle =>
      pick('Related Fan Works', 'أعمال معجبين مرتبطة');
  String get relatedGroupsTitle => pick('Related groups', 'مجموعات مرتبطة');
  String get writeReview => pick('Write a review', 'اكتب مراجعة');
  String get reviewHint =>
      pick('Share what you thought (optional)', 'شارك رأيك (اختياري)');
  String get submitRating => pick('Save rating', 'حفظ التقييم');
  String get thisSeasonSubtitle => pick(
    'Airing this cour — posters, scores, and studios.',
    'أبرز عناوين الموسم الحالي.',
  );
  String get popularSubtitle =>
      pick('The titles everyone is watching and saving.', 'الأكثر شعبية الآن.');
  String get mostListed =>
      pick('Most listed in user lists', 'الأكثر في قوائم المستخدمين');
  String get seasonalCharacters =>
      pick('Characters of the season', 'شخصيات هذا الموسم');

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  String get searchHomeHint => pick(
    'Search groups, people, events, anime, and Fan Works',
    'ابحث في الأنمي بالاسم',
  );
  String get searchFiltersHint => pick(
    'Search by name, or filter by season and genre.',
    'ابحث بالاسم، ثم صفّ حسب الموسم والنوع والحالة.',
  );
  String get filterGenre => pick('Genre', 'التصنيف');
  String get filterStudio => pick('Studio', 'الاستوديو');
  String get filterStatus => pick('Status', 'العرض');
  String get filterAgeRating => pick('Age rating', 'التصنيف العمري');
  String get filterType => pick('Type', 'النوع');
  String get filterSeason => pick('Season', 'الموسم');
  String get filterSort => pick('Sort', 'الترتيب');
  String get filterAll => pick('All', 'الكل');
  String get sortMembers => pick('Popularity', 'الأكثر أعضاء');
  String get sortTitle => pick('Title', 'العنوان');
  String get sortNewest => pick('Newest', 'الأحدث');
  String get sortFavorites => pick('Most favorited', 'الأكثر تفضيلاً');
  String get sortHighestRated => pick('Highest rated', 'الأعلى تقييماً');
  String get sortLowestRated => pick('Lowest rated', 'الأدنى تقييماً');
  String get statusAiring => pick('Airing', 'يُعرض حالياً');
  String get statusFinished => pick('Finished', 'منتهٍ');
  String get statusUpcoming => pick('Upcoming', 'قادم');
  String get ageAllAges => pick('All ages', 'جميع الأعمار');
  String get ageTeens => pick('Teens 13+', 'مراهقون 13+');
  String get ageAdult => pick('17+', 'بالغون 17+');

  // ---------------------------------------------------------------------------
  // Custom lists
  // ---------------------------------------------------------------------------

  String get myLibrary => pick('My library', 'مكتبتي');
  String get customListsTitle => pick('Custom lists', 'قوائم مخصصة');
  String get recommendedForYou => pick('Recommended for you', 'موصى بها لك');
  String get customLists => pick('Custom lists', 'قوائم مخصصة');
  String get newCustomList => pick('New list', 'قائمة جديدة');
  String get customListName => pick('List name', 'اسم القائمة');
  String get customListDescription =>
      pick('Description (optional)', 'وصف (اختياري)');
  String get privateList => pick('Private', 'خاصة');
  String get privateListHint =>
      pick('Only you can see this list', 'أنت فقط من يرى هذه القائمة');
  String get customListsEmpty =>
      pick('No custom lists yet', 'لا قوائم مخصصة بعد');
  String get customListsEmptyMessage => pick(
    'Create your own themed lists to organize anime your way.',
    'أنشئ قوائمك الخاصة لتنظيم الأنمي على طريقتك.',
  );
  String get createList => pick('Create list', 'إنشاء القائمة');
  String get customList => pick('Custom list', 'قائمة مخصصة');
  String get listNameRequired =>
      pick('A list name is required.', 'اسم القائمة مطلوب.');
  String get editList => pick('Edit list', 'تعديل القائمة');
  String get deleteList => pick('Delete list', 'حذف القائمة');

  // ---------------------------------------------------------------------------
  // Counters
  // ---------------------------------------------------------------------------

  String customListItemCount(int count) =>
      pick('$count titles', '$count عنواناً');

  String listedCount(int count) => pick('$count listed', '$count في القوائم');

  String characterFavoritesCount(int count) =>
      pick('$count favorites', '$count تفضيل');

  String ratingsCount(int count) =>
      pick('$count Pubget ratings', '$count تقييم على Pubget');

  String votesCount(int count) => pick('$count votes', '$count صوت');

  String episodeCount(int count) => pick(
    count == 1 ? '1 episode' : '$count episodes',
    count == 1 ? 'حلقة واحدة' : '$count حلقة',
  );
}
