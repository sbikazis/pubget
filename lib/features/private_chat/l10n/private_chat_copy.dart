import 'package:flutter/widgets.dart';

import '../../../core/l10n/app_strings.dart';

/// Localized chrome for the private chats list (spec §10.3).
final class PrivateChatCopy {
  const PrivateChatCopy(this._s);

  final AppStrings _s;

  static PrivateChatCopy of(BuildContext context) =>
      PrivateChatCopy(AppStrings.of(context));

  String get listTitle => _s.pick('Private', 'الخاص');
  String get emptyTitle =>
      _s.pick('No private chats yet', 'لا توجد محادثات خاصة بعد');
  String get emptyMessage => _s.pick(
    'Start a conversation from a Friend or Fan profile.',
    'ابدأ محادثة من ملف صديق أو معجب.',
  );
  String get findPeople => _s.pick('Find people', 'ابحث عن أشخاص');
  String get loadOlder => _s.pick('Load older chats', 'تحميل محادثات أقدم');
  String get loadFailed =>
      _s.pick('Private chats could not load.', 'تعذّر تحميل المحادثات الخاصة.');
  String get noMessages => _s.pick('No messages yet', 'لا رسائل بعد');
}
