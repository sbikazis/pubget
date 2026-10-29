import 'package:flutter/widgets.dart';

import '../../../core/l10n/app_strings.dart';

/// Localized Search-feature copy, following the same pattern as
/// [FanWorkCopy]/[GameCopy]: a thin wrapper over [AppStrings] that keeps
/// feature-specific sentences out of the shared catalog while still resolving
/// to Arabic when the app locale is Arabic.
///
/// The search result *kind* labels already resolve through
/// `AppStrings.searchHitLabel`; this class covers the screen chrome and the
/// empty/runnable states that used to be hardcoded English.
final class SearchCopy {
  const SearchCopy(this._s);

  final AppStrings _s;

  static SearchCopy of(BuildContext context) =>
      SearchCopy(AppStrings.of(context));

  static SearchCopy forLocale(Locale? locale) =>
      SearchCopy(AppStrings.forLocale(locale));

  String get title => _s.search;
  String get fieldHint => _s.searchHint;
  String get runnableTitle => _s.searchHint;

  String runnableMessage(int minLength) => _s.pick(
    'Type at least $minLength characters to find groups, people, events, '
        'anime, and Fan Works.',
    'اكتب $minLength أحرف على الأقل للعثور على المجموعات والأشخاص '
        'والفعاليات والأنمي وأعمال المعجبين.',
  );

  String get emptyTitle => _s.pick('Nothing found', 'لا نتائج');
  String get emptyMessage => _s.pick(
    'Try another group, username, event, anime, or Fan Work.',
    'جرّب مجموعة أو اسم مستخدم أو فعالية أو أنمي أو عملاً آخر.',
  );

  String get unknownUser => _s.pubgetUser;

  /// Recent-search list chrome (spec §6).
  String get historyTitle => _s.pick('Recent searches', 'عمليات البحث الأخيرة');
  String get clearHistory => _s.pick('Clear', 'مسح');
  String removeHistoryEntry(String term) => _s.pick(
    'Remove $term from recent searches',
    'إزالة $term من البحث الأخير',
  );
  String get allFilter => _s.pick('All', 'الكل');

  /// Shown when an entity filter is the only reason the list is empty, so the
  /// screen does not claim nothing was found.
  String get filterEmptyTitle =>
      _s.pick('No results of this type', 'لا نتائج من هذا النوع');
  String get filterEmptyMessage => _s.pick(
    'Other results matched your search. Choose “All” to see them.',
    'هناك نتائج أخرى طابقت بحثك. اختر «الكل» لعرضها.',
  );
}
