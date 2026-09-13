import 'package:flutter/widgets.dart';

import '../../../core/l10n/app_strings.dart';
import '../data/group_image_uploader.dart';
import '../models/group_models.dart';

/// Localized chrome for group create, join, and control-panel flows.
final class GroupCopy {
  const GroupCopy(this._s);

  final AppStrings _s;

  static GroupCopy of(BuildContext context) => GroupCopy(AppStrings.of(context));

  static GroupCopy forLocale(Locale? locale) =>
      GroupCopy(AppStrings.forLocale(locale));

  String get createTitle => _s.pick('Create a group', 'إنشاء مجموعة');
  String get chooseType => _s.pick('Choose group type', 'اختر نوع المجموعة');
  String get typeLockedHint => _s.pick(
    'Type is locked. Go back and start again to change it. Your draft is saved.',
    'النوع مقفل. ارجع وابدأ من جديد لتغييره. المسودة محفوظة.',
  );
  String typeLabel(GroupType type) => _s.groupTypeLabel(type.name);
  String typeHint(GroupType type) => switch (type) {
    GroupType.public => _s.pick(
      'A community around shared interests.',
      'مجتمع حول اهتمامات مشتركة.',
    ),
    GroupType.animeRoleplay => _s.pick(
      'Roleplay tied to a specific anime.',
      'تقمص دور مبني على أنمي محدد.',
    ),
    GroupType.openRoleplay => _s.pick(
      'Roleplay with characters from any work.',
      'تقمص دور مفتوح من كل الأعمال.',
    ),
  };

  String get avatar => _s.pick('Group avatar', 'صورة المجموعة الأساسية');
  String get avatarRequired =>
      _s.pick('Avatar is required', 'صورة المجموعة إلزامية');
  String get cover => _s.pick('Cover image (optional)', 'صورة الخلفية/الغلاف');
  String get coverPreview =>
      _s.pick('Cover preview', 'معاينة الغلاف');
  String get name => _s.pick('Group name', 'اسم المجموعة');
  String get description => _s.pick('Group description', 'وصف المجموعة');
  String get rules => _s.rules;
  String get addRule => _s.pick('Add a rule', 'إضافة قانون');
  String get removeRule => _s.pick('Remove rule', 'حذف القانون');
  String get joinPolicy => _s.pick('Join policy', 'سياسة الدخول');
  String get joinClosed => _s.joinPolicyClosed;
  String get joinOpen => _s.joinPolicyOpenEveryone;
  String get confirm => _s.pick('Publish group', 'نشر المجموعة');
  String get publishing => _s.pick('Publishing…', 'جاري النشر…');
  String get working => _s.pick('Working…', 'جاري التنفيذ');
  String get retry => _s.pick('Try again', 'إعادة المحاولة');

  String get selectAnime => _s.selectAnime;
  String get selectCharacter => _s.selectCharacter;
  String get popularAnime =>
      _s.pick('Most popular anime', 'الأنميات الأكثر شعبية');
  String get popularCharacters =>
      _s.pick('Most popular characters', 'الشخصيات الأكثر شعبية');
  String get searchAnime => _s.pick('Search anime', 'ابحث عن أنمي');
  String get searchCharacters => _s.pick('Search characters', 'ابحث عن شخصية');
  String get filters => _s.pick('Filters', 'تصفية');
  String get noAnime => _s.noAnimeResults;
  String get noAnimeHint => _s.noAnimeResultsHint;
  String get noCharacters => _s.noCharacterResults;
  String get noCharactersHint => _s.noCharacterResultsHint;
  String get characterReserved => _s.characterReserved;
  String get pickImage => _s.pick('Choose image', 'اختيار صورة');
  String get imageUrl => _s.pick('Image URL', 'رابط الصورة');
  String get uploadingImage => _s.pick('Uploading image…', 'جاري رفع الصورة…');
  String get imageUploadFailed => _s.pick(
    'Image upload failed. Check your connection and try again.',
    'فشل رفع الصورة. تحقق من الاتصال ثم أعد المحاولة.',
  );
  String get imageEmpty => _s.pick(
    'The selected image is empty. Pick another file.',
    'الصورة المختارة فارغة. اختر ملفًا آخر.',
  );
  String get imageTooLarge => _s.pick(
    'Choose an image up to 10 MB.',
    'اختر صورة بحجم أقصى 10 ميغابايت.',
  );
  String get uploadPermissionDenied => _s.pick(
    'Storage rejected the upload. Sign in again, then retry.',
    'التخزين رفض الرفع. سجّل الدخول مجددًا ثم أعد المحاولة.',
  );
  String get uploadNetworkInterrupted => _s.pick(
    'Network interrupted during upload. Retry the same image.',
    'انقطع الاتصال أثناء الرفع. أعد محاولة نفس الصورة.',
  );
  String get retryImageUpload => _s.pick('Retry upload', 'إعادة محاولة الرفع');
  String get replaceImage => _s.pick('Replace image', 'استبدال الصورة');
  String get imageReady => _s.pick('Image ready', 'الصورة جاهزة');
  String get photosSection => _s.pick('Photos', 'الصور');
  String get basicsSection => _s.pick('Basics', 'المعلومات الأساسية');
  String get rulesSection => _s.pick('Rules', 'القوانين');
  String get privacySection => _s.pick('Privacy', 'الخصوصية');
  String get livePreview => _s.pick('Live preview', 'معاينة مباشرة');
  String get pasteImageUrl =>
      _s.pick('Or paste image URL', 'أو الصق رابط الصورة');
  String get signInToUpload => _s.pick(
    'Sign in to upload a group image.',
    'سجّل الدخول لرفع صورة المجموعة.',
  );

  /// Map typed upload failures to localized copy; fall back to the real message.
  String uploadErrorMessage(Object error) {
    if (error is! GroupImageUploadException) {
      return 'Upload failed: $error';
    }
    final code = (error.code ?? '').toLowerCase();
    return switch (code) {
      'empty-file' => imageEmpty,
      'too-large' => imageTooLarge,
      'unauthenticated' => signInToUpload,
      'unauthorized' || 'permission-denied' => uploadPermissionDenied,
      'unavailable' ||
      'retry-limit-exceeded' ||
      'network-request-failed' =>
        uploadNetworkInterrupted,
      _ => error.message,
    };
  }

  String get created => _s.groupCreatedTitle;
  String get copyLink => _s.copyGroupLink;
  String get shareInApp => _s.shareInApp;
  String get shareOutside => _s.shareOutside;
  String get skip => _s.skip;

  String get invitedBy => _s.invitedByOptional;
  String get acceptRules => _s.acceptGroupRules;
  String get characterReason => _s.characterReason;
  String get useDefaultImage => _s.useDefaultCharacterImage;
  String get useCustomImage => _s.useCustomCharacterImage;
  String get pending => _s.requestPending;
  String get banned => _s.bannedFromGroup;
  String get full => _s.groupCapacityReached;
  String get join => _s.joinGroup;
  String get request => _s.requestToJoin;
  String get save => _s.pick('Save', 'حفظ');
  String get groupDisbanded => _s.pick(
    'This group was disbanded. The request was cancelled.',
    'تُفككت المجموعة. أُلغي الطلب.',
  );

  String get overview => _s.pick('Overview', 'نظرة عامة');
  String get requestInbox => _s.joinRequests;
  String get manageMembers => _s.manageMembers;
  String get manageRules => _s.pick('Manage rules', 'إدارة القوانين');
  String get settings => _s.groupSettings;
  String get growth => _s.growthOverview;
  String get openChat => _s.openChat;
  String get danger => _s.dangerZone;
  String get controlPanel => _s.controlPanelTitle;
  String get memberPreview => _s.memberPreview;
  String pendingCount(int count) =>
      _s.pick('$count pending', '$count معلّق');

  String get promoteTitle =>
      _s.pick('Promote and reach', 'ترويج وانتشار المجموعة');
  String get risingEligible => _s.pick(
    'Eligible for Rising Groups.',
    'مؤهّلة للظهور ضمن المجموعات الصاعدة.',
  );
  String get risingNotEligible => _s.pick(
    'Not yet eligible for Rising Groups.',
    'غير مؤهّلة بعد للمجموعات الصاعدة.',
  );
  String get risingNeedMembers =>
      _s.pick('Need at least 2 members', 'يلزم عضوان على الأقل');
  String get risingNeedImage =>
      _s.pick('Add a group image', 'أضف صورة للمجموعة');
  String get risingNeedDescription =>
      _s.pick('Add a description', 'أضف وصفاً');
  String get risingNeedRules => _s.pick('Add group rules', 'أضف قوانين المجموعة');
  String get risingNeedActivity =>
      _s.pick('Need recent chat activity', 'يلزم نشاط حديث في الدردشة');
  String get promoteWithCoins => _s.pick(
    'Promote with 120 coins (7 days)',
    'ترويج بـ 120 عملة (7 أيام)',
  );
  String get promoting => _s.pick('Promoting…', 'جاري الترويج…');
  String get currentlyPromoted =>
      _s.pick('Promoted in discovery', 'مُروَّجة في الاكتشاف');
  String get shareGroupLink => _s.pick('Share group link', 'مشاركة رابط المجموعة');
  String get copyGroupLink => _s.pick('Copy group link', 'نسخ رابط المجموعة');
  String get newMembersWeek => _s.pick('New members this week', 'أعضاء جدد هذا الأسبوع');
  String get chatActivity => _s.pick('Chat activity', 'نشاط الدردشة');
  String get activeMembers => _s.pick('Active members', 'أعضاء نشطون');
}
