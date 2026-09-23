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

  // ── 7-step create wizard ────────────────────────────────────────────────
  String get step1Title => _s.pick('Identity', 'الهوية');
  String get step2Title => _s.pick('Type', 'النوع');
  String get step3Title => _s.pick('Rules & privacy', 'القواعد والخصوصية');
  String get step4Title => _s.pick('Customization', 'التخصيص');
  String get step5Title => _s.pick('Roles & permissions', 'الرتب والصلاحيات');
  String get step6Title => _s.pick('Preview', 'المعاينة');
  String get step7Title => _s.pick('Publish', 'النشر');
  String get back => _s.pick('Back', 'رجوع');
  String get next => _s.pick('Next', 'التالي');
  String get review => _s.pick('Review', 'مراجعة');
  String get typeSelectionHint => _s.pick(
    'Pick the group type. Public groups are communities; roleplay groups '
    '(anime or open) reserve a founder character.',
    'اختر نوع المجموعة. المجموعات العامة مجتمعات، بينما تحجز مجموعة التقمص '
    'شخصية للمؤسس.',
  );

  // Step 3 — rules & privacy.
  String get rulesAndPrivacy => _s.pick('Rules & privacy', 'القواعد والخصوصية');
  String get rulesAndPrivacyHint => _s.pick(
    'Choose who can join, the member limit, and content rules.',
    'اختر من يمكنه الانضمام وحد الأعضاء وقواعد المحتوى.',
  );
  String get joinPolicySection => _s.pick('Who can join', 'من يمكنه الانضمام');
  String get joinInviteOnly => _s.pick('Invite only', 'بالدعوة فقط');
  String get joinInviteOnlyHint => _s.pick(
    'Only invited people can join.',
    'لا يمكن الانضمام إلا بالدعوة.',
  );
  String get joinApproval => _s.pick('Request to join', 'طلب انضمام');
  String get joinApprovalHint => _s.pick(
    'Members approve each request.',
    'يوافق الأعضاء على كل طلب.',
  );
  String get joinOpenHint => _s.pick(
    'Anyone can join instantly.',
    'يمكن لأي شخص الانضمام فوراً.',
  );
  String get memberLimitSection => _s.pick('Member limit', 'حد الأعضاء');
  String get maxMembersLabel => _s.pick('Max members', 'الحد الأقصى للأعضاء');
  String maxMembersHint(int limit) => _s.pick(
    'Custom limit up to $limit',
    'حد مخصص حتى $limit',
  );
  String maxMembersRange(int min, int max) => _s.pick(
    'Between $min and $max members.',
    'بين $min و $max عضواً.',
  );
  String get contentRulesSection => _s.pick('Content rules', 'قواعد المحتوى');

  // Step 4 — customization.
  String get customizationTitle => _s.pick('Customization', 'التخصيص');
  String get customizationHint => _s.pick(
    'Make the group yours — welcome message and chat background.',
    'اجعل المجموعة بصمتك — رسالة الترحيب وخلفية الدردشة.',
  );
  String get welcomeMessageSection => _s.pick(
    'Welcome message',
    'رسالة الترحيب',
  );
  String get welcomeMessageLabel => _s.pick(
    'Custom welcome message (optional)',
    'رسالة ترحيب مخصصة (اختياري)',
  );
  String get welcomeMessageHint => _s.pick(
    'Shown automatically to every new member.',
    'تُعرض تلقائياً لكل عضو جديد.',
  );
  String get chatBackgroundSection => _s.pick(
    'Chat background',
    'خلفية الدردشة',
  );
  String get chatBackgroundLabel => _s.pick(
    'Background image URL (optional)',
    'رابط صورة الخلفية (اختياري)',
  );
  String get chatBackgroundHint => _s.pick(
    'A remote image shown behind chat bubbles.',
    'صورة عن بُعد توضع خلف فقاعات الدردشة.',
  );
  String get chatBackgroundHintDetail => _s.pick(
    'Contrast is adjusted automatically so messages stay readable.',
    'يُعدّل التباين تلقائياً لتبقى الرسائل مقروءة دائماً.',
  );

  // Step 6 — preview.
  String get previewTitle => _s.pick('Preview', 'المعاينة');
  String get previewHint => _s.pick(
    'Review your group before publishing.',
    'راجع مجموعتك قبل النشر.',
  );
  String get basicInfo => _s.pick('Basic info', 'المعلومات الأساسية');
  String get typeLabelPreview => _s.pick('Type', 'النوع');
  String get anime => _s.pick('Anime', 'الأنمي');
  String get maxMembersLabelPreview => _s.pick('Capacity', 'السعة');
  String get joinPolicyLabelTitle => _s.pick('Join policy', 'سياسة الدخول');
  String joinPolicyLabelValue(String name) {
    final policy = JoinPolicy.values.firstWhere(
      (value) => value.name == name,
      orElse: () => JoinPolicy.open,
    );
    return switch (policy) {
      JoinPolicy.open => joinOpen,
      JoinPolicy.approval => joinApproval,
      JoinPolicy.inviteOnly => joinInviteOnly,
    };
  }

  String get noWelcomeMessage => _s.pick(
    'No welcome message set.',
    'لا توجد رسالة ترحيب.',
  );

  // Step 7 — publish.
  String get finalStep => _s.pick('Ready to publish?', 'جاهز للنشر؟');
  String finalStepHint(String name) => _s.pick(
    'Your group “$name” will be live the moment you publish.',
    'ستكون مجموعتك “$name” متاحة فور النشر.',
  );
  String get readyToPublish => _s.pick(
    'Publish checklist',
    'قائمة فحص النشر',
  );
  String get checkName => _s.pick('Group name set', 'اسم المجموعة مُحدد');
  String get checkImage => _s.pick(
    'Group image verified',
    'صورة المجموعة مؤكدة',
  );
  String get checkType => _s.pick('Group type selected', 'نوع المجموعة محدد');
  String get checkRules => _s.pick(
    'Content rules ready',
    'قواعد المحتوى جاهزة',
  );
  String get checkPermissions => _s.pick(
    'Permission presets applied',
    'مصفوفة الصلاحيات مطبقة',
  );
  String get publishGroup => _s.pick('Publish group', 'نشر المجموعة');
  String get fillRequiredFields => _s.pick(
    'Complete the required fields to publish.',
    'أكمل الحقول المطلوبة للنشر.',
  );

  // Step 5 / Step 6 shared roleplay chrome.
  String get roleplayCharacterSection => _s.pick(
    'Roleplay character',
    'شخصية التقمص',
  );
  String get reservedForFounder => _s.pick(
    'Reserved for the founder',
    'محجوزة للمؤسس',
  );
  String get groupNamePlaceholder => _s.pick('Group name', 'اسم المجموعة');
  String get permissionsTitle => _s.pick(
    'Role permissions',
    'صلاحيات الرتب',
  );
  String get permissionsHint => _s.pick(
    'The permission matrix is applied automatically per group type. The '
    'founder (MIKADO) holds every permission.',
    'مصفوفة الصلاحيات ستُطبَّق تلقائياً حسب نوع المجموعة. المؤسس (MIKADO) '
    'يملك جميع الصلاحيات.',
  );
  String get roleplayRanksNote => _s.pick(
    'Roleplay groups: members start as RŌNIN with a chosen character. Ranks '
    'are granted manually or automatically by invites and activity.',
    'مجموعات تقمص الدور: يبدأ الأعضاء بـ RŌNIN مع شخصية مختارة. الرتب تُمنح '
    'يدوياً أو تلقائياً حسب الدعوات والنشاط.',
  );
  String get rolesNotesTitle => _s.pick('Important notes', 'ملاحظات مهمة');
  String get founderNote => _s.pick(
    'The founder rank (MIKADO) is never granted to anyone else',
    'رتبة المؤسس (MIKADO) لا تُمنح لأحد آخر',
  );
  String get shogunNote => _s.pick(
    'There is only one SHŌGUN seat per group',
    'SHŌGUN سقف واحد فقط لكل مجموعة',
  );
  String get daimyoNote => _s.pick(
    'DAIMYŌ seats cap at 3 (2 manual + 1 auto)',
    'DAIMYŎ حد أقصى 3 (2 يدوي + 1 تلقائي)',
  );
  String get roleChangeNote => _s.pick(
    'Rank changes require confirmation and are recorded in the audit log',
    'تغيير الرتب يتطلب تأكيداً ومسجلة في سجل التدقيق',
  );
  String get serverSideOnlyNote => _s.pick(
    'Permissions are enforced server-side only — the client is view-only',
    'الصلاحيات تُفحص Server-side فقط — العميل للعرض فقط',
  );
  String get permissionsMatrix => _s.pick(
    'Permission matrix',
    'مصفوفة الصلاحيات',
  );
  String get permissionColumn => _s.pick('Permission', 'الصلاحية');
  String permissionLabel(GroupPermission permission) => switch (permission) {
    GroupPermission.invite => _s.pick('Invite members', 'دعوة أعضاء'),
    GroupPermission.pinOwnMessages => _s.pick(
      'Pin own messages',
      'تثبيت رسائله الخاصة',
    ),
    GroupPermission.promoteContent => _s.pick(
      'Promote content',
      'ترويج المحتوى',
    ),
    GroupPermission.manageRequests => _s.pick(
      'Manage join requests',
      'إدارة طلبات الانضمام',
    ),
    GroupPermission.manageEvents => _s.pick('Manage events', 'إدارة الأحداث'),
    GroupPermission.moderateChat => _s.pick(
      'Moderate chat',
      'إشراف الدردشة',
    ),
    GroupPermission.deleteMessages => _s.pick(
      'Delete others’ messages',
      'حذف رسائل الآخرين',
    ),
    GroupPermission.manageGames => _s.pick('Manage games', 'إدارة الألعاب'),
    GroupPermission.kickBan => _s.pick(
      'Kick / ban members',
      'طرد/حظر الأعضاء',
    ),
    GroupPermission.unban => _s.pick('Unban', 'إلغاء الحظر'),
    GroupPermission.manageBackground => _s.pick(
      'Change chat background',
      'تغيير خلفية الدردشة',
    ),
    GroupPermission.manageSettings => _s.pick(
      'Manage group settings',
      'إدارة إعدادات المجموعة',
    ),
    GroupPermission.manageRoles => _s.pick(
      'Manage roles (capped seats)',
      'إدارة الرتب (سقف محدد)',
    ),
  };

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

  // Roleplay character reservation tray.
  String get roleplayCharacterTitle =>
      _s.pick('Choose a character', 'اختر شخصية');
  String get reserveCharacter => _s.pick('Reserve', 'حجز');
  String get roleplayNoCharacters =>
      _s.pick('No characters available', 'لا توجد شخصيات متاحة');
  String get roleplayAllReserved => _s.pick(
    'All characters for this group are already reserved.',
    'كل شخصيات هذه المجموعة محجوزة بالفعل.',
  );
  String get roleplayCharactersLoadFailed => _s.pick(
    'Characters could not load.',
    'تعذّر تحميل الشخصيات.',
  );
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
