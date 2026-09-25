import 'package:flutter/widgets.dart';

import '../../../core/l10n/app_strings.dart';
import '../models/fan_work_lifecycle.dart';
import '../models/fan_work_models.dart';

/// Localized Fan Works copy, following the AnimeCopy pattern: canonical
/// English tokens live in [FanWorkStrings] and this wrapper picks the Arabic
/// rendering when the app locale is Arabic (spec §2.3).
final class FanWorkCopy {
  const FanWorkCopy(this._s);

  final AppStrings _s;

  static FanWorkCopy of(BuildContext context) =>
      FanWorkCopy(AppStrings.of(context));

  static FanWorkCopy forLocale(Locale? locale) =>
      FanWorkCopy(AppStrings.forLocale(locale));

  String get feedTitle => _ui(FanWorkStrings.feedTitle, 'أعمال المعجبين');
  String get seeAll => _ui(FanWorkStrings.seeAll, 'عرض كل أعمال المعجبين');
  String get create => _ui(FanWorkStrings.create, 'إنشاء عمل خاص');
  String get saveDraft => _ui(FanWorkStrings.saveDraft, 'حفظ المسودة');
  String get publish => _ui(FanWorkStrings.publish, 'نشر');
  String get preview => _ui(FanWorkStrings.preview, 'معاينة');
  String get archive => _ui(FanWorkStrings.archive, 'أرشفة');
  String get deleteDraft => _ui(FanWorkStrings.deleteDraft, 'حذف المسودة');
  String get share => _ui(FanWorkStrings.share, 'مشاركة العمل الخاص');
  String get copyLink => _ui(FanWorkStrings.copyLink, 'نسخ الرابط');
  String get copied => _ui(FanWorkStrings.copied, 'تم نسخ رابط العمل');
  String get report => _ui(FanWorkStrings.report, 'إبلاغ');
  String get like => _ui(FanWorkStrings.like, 'أعجبني');
  String get liked => _ui('Liked', 'أعجبك');
  String get bookmark => _ui(FanWorkStrings.bookmark, 'حفظ');
  String get bookmarked => _ui('Saved', 'تم الحفظ');
  String get rating => _ui(FanWorkStrings.rating, 'قيّم');
  String get comments => _ui(FanWorkStrings.comments, 'التعليقات');
  String get addComment => _ui(FanWorkStrings.addComment, 'أضف تعليقاً');
  String get sendComment => _ui(FanWorkStrings.sendComment, 'إرسال التعليق');
  String get noComments => _ui(FanWorkStrings.noComments, 'لا تعليقات بعد');
  String get noCommentsMessage =>
      _ui(FanWorkStrings.noCommentsMessage, 'كن أول من يرد على هذا العمل.');
  String get reply => _ui(FanWorkStrings.reply, 'رد');
  String get replyBadge => _ui('Reply', 'رد');
  String get cancelReply => _ui('Cancel reply', 'إلغاء الرد');
  String get replyingTo => _ui('Replying to', 'أنت ترد على');
  String get likeComment => _ui(FanWorkStrings.likeComment, 'أعجب بالتعليق');
  String get deleteComment => _ui(FanWorkStrings.deleteComment, 'حذف التعليق');
  String get reportComment =>
      _ui(FanWorkStrings.reportComment, 'الإبلاغ عن التعليق');
  String get missing => _ui(FanWorkStrings.missing, 'هذا العمل غير متاح.');
  String get missingHint => _ui(
    'It may be a draft, archived, or removed.',
    'قد يكون مسودة أو مؤرشفاً أو محذوفاً.',
  );
  String get emptyTitle => _ui(FanWorkStrings.emptyTitle, 'لا توجد أعمال بعد');
  String get emptyMessage =>
      _ui(FanWorkStrings.emptyMessage, 'كن أول من ينشر رسمة أو قصة أو مانغا.');
  String get draftsEmpty => _ui(FanWorkStrings.draftsEmpty, 'لا مسودات بعد');
  String get draftsEmptyMessage => _ui(
    'Start a Fan Work and save it as a draft.',
    'ابدأ عملاً واحفظه كمسودة.',
  );
  String get untitledDraft => _ui('Untitled draft', 'مسودة بدون عنوان');
  String get offlineCached =>
      _ui(FanWorkStrings.offlineCached, 'عرض أعمال محفوظة. أنت غير متصل.');
  String get offline =>
      _ui(FanWorkStrings.offline, 'أنت غير متصل. اتصل وحاول مجدداً.');
  String get aiAssisted =>
      _ui(FanWorkStrings.aiAssisted, 'مدعوم بالذكاء الاصطناعي');
  String get draftSaved => _ui(FanWorkStrings.draftSaved, 'تم حفظ المسودة');
  String get draftKept =>
      _ui('Draft kept on this device.', 'المسودة محفوظة على هذا الجهاز.');
  String get published => _ui(FanWorkStrings.published, 'تم نشر العمل');
  String get publishFailed =>
      _ui(FanWorkStrings.publishFailed, 'فشل النشر. تم الاحتفاظ بمسودتك.');
  String get uploadFailed =>
      _ui(FanWorkStrings.uploadFailed, 'فشل الرفع. تم الاحتفاظ بمسودتك.');
  String uploadProgress(int percent) =>
      _ui('$percent% uploaded', 'تم رفع $percent٪');
  String get uploadingMedia =>
      _ui(FanWorkStrings.uploadingMedia, 'جارٍ رفع الوسائط');
  String get cancelUpload => _ui(FanWorkStrings.cancelUpload, 'إلغاء الرفع');
  String get retryUpload =>
      _ui(FanWorkStrings.retryUpload, 'إعادة محاولة الرفع');
  String get uploadCanceled =>
      _ui(FanWorkStrings.uploadCanceled, 'أُلغي الرفع. تم الاحتفاظ بمسودتك.');
  String get chooseType => _ui(FanWorkStrings.chooseType, 'اختر نوعاً');
  String get basicInfo => _ui(FanWorkStrings.basicInfo, 'المعلومات الأساسية');
  String get mediaContent =>
      _ui(FanWorkStrings.mediaContent, 'الوسائط والمحتوى');
  String get tagsAnime => _ui(FanWorkStrings.tagsAnime, 'الوسوم والأنمي');
  String get copyright => _ui(FanWorkStrings.copyright, 'حقوق النشر والمصدر');
  String get requestRemoval => _ui(FanWorkStrings.requestRemoval, 'طلب إزالة');
  String get revised => _ui(FanWorkStrings.revised, 'تم حفظ المراجعة');
  String get revisions => _ui(FanWorkStrings.revisions, 'سجل المراجعات');
  String get noRevisions => _ui(FanWorkStrings.noRevisions, 'لا مراجعات بعد');
  String get version => _ui(FanWorkStrings.version, 'النسخة');
  String get load => _ui('Load', 'تحميل');
  String get loading => _ui('Loading…', 'جاري التحميل…');
  String get loadMore => _ui('Load more', 'تحميل المزيد');
  String get loadMoreComments =>
      _ui('Load more comments', 'تحميل المزيد من التعليقات');
  String get editDraft => _ui('Edit draft', 'تعديل المسودة');
  String get saveRevisionMetadata =>
      _ui('Save revision metadata', 'حفظ بيانات المراجعة');
  String get readManga => _ui('Read manga', 'قراءة المانغا');
  String get readStory => _ui('Read story', 'قراءة القصة');
  String get latest => _ui('Latest', 'الأحدث');
  String get allTypes => _ui('All', 'الكل');
  String get works => _ui('Works', 'الأعمال');
  String get analytics => _ui('Analytics', 'الإحصائيات');
  String get analyticsOwnOnly => _ui(
    'Analytics available for your own works',
    'الإحصائيات متاحة لأعمالك أنت فقط.',
  );
  String get couldNotLoadFanWorks =>
      _ui('Could not load fan works.', 'تعذّر تحميل الأعمال الخاصة.');
  String get couldNotLoadAnalytics =>
      _ui('Could not load analytics.', 'تعذّر تحميل الإحصائيات.');
  String get noFanWorksOwner =>
      _ui('No fan works yet', 'لا توجد أعمال خاصة بعد');
  String get noFanWorksVisitor =>
      _ui('No fan works to show', 'لا توجد أعمال خاصة للعرض');
  String get shareAWorkHint => _ui(
    'Share a drawing, manga page, or story.',
    'شارك رسمة أو صفحة مانغا أو قصة.',
  );
  String get creatorNoWorksHint => _ui(
    'This creator has not shared works yet.',
    'لم يشارك هذا المنشئ أعمالاً بعد.',
  );
  String get totalWorks => _ui('Total Works', 'إجمالي الأعمال');
  String get publishedLabel => _ui('Published', 'منشور');
  String get draftsLabel => _ui('Drafts', 'مسودات');
  String get totalLikes => _ui('Total Likes', 'إجمالي الإعجابات');
  String get totalSaves => _ui('Total Saves', 'إجمالي الحفظ');
  String get totalComments => _ui('Total Comments', 'إجمالي التعليقات');
  String get avgRating => _ui('Avg Rating', 'متوسط التقييم');
  String get totalRatings => _ui('Total Ratings', 'إجمالي التقييمات');
  String get worksByType => _ui('Works by Type', 'الأعمال حسب النوع');
  String get topWorks => _ui('Top Works', 'أفضل الأعمال');
  String get fanWorkNotFound =>
      _ui('Fan Work not found.', 'تعذّر العثور على هذا العمل.');
  String get untitled => _ui('Untitled', 'بدون عنوان');
  String get homeStripEmpty => _ui(
    'Fan Works will appear here after they are published.',
    'ستظهر الأعمال الخاصة هنا بعد نشرها.',
  );
  String get titleLabel => _ui('Title', 'العنوان');
  String get titleHint => _ui('Give this work a name', 'أعطِ هذا العمل اسماً');
  String get descriptionLabel => _ui('Description', 'الوصف');
  String get descriptionHint =>
      _ui('What is this work about?', 'ما موضوع هذا العمل؟');
  String get tagsLabel => _ui('Tags', 'الوسوم');
  String get tagsHintEnEditor => _ui('demonslayer, tanjiro', 'شيطان، تانجيرو');
  String get tagsHintEnWidgets =>
      _ui('demonslayer, tanjiro, drawing', 'شيطان، تانجيرو، رسمة');
  String get tagsHelperEditor => _ui(
    'Up to 8 tags. Values are normalized.',
    'حتى 8 وسوم. تتم معايرة القيم.',
  );
  String get tagsHelperWidgets => _ui(
    'Up to 8 tags. Hashtags are normalized.',
    'حتى 8 وسوم. تتم معايرة الوسوم.',
  );
  String get relatedAnimeId => _ui('Related anime ID', 'معرّف الأنمي المرتبط');
  String get optionalAnimeIdentifier =>
      _ui('Optional anime identifier', 'معرّف أنمي اختياري');
  String get relatedAnimeTitle =>
      _ui('Related anime title', 'عنوان الأنمي المرتبط');
  String get optionalDisplayTitle =>
      _ui('Optional display title', 'عنوان عرض اختياري');
  String get originalWorkId => _ui('Original work ID', 'معرّف العمل الأصلي');
  String get optionalSourceIdentifier =>
      _ui('Optional source identifier', 'معرّف المصدر اختياري');
  String get sourceTitle => _ui('Source title', 'عنوان المصدر');
  String get originalSeriesOrWork =>
      _ui('Original series or work', 'السلسلة أو العمل الأصلي');
  String get creditLabel => _ui('Credit', 'الاعتماد');
  String get creditHint =>
      _ui('How this work should be credited', 'كيف يُنسب هذا العمل');
  String get storyLabel => _ui('Story', 'قصة');
  String get contentLabel => _ui('Content', 'المحتوى');
  String get nameLabel => _ui('Name', 'الاسم');
  String get personalityLabel => _ui('Personality', 'الشخصية');
  String get abilitiesLabel => _ui('Abilities', 'القدرات');
  String get backgroundLabel => _ui('Background', 'الخلفية');
  String get loreLabel => _ui('Lore', 'العالم');
  String get locationsLabel => _ui('Locations', 'المواقع');
  String get factionsLabel => _ui('Factions', 'الفصائل');
  String get charactersLabel => _ui('Characters', 'الشخصيات');
  String get pagesLabel => _ui('Pages', 'الصفحات');
  String get imagesLabel => _ui('Images', 'الصور');
  String get chaptersLabel => _ui('Chapters', 'الفصول');
  String get chapterTitleLabel => _ui('Chapter title', 'عنوان الفصل');
  String get chapterTextLabel => _ui('Chapter text', 'نص الفصل');
  String get addPage => _ui('Add page', 'إضافة صفحة');
  String get addImage => _ui('Add image', 'إضافة صورة');
  String get addChapter => _ui('Add chapter', 'إضافة فصل');
  String get optionalCaption => _ui('Optional caption', 'تعليق اختياري');
  String get noPagesYet => _ui('No pages yet', 'لا صفحات بعد');
  String get mangaNoPages => _ui(
    'This manga does not have pages to display.',
    'لا توجد صفحات لهذه المانغا للعرض.',
  );
  String get storyNoContent => _ui(
    'This story has no content yet.',
    'لا تحتوي هذه القصة على محتوى بعد.',
  );
  String get storyFallback => _ui('Story', 'قصة');
  String get mangaFallback => _ui('Manga', 'مانغا');
  String get aiAssistedNotice => _ui(
    'This work is labeled as AI-assisted. Pubget does not generate the character in this version.',
    'يُعلَّم هذا العمل على أنه مدعوم بالذكاء الاصطناعي. لا يولّد Pubget الشخصية في هذا الإصدار.',
  );

  String typeLabel(FanWorkType type) {
    final label = switch (type) {
      FanWorkType.manga => 'Manga',
      FanWorkType.drawing => 'Drawing',
      FanWorkType.story => 'Story',
      FanWorkType.character => 'Character',
      FanWorkType.aiCharacter => 'AI-assisted character',
      FanWorkType.worldbuilding => 'Worldbuilding',
      FanWorkType.other => 'Other',
    };
    return switch (label) {
      'Manga' => _ui('Manga', 'مانغا'),
      'Drawing' => _ui('Drawing', 'رسمة'),
      'Story' => _ui('Story', 'قصة'),
      'Character' => _ui('Character', 'شخصية'),
      'AI-assisted character' => _ui(
        'AI-assisted character',
        'شخصية مدعومة بالذكاء الاصطناعي',
      ),
      'Worldbuilding' => _ui('Worldbuilding', 'بناء عالم'),
      _ => _ui('Other', 'أخرى'),
    };
  }

  String reportReason(FanWorkReportReason reason) =>
      _s.reportReasonLabel(reason.name);

  String publishedOn(DateTime publishedAt) {
    final date = publishedAt.toLocal().toIso8601String().split('T').first;
    return _s.pick('Published $date', '$date المنشور');
  }

  String relatedAnime(String title) =>
      _s.pick('Related anime: $title', 'أنمي مرتبط: $title');

  String sourceLine(String title) =>
      _s.pick('Source: $title', 'المصدر: $title');

  String originalId(String id) =>
      _s.pick('Original ID: $id', 'المعرّف الأصلي: $id');

  String credit(String text) => _s.pick('Credit: $text', 'الاعتماد: $text');

  String revisionNumber(int version) =>
      _s.pick('Revision $version', 'المراجعة $version');

  String versionNumber(int version) =>
      _s.pick('Version $version', 'النسخة $version');

  String characterRefs(String ids) =>
      _s.pick('Character refs: $ids', 'الشخصيات: $ids');

  String likes(int count) =>
      _s.pick(count == 1 ? '1 like' : '$count likes', '$count إعجاب');

  String commentsCount(int count) =>
      _s.pick(count == 1 ? '1 comment' : '$count comments', '$count تعليق');

  String saves(int count) =>
      _s.pick(count == 1 ? '1 save' : '$count saves', '$count حفظ');

  String ratings(int count) =>
      _s.pick(count == 1 ? '1 rating' : '$count ratings', '$count تقييم');

  String pageOf(int total, int n) =>
      _s.pick('Page $n of $total', 'الصفحة $n من $total');

  String pageNumber(int n) => _s.pick('Page $n', 'الصفحة $n');

  String chapterNumber(int n) => _s.pick('Chapter $n', 'الفصل $n');

  String addSection(String title) => _s.pick('Add $title', 'إضافة $title');

  String addSectionItem(String title) =>
      _s.pick('Add $title item', 'إضافة عنصر $title');

  String draftStillOnDevice(String error) => _s.pick(
    '$error Your draft is still on this device.',
    '$error المسودة ما زالت على هذا الجهاز.',
  );

  String lifecycleError(String? message) {
    if (message == null) return '';
    return switch (message) {
      'A title between 3 and 80 characters is required.' => _s.pick(
        message,
        'العنوان المطلوب بين 3 و80 حرفاً.',
      ),
      'Manga needs at least one page.' => _s.pick(
        message,
        'المانغا تحتاج صفحة واحدة على الأقل.',
      ),
      'A drawing needs at least one image.' => _s.pick(
        message,
        'الرسمة تحتاج صورة واحدة على الأقل.',
      ),
      'A story needs written content.' => _s.pick(
        message,
        'القصة تحتاج محتوى مكتوباً.',
      ),
      'A character name is required.' => _s.pick(message, 'اسم الشخصية مطلوب.'),
      'A character needs a description or background.' => _s.pick(
        message,
        'الشخصية تحتاج وصفاً أو خلفية.',
      ),
      'Worldbuilding needs lore or a description.' => _s.pick(
        message,
        'بناء العالم يحتاج خلفية أو وصفاً.',
      ),
      'This work needs a description, written content, or media.' => _s.pick(
        message,
        'هذا العمل يحتاج وصفاً أو محتوى مكتوباً أو وسائط.',
      ),
      'Use a JPEG, PNG, WEBP, or GIF image.' => _s.pick(
        message,
        'استخدم صورة JPEG أو PNG أو WEBP أو GIF.',
      ),
      'Images must be 10 MB or smaller.' => _s.pick(
        message,
        'يجب ألا يتجاوز حجم الصور 10 ميغابايت.',
      ),
      _ => message,
    };
  }

  String _ui(String en, String ar) => _s.pick(en, ar);
}
