import 'package:flutter/widgets.dart';

import '../../../core/l10n/app_strings.dart';
import '../models/anime_list_models.dart';
import '../models/anime_models.dart';
import '../models/anime_rating_models.dart';

/// Localized Anime Hub chrome and mapped catalog terms.
///
/// Original titles, MAL IDs, and Jikan narrative stay in the source language.
final class AnimeCopy {
  const AnimeCopy(this._s);

  final AppStrings _s;

  static AnimeCopy of(BuildContext context) => AnimeCopy(AppStrings.of(context));

  static AnimeCopy forLocale(Locale? locale) =>
      AnimeCopy(AppStrings.forLocale(locale));

  String get hubTitle => _ui(AnimeStrings.hubTitle, 'مركز الأنمي');
  String get seeAll => _ui(AnimeStrings.seeAll, 'عرض الكل');
  String get searchHint => _ui(AnimeStrings.searchHint, 'ابحث عن أنمي');
  String get openSearch => _ui(AnimeStrings.openSearch, 'بحث');
  String get closeSearch => _ui(AnimeStrings.closeSearch, 'إغلاق البحث');
  String get nothingFound => _ui(AnimeStrings.nothingFound, 'لا يوجد أنمي');
  String get nothingFoundMessage => _ui(
    AnimeStrings.nothingFoundMessage,
    'جرّب اسماً آخر أو صفّح الكتالوج.',
  );
  String get unableToLoad =>
      _ui(AnimeStrings.unableToLoad, 'تعذّر تحميل الأنمي الآن.');
  String get checkConnection => _ui(
    AnimeStrings.checkConnection,
    'تحقق من الاتصال وحاول مرة أخرى.',
  );
  String get retry => _ui(AnimeStrings.retry, 'إعادة المحاولة');
  String get cachedBanner =>
      _ui(AnimeStrings.cachedBanner, 'عرض بيانات محفوظة');
  String get offlineCached => _ui(
    AnimeStrings.offlineCached,
    'أنت غير متصل. عرض بيانات محفوظة.',
  );
  String get genresTitle => _ui(AnimeStrings.genresTitle, 'تصفح حسب التصنيف');
  String get seasonsTitle => _ui(AnimeStrings.seasonsTitle, 'تصفح حسب الموسم');
  String get charactersTitle => _ui(AnimeStrings.charactersTitle, 'الشخصيات');
  String get synopsisTitle => _ui(AnimeStrings.synopsisTitle, 'القصة');
  String get detailsMissing =>
      _ui(AnimeStrings.detailsMissing, 'تعذّر العثور على هذا الأنمي.');
  String get emptyCatalog =>
      _ui(AnimeStrings.emptyCatalog, 'لا شيء في هذه القائمة بعد.');
  String get endOfList =>
      _ui(AnimeStrings.endOfList, 'وصلت إلى نهاية القائمة.');
  String get favorite => _ui(AnimeStrings.favorite, 'المفضلة');
  String get favorited => _ui(AnimeStrings.favorited, 'في المفضلة');
  String get trailer => _ui(AnimeStrings.trailer, 'الإعلان');
  String get links => _ui(AnimeStrings.links, 'روابط خارجية');
  String get copied => _ui(AnimeStrings.copied, 'تم نسخ الرابط');
  String get share => _ui(AnimeStrings.share, 'مشاركة الأنمي');
  String get favoriteLimit => _ui(
    AnimeStrings.favoriteLimit,
    'يمكنك حفظ حتى 50 أنمي في المفضلة.',
  );
  String get libraryTitle => _ui(AnimeStrings.libraryTitle, 'قوائمي');
  String get libraryEmpty =>
      _ui(AnimeStrings.libraryEmpty, 'لا عناوين في هذه القائمة بعد');
  String get libraryEmptyMessage => _ui(
    AnimeStrings.libraryEmptyMessage,
    'أضف أنمي من صفحة التفاصيل. تُحفظ القوائم على الخادم.',
  );
  String get listStatus => _ui(AnimeStrings.listStatus, 'قائمتك');
  String get removeFromList =>
      _ui(AnimeStrings.removeFromList, 'إزالة من القائمة');
  String get rateAnime => _ui(AnimeStrings.rateAnime, 'قيّم هذا الأنمي');
  String get editRating => _ui(AnimeStrings.editRating, 'تعديل التقييم');
  String get communityScore => _ui(AnimeStrings.communityScore, 'تقييم Pubget');
  String get malScore => _ui(AnimeStrings.malScore, 'MAL');
  String get ratingsTitle => _ui(AnimeStrings.ratingsTitle, 'التقييمات');
  String get popularCharactersTitle =>
      _ui(AnimeStrings.popularCharactersTitle, 'الشخصيات الشائعة');
  String get myAnimeTitle => _ui(AnimeStrings.myAnimeTitle, 'أنميّاتي');
  String get theirAnimeTitle => _ui(AnimeStrings.theirAnimeTitle, 'أنمي');
  String get reviewsTitle => _ui(AnimeStrings.reviewsTitle, 'المراجعات');
  String get writeReview => _ui(AnimeStrings.writeReview, 'اكتب مراجعة');
  String get reviewHint =>
      _ui(AnimeStrings.reviewHint, 'شارك رأيك (اختياري)');
  String get submitRating => _ui(AnimeStrings.submitRating, 'حفظ التقييم');
  String get favoriteCharacter =>
      _ui(AnimeStrings.favoriteCharacter, 'تفضيل الشخصية');
  String get filterGenre => _ui(AnimeStrings.filterGenre, 'التصنيف');
  String get filterType => _ui(AnimeStrings.filterType, 'النوع');
  String get filterSeason => _ui(AnimeStrings.filterSeason, 'الموسم');
  String get filterSort => _ui(AnimeStrings.filterSort, 'الترتيب');
  String get sortMembers => _ui(AnimeStrings.sortMembers, 'الشعبية');
  String get sortTitle => _ui(AnimeStrings.sortTitle, 'العنوان');
  String get sortNewest => _ui(AnimeStrings.sortNewest, 'الأحدث');
  String get sortFavorites => _ui(AnimeStrings.sortFavorites, 'الأكثر تفضيلاً');
  String get searchFiltersHint => _ui(
    AnimeStrings.searchFiltersHint,
    'ابحث بالاسم أو صفّ حسب الموسم والتصنيف.',
  );
  String get noRatingsYet => _ui(
    AnimeStrings.noRatingsYet,
    'كن أول من يقيّم هذا الأنمي على Pubget.',
  );
  String get characterAbout => _ui(AnimeStrings.characterAbout, 'نبذة');
  String get characterNicknames =>
      _ui(AnimeStrings.characterNicknames, 'ألقاب');
  String get characterAnime =>
      _ui(AnimeStrings.characterAnime, 'ظهور في الأنمي');
  String get characterManga =>
      _ui(AnimeStrings.characterManga, 'ظهور في المانغا');
  String get characterVoices =>
      _ui(AnimeStrings.characterVoices, 'أداء صوتي');
  String get characterFacts =>
      _ui(AnimeStrings.characterFacts, 'بيانات الشخصية');
  String get characterMalId => _ui(AnimeStrings.characterMalId, 'معرف MAL');
  String get characterRole => _ui(AnimeStrings.characterRole, 'الدور');
  String get loadingProfile =>
      _ui(AnimeStrings.loadingProfile, 'جاري تحميل الملف الكامل…');
  String get malFavorites => _ui(AnimeStrings.malFavorites, 'مفضلات MAL');
  String get pubgetFavorites =>
      _ui(AnimeStrings.pubgetFavorites, 'مفضلات Pubget');
  String get thisSeasonSubtitle => _ui(
    AnimeStrings.thisSeasonSubtitle,
    'أبرز عناوين الموسم الحالي.',
  );
  String get popularSubtitle =>
      _ui(AnimeStrings.popularSubtitle, 'الأكثر شعبية الآن.');
  String get detailsSection => _ui('Details', 'التفاصيل');
  String get factType => _ui('Type', 'النوع');
  String get factEpisodes => _ui('Episodes', 'الحلقات');
  String get factDuration => _ui('Duration', 'المدة');
  String get factAired => _ui('Aired', 'العرض');
  String get factStudios => _ui('Studios', 'الاستوديو');
  String get factSource => _ui('Source', 'المصدر');
  String get factBroadcast => _ui('Broadcast', 'البث');
  String get englishName => _ui('English name', 'الاسم الإنجليزي');
  String get arabicName => _ui('Arabic name', 'الاسم العربي');
  String get age => _ui('Age', 'العمر');
  String get birthday => _ui('Birthday', 'تاريخ الميلاد');
  String get height => _ui('Height', 'الطول');
  String get weight => _ui('Weight', 'الوزن');
  String get searchHomeHint => _ui(
    AnimeStrings.searchHomeHint,
    'ابحث في المجموعات والأشخاص والفعاليات والأنمي وأعمال المعجبين',
  );

  String ratingsCount(int count) =>
      _s.pick('$count Pubget ratings', '$count تقييم على Pubget');

  String overallScore(String value) =>
      _s.pick('Overall $value', 'الإجمالي $value');

  String criterion(AnimeRatingCriterion value) => switch (value) {
    AnimeRatingCriterion.story => _ui('Story', 'القصة'),
    AnimeRatingCriterion.art => _ui('Art', 'الرسم'),
    AnimeRatingCriterion.characters => _ui('Characters', 'الشخصيات'),
    AnimeRatingCriterion.action => _ui('Action', 'أكشن'),
    AnimeRatingCriterion.sound => _ui('Sound', 'الصوت'),
    AnimeRatingCriterion.enjoyment => _ui('Enjoyment', 'المتعة'),
  };

  String ui(String english) {
    return switch (english) {
      AnimeStrings.hubTitle => hubTitle,
      AnimeStrings.seeAll => seeAll,
      AnimeStrings.searchHint => searchHint,
      AnimeStrings.openSearch => openSearch,
      AnimeStrings.closeSearch => closeSearch,
      AnimeStrings.nothingFound => nothingFound,
      AnimeStrings.nothingFoundMessage => nothingFoundMessage,
      AnimeStrings.unableToLoad => unableToLoad,
      AnimeStrings.checkConnection => checkConnection,
      AnimeStrings.retry => retry,
      AnimeStrings.cachedBanner => cachedBanner,
      AnimeStrings.offlineCached => offlineCached,
      AnimeStrings.genresTitle => genresTitle,
      AnimeStrings.seasonsTitle => seasonsTitle,
      AnimeStrings.charactersTitle => charactersTitle,
      AnimeStrings.synopsisTitle => synopsisTitle,
      AnimeStrings.detailsMissing => detailsMissing,
      AnimeStrings.emptyCatalog => emptyCatalog,
      AnimeStrings.endOfList => endOfList,
      AnimeStrings.favorite => favorite,
      AnimeStrings.favorited => favorited,
      AnimeStrings.trailer => trailer,
      AnimeStrings.links => links,
      AnimeStrings.copied => copied,
      AnimeStrings.share => share,
      AnimeStrings.favoriteLimit => favoriteLimit,
      AnimeStrings.libraryTitle => libraryTitle,
      AnimeStrings.libraryEmpty => libraryEmpty,
      AnimeStrings.libraryEmptyMessage => libraryEmptyMessage,
      AnimeStrings.listStatus => listStatus,
      AnimeStrings.removeFromList => removeFromList,
      AnimeStrings.rateAnime => rateAnime,
      AnimeStrings.editRating => editRating,
      AnimeStrings.communityScore => communityScore,
      AnimeStrings.malScore => malScore,
      AnimeStrings.ratingsTitle => ratingsTitle,
      AnimeStrings.popularCharactersTitle => popularCharactersTitle,
      AnimeStrings.myAnimeTitle => myAnimeTitle,
      AnimeStrings.theirAnimeTitle => theirAnimeTitle,
      AnimeStrings.reviewsTitle => reviewsTitle,
      AnimeStrings.writeReview => writeReview,
      AnimeStrings.reviewHint => reviewHint,
      AnimeStrings.submitRating => submitRating,
      AnimeStrings.favoriteCharacter => favoriteCharacter,
      AnimeStrings.filterGenre => filterGenre,
      AnimeStrings.filterType => filterType,
      AnimeStrings.filterSeason => filterSeason,
      AnimeStrings.filterSort => filterSort,
      AnimeStrings.sortMembers => sortMembers,
      AnimeStrings.sortTitle => sortTitle,
      AnimeStrings.sortNewest => sortNewest,
      AnimeStrings.sortFavorites => sortFavorites,
      AnimeStrings.searchFiltersHint => searchFiltersHint,
      AnimeStrings.noRatingsYet => noRatingsYet,
      AnimeStrings.characterAbout => characterAbout,
      AnimeStrings.characterNicknames => characterNicknames,
      AnimeStrings.characterAnime => characterAnime,
      AnimeStrings.characterManga => characterManga,
      AnimeStrings.characterVoices => characterVoices,
      AnimeStrings.characterFacts => characterFacts,
      AnimeStrings.characterMalId => characterMalId,
      AnimeStrings.characterRole => characterRole,
      AnimeStrings.loadingProfile => loadingProfile,
      AnimeStrings.malFavorites => malFavorites,
      AnimeStrings.pubgetFavorites => pubgetFavorites,
      AnimeStrings.thisSeasonSubtitle => thisSeasonSubtitle,
      AnimeStrings.popularSubtitle => popularSubtitle,
      AnimeStrings.searchHomeHint => searchHomeHint,
      'Details' => detailsSection,
      _ => catalogPhrase(english),
    };
  }

  String catalog(AnimeCatalogKind kind) => switch (kind) {
    AnimeCatalogKind.trending => _ui('Trending', 'الرائج'),
    AnimeCatalogKind.popular => _ui('Most popular', 'الأكثر شعبية'),
    AnimeCatalogKind.top => _ui('Top rated', 'الأعلى تقييماً'),
    AnimeCatalogKind.airing => _ui('Currently airing', 'يعرض الآن'),
    AnimeCatalogKind.thisSeason => _ui('This season', 'هذا الموسم'),
    AnimeCatalogKind.upcoming => _ui('Upcoming', 'قادم'),
  };

  String pageTitle(String english) {
    final seasonYear = RegExp(
      r'^(Winter|Spring|Summer|Fall) (\d{4})$',
    ).firstMatch(english.trim());
    if (seasonYear != null) {
      final parsed = AnimeSeason.tryParse(seasonYear.group(1));
      if (parsed != null) {
        return seasonTitle(parsed, int.parse(seasonYear.group(2)!));
      }
    }
    return ui(english);
  }

  String catalogPhrase(String english) => switch (english) {
    'Trending' => catalog(AnimeCatalogKind.trending),
    'Most popular' => catalog(AnimeCatalogKind.popular),
    'Top rated' => catalog(AnimeCatalogKind.top),
    'Currently airing' => catalog(AnimeCatalogKind.airing),
    'This season' => catalog(AnimeCatalogKind.thisSeason),
    'Upcoming' => catalog(AnimeCatalogKind.upcoming),
    _ => typeStatusOrSelf(english),
  };

  String season(AnimeSeason season) => switch (season) {
    AnimeSeason.winter => _ui('Winter', 'شتاء'),
    AnimeSeason.spring => _ui('Spring', 'ربيع'),
    AnimeSeason.summer => _ui('Summer', 'صيف'),
    AnimeSeason.fall => _ui('Fall', 'خريف'),
  };

  String seasonTitle(AnimeSeason season, int year) =>
      '${this.season(season)} $year';

  String listStatusLabel(AnimeListStatus status) => switch (status) {
    AnimeListStatus.watching => _ui('Watching', 'أشاهد'),
    AnimeListStatus.completed => _ui('Completed', 'مكتمل'),
    AnimeListStatus.planToWatch => _ui('Plan to watch', 'أخطط للمشاهدة'),
    AnimeListStatus.dropped => _ui('Dropped', 'متروك'),
    AnimeListStatus.onHold => _ui('On hold', 'معلّق'),
    AnimeListStatus.favorites => _ui('Favorites', 'المفضلة'),
  };

  String typeFilter(AnimeTypeFilter type) => switch (type) {
    AnimeTypeFilter.tv => typeLabel('TV'),
    AnimeTypeFilter.movie => typeLabel('Movie'),
    AnimeTypeFilter.ova => typeLabel('OVA'),
    AnimeTypeFilter.special => typeLabel('Special'),
    AnimeTypeFilter.ona => typeLabel('ONA'),
  };

  String typeLabel(String? raw) {
    final key = raw?.trim().toLowerCase() ?? '';
    return switch (key) {
      'tv' => _ui('TV', 'تلفزيون'),
      'movie' => _ui('Movie', 'فيلم'),
      'ova' => _ui('OVA', 'أوفا'),
      'ona' => _ui('ONA', 'أونا'),
      'special' => _ui('Special', 'خاص'),
      'music' => _ui('Music', 'موسيقى'),
      'pv' => _ui('PV', 'إعلان'),
      _ => raw ?? '',
    };
  }

  String status(String? raw) {
    final key = raw?.trim().toLowerCase() ?? '';
    return switch (key) {
      'finished airing' || 'finished' => _ui('Finished Airing', 'مكتمل'),
      'currently airing' || 'airing' => _ui('Currently Airing', 'يعرض الآن'),
      'not yet aired' || 'upcoming' => _ui('Not yet aired', 'لم يُعرض بعد'),
      _ => raw ?? '',
    };
  }

  String genre(String? raw) {
    final key = raw?.trim().toLowerCase() ?? '';
    return switch (key) {
      'action' => _ui('Action', 'أكشن'),
      'adventure' => _ui('Adventure', 'مغامرة'),
      'comedy' => _ui('Comedy', 'كوميديا'),
      'drama' => _ui('Drama', 'دراما'),
      'fantasy' => _ui('Fantasy', 'فانتازيا'),
      'horror' => _ui('Horror', 'رعب'),
      'mystery' => _ui('Mystery', 'غموض'),
      'romance' => _ui('Romance', 'رومانسية'),
      'sci-fi' || 'sci fi' || 'science fiction' => _ui('Sci-Fi', 'خيال علمي'),
      'slice of life' => _ui('Slice of Life', 'شريحة من الحياة'),
      'sports' => _ui('Sports', 'رياضة'),
      'supernatural' => _ui('Supernatural', 'خارق'),
      'suspense' || 'thriller' => _ui('Suspense', 'إثارة'),
      'avant garde' => _ui('Avant Garde', 'طليعي'),
      'gourmet' => _ui('Gourmet', 'طعام'),
      'boys love' => _ui('Boys Love', 'حب فتيان'),
      'girls love' => _ui('Girls Love', 'حب فتيات'),
      'ecchi' => _ui('Ecchi', 'إيتشي'),
      'erotica' => _ui('Erotica', 'إروتيكا'),
      'hentai' => _ui('Hentai', 'هنتاي'),
      'award winning' => _ui('Award Winning', 'حائز على جوائز'),
      'adult cast' => _ui('Adult Cast', 'طاقم بالغ'),
      'anthropomorphic' => _ui('Anthropomorphic', 'مجسّم'),
      'cgdct' => _ui('CGDCT', 'فتيات لطيفات'),
      'childcare' => _ui('Childcare', 'رعاية أطفال'),
      'combat sports' => _ui('Combat Sports', 'رياضات قتالية'),
      'delinquents' => _ui('Delinquents', 'منحرفون'),
      'detective' => _ui('Detective', 'تحقيق'),
      'educational' => _ui('Educational', 'تعليمي'),
      'gag humor' => _ui('Gag Humor', 'كوميديا سريعة'),
      'gore' => _ui('Gore', 'دموي'),
      'harem' => _ui('Harem', 'حريم'),
      'high stakes game' => _ui('High Stakes Game', 'لعبة عالية المخاطر'),
      'historical' => _ui('Historical', 'تاريخي'),
      'idols (female)' => _ui('Idols (Female)', 'آيدول (إناث)'),
      'idols (male)' => _ui('Idols (Male)', 'آيدول (ذكور)'),
      'isekai' => _ui('Isekai', 'إيسكاي'),
      'iyashikei' => _ui('Iyashikei', 'إياشيكي'),
      'love polygon' => _ui('Love Polygon', 'مثلث حب'),
      'magical sex shift' => _ui('Magical Sex Shift', 'تحول سحري'),
      'mahou shoujo' => _ui('Mahou Shoujo', 'فتاة سحرية'),
      'martial arts' => _ui('Martial Arts', 'فنون قتالية'),
      'mecha' => _ui('Mecha', 'ميكا'),
      'medical' => _ui('Medical', 'طبي'),
      'military' => _ui('Military', 'عسكري'),
      'music' => _ui('Music', 'موسيقى'),
      'mythology' => _ui('Mythology', 'أساطير'),
      'organized crime' => _ui('Organized Crime', 'جريمة منظمة'),
      'otaku culture' => _ui('Otaku Culture', 'ثقافة الأوتاكو'),
      'parody' => _ui('Parody', 'محاكاة ساخرة'),
      'performing arts' => _ui('Performing Arts', 'فنون أدائية'),
      'pets' => _ui('Pets', 'حيوانات أليفة'),
      'psychological' => _ui('Psychological', 'نفسي'),
      'racing' => _ui('Racing', 'سباق'),
      'reincarnation' => _ui('Reincarnation', 'تناسخ'),
      'reverse harem' => _ui('Reverse Harem', 'حريم عكسي'),
      'romantic subtext' => _ui('Romantic Subtext', 'إيحاء رومانسي'),
      'samurai' => _ui('Samurai', 'ساموراي'),
      'school' => _ui('School', 'مدرسي'),
      'showbiz' => _ui('Showbiz', 'عرض فني'),
      'space' => _ui('Space', 'فضاء'),
      'strategy game' => _ui('Strategy Game', 'لعبة استراتيجية'),
      'super power' => _ui('Super Power', 'قوى خارقة'),
      'survival' => _ui('Survival', 'بقاء'),
      'team sports' => _ui('Team Sports', 'رياضات جماعية'),
      'time travel' => _ui('Time Travel', 'سفر عبر الزمن'),
      'urban fantasy' => _ui('Urban Fantasy', 'فانتازيا حضرية'),
      'vampire' => _ui('Vampire', 'مصاص دماء'),
      'video game' => _ui('Video Game', 'لعبة فيديو'),
      'villainess' => _ui('Villainess', 'شريرة'),
      'visual arts' => _ui('Visual Arts', 'فنون بصرية'),
      'workplace' => _ui('Workplace', 'مكان عمل'),
      'josei' => _ui('Josei', 'جوسي'),
      'kids' => _ui('Kids', 'أطفال'),
      'seinen' => _ui('Seinen', 'سينين'),
      'shoujo' => _ui('Shoujo', 'شوجو'),
      'shounen' => _ui('Shounen', 'شونين'),
      _ => raw ?? '',
    };
  }

  String source(String? raw) {
    final key = raw?.trim().toLowerCase() ?? '';
    return switch (key) {
      'manga' => _ui('Manga', 'مانغا'),
      'light novel' => _ui('Light novel', 'رواية خفيفة'),
      'novel' => _ui('Novel', 'رواية'),
      'original' => _ui('Original', 'أصلي'),
      'visual novel' => _ui('Visual novel', 'رواية بصرية'),
      'web manga' => _ui('Web manga', 'مانغا ويب'),
      'web novel' => _ui('Web novel', 'رواية ويب'),
      'game' => _ui('Game', 'لعبة'),
      'card game' => _ui('Card game', 'لعبة بطاقات'),
      'book' => _ui('Book', 'كتاب'),
      'picture book' => _ui('Picture book', 'كتاب مصور'),
      'music' => _ui('Music', 'موسيقى'),
      'radio' => _ui('Radio', 'راديو'),
      'other' => _ui('Other', 'أخرى'),
      _ => raw ?? '',
    };
  }

  String role(String? raw) {
    final key = raw?.trim().toLowerCase() ?? '';
    return switch (key) {
      'main' => _ui('Main', 'رئيسية'),
      'supporting' => _ui('Supporting', 'مساعدة'),
      'background' => _ui('Background', 'خلفية'),
      _ => raw ?? '',
    };
  }

  String factLabel(String raw) {
    final key = raw.trim().toLowerCase();
    return switch (key) {
      'age' => age,
      'birthday' || 'birth date' || 'birthdate' => birthday,
      'height' => height,
      'weight' => weight,
      'arabic' || 'arabic name' || 'الاسم' || 'الاسم العربي' => arabicName,
      'english' || 'english name' => englishName,
      'blood type' => _ui('Blood type', 'فصيلة الدم'),
      'hair color' => _ui('Hair color', 'لون الشعر'),
      'eye color' => _ui('Eye color', 'لون العين'),
      'gender' => _ui('Gender', 'الجنس'),
      'species' => _ui('Species', 'النوع'),
      'affiliation' => _ui('Affiliation', 'الانتماء'),
      'occupation' => _ui('Occupation', 'المهنة'),
      _ => raw,
    };
  }

  String voiceLanguage(String? raw) {
    final key = raw?.trim().toLowerCase() ?? '';
    final localized = switch (key) {
      'japanese' => _ui('Japanese', 'اليابانية'),
      'english' => _ui('English', 'الإنجليزية'),
      'korean' => _ui('Korean', 'الكورية'),
      'chinese' || 'mandarin' => _ui('Chinese', 'الصينية'),
      'spanish' => _ui('Spanish', 'الإسبانية'),
      'french' => _ui('French', 'الفرنسية'),
      'german' => _ui('German', 'الألمانية'),
      'italian' => _ui('Italian', 'الإيطالية'),
      'portuguese' || 'brazilian' || 'portuguese (br)' =>
        _ui('Portuguese', 'البرتغالية'),
      'arabic' => _ui('Arabic', 'العربية'),
      'hungarian' => _ui('Hungarian', 'المجرية'),
      'hebrew' => _ui('Hebrew', 'العبرية'),
      'filipino' || 'tagalog' => _ui('Filipino', 'الفلبينية'),
      _ => raw ?? '',
    };
    if (_s.isArabic && raw != null && raw.trim().isNotEmpty) {
      final original = raw.trim();
      if (localized != original) return '$localized / $original';
    }
    return localized;
  }

  String typeStatusOrSelf(String english) {
    final typed = typeLabel(english);
    if (typed != english && typed.isNotEmpty) return typed;
    final stated = status(english);
    if (stated != english && stated.isNotEmpty) return stated;
    final seasonal = switch (english.toLowerCase()) {
      'winter' => season(AnimeSeason.winter),
      'spring' => season(AnimeSeason.spring),
      'summer' => season(AnimeSeason.summer),
      'fall' || 'autumn' => season(AnimeSeason.fall),
      _ => english,
    };
    if (seasonal != english) return seasonal;
    final genred = genre(english);
    if (genred != english && genred.isNotEmpty) return genred;
    return english;
  }

  String subtitle(Anime anime) {
    final parts = <String>[
      if (anime.type != null && anime.type!.isNotEmpty) typeLabel(anime.type),
      if (anime.year != null) '${anime.year}',
      if (anime.season != null) season(anime.season!),
    ];
    return parts.join(' · ');
  }

  String meta(Anime anime) {
    final parts = <String>[
      if (anime.type != null && anime.type!.isNotEmpty) typeLabel(anime.type),
      if (anime.status != null && anime.status!.isNotEmpty) status(anime.status),
      if (anime.year != null) '${anime.year}',
      if (anime.season != null) season(anime.season!),
    ];
    return parts.join(' · ');
  }

  String _ui(String en, String ar) => _s.pick(en, ar);
}
