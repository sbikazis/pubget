import 'package:flutter/widgets.dart';

import '../../../core/l10n/app_strings.dart';
import '../search_hit.dart';

/// Localized chrome for global search (spec §6).
final class SearchCopy {
  const SearchCopy(this._s);

  final AppStrings _s;

  static SearchCopy of(BuildContext context) =>
      SearchCopy(AppStrings.of(context));

  String get title => _s.pick('Search', 'بحث');
  String get emptyTitle => _s.pick('Search Pubget', 'ابحث في Pubget');

  String emptyMessage(int minLength) => _s.pick(
    'Type at least $minLength characters to find groups, people, events, '
        'anime, and Fan Works.',
    'اكتب $minLength أحرف على الأقل للعثور على المجموعات والأشخاص والأحداث '
        'والأنمي والأعمال الخاصة.',
  );

  String get nothingTitle => _s.pick('Nothing found', 'لا توجد نتائج');
  String get nothingMessage => _s.pick(
    'Try another group, username, event, anime, or Fan Work.',
    'جرّب مجموعة أو اسم مستخدم أو حدثاً أو أنمي أو عملاً آخر.',
  );
  String get failed => _s.pick('Search failed.', 'فشل البحث.');
  String get unknownUser => _s.pick('Pubget user', 'مستخدم Pubget');

  String labelFor(SearchHitType type) => switch (type) {
    SearchHitType.group => _s.pick('Group', 'مجموعة'),
    SearchHitType.user => _s.pick('Person', 'شخص'),
    SearchHitType.event => _s.pick('Event', 'حدث'),
    SearchHitType.anime => _s.pick('Anime', 'أنمي'),
    SearchHitType.fanWork => _s.pick('Fan Work', 'عمل خاص'),
    SearchHitType.character => _s.pick('Character', 'شخصية'),
    SearchHitType.reel => _s.pick('Reel', 'ريل'),
  };
}
