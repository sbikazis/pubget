import 'package:flutter/widgets.dart';

import '../../../core/l10n/app_strings.dart';

/// Bilingual copy for the Give Respect sheet.
///
/// This sheet was **Arabic-only**: every string was a hardcoded Arabic literal,
/// so an English-locale member was shown Arabic. Spec §2.3 requires both
/// locales to be first-class, and a single untranslated string in the wrong
/// locale is a defect, not a rough edge — which is exactly what this was.
final class RespectCopy {
  const RespectCopy(this._s);

  final AppStrings _s;

  static RespectCopy of(BuildContext context) =>
      RespectCopy(AppStrings.of(context));

  static RespectCopy forLocale(Locale? locale) =>
      RespectCopy(AppStrings.forLocale(locale));

  String get title => _s.pick('Give Respect', 'منح الاحترام');

  /// The scale hint. Takes the bounds instead of hardcoding them so the sheet
  /// and the server contract cannot drift apart in either locale.
  String body({required int max, required int fanThreshold}) => _s.pick(
    'Choose how much Respect to give (0–$max). '
        'From $fanThreshold you become one of their fans.',
    'اختر مقدار الاحترام (0–$max). عند $fanThreshold+ تصبح من معجبيه.',
  );

  String get confirm => _s.pick('Confirm', 'تأكيد');

  String get confirmSemantic => _s.pick(
    'Give the selected Respect',
    'منح الاحترام المحدد',
  );

  /// Screen-reader label for a single value chip; the numeral alone is not
  /// meaningful spoken aloud.
  String valueLabel(int value) =>
      _s.pick('$value Respect', '$value احترام');
}
