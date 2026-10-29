import 'package:flutter/widgets.dart';

import '../../../core/l10n/app_strings.dart';

/// Bilingual copy for the members Council surfaces (spec §8 / §22).
///
/// The council sheets were Arabic-only, so the English locale showed Arabic
/// labels on destructive actions — "Transfer ownership" and "Remove" among
/// them. Destructive actions are the last place a member should have to guess,
/// which makes this a correctness fix rather than a translation nicety.
///
/// Scope note: this catalog currently covers the member action sheet. The
/// remaining council sheets (rank management, warn, kick/ban, member info) are
/// still Arabic-only and are tracked explicitly by the ratchet in
/// `test/app_language_test.dart`, so the count can only go down.
final class CouncilCopy {
  const CouncilCopy(this._s);

  final AppStrings _s;

  static CouncilCopy of(BuildContext context) =>
      CouncilCopy(AppStrings.of(context));

  static CouncilCopy forLocale(Locale? locale) =>
      CouncilCopy(AppStrings.forLocale(locale));

  // --- member action sheet ---------------------------------------------------
  String get actionsTitle => _s.pick('Member actions', 'إجراءات العضو');
  String get editRank => _s.pick('Change rank', 'تعديل الرتبة');
  String get memberInfo => _s.pick('Member info', 'معلومات العضو');
  String get profile => _s.pick('Open profile', 'الملف الشخصي');
  String get warn => _s.pick('Warn', 'تحذير');
  String get remove => _s.pick('Remove from group', 'طرد');
  String get transferOwnership =>
      _s.pick('Transfer ownership', 'نقل الملكية');
}
