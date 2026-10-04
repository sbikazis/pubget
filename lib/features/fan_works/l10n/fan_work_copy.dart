import 'package:flutter/widgets.dart';

import '../../../core/l10n/app_strings.dart';
import '../models/fan_work_lifecycle.dart';
import '../models/fan_work_models.dart';
import '../models/fan_work_taxonomy.dart';

/// Localized Fan Works copy, following the AnimeCopy pattern: canonical
/// English tokens live in [FanWorkStrings] and this wrapper picks the Arabic
/// rendering when the app locale is Arabic (spec §1.4).
///
/// A single English word left in the Arabic build is a critical defect, so
/// every user-visible string in this feature resolves through here.
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
  String get chooseType => _ui(FanWorkStrings.chooseType, 'اختر نوع العمل');
  String get saveDraft => _ui(FanWorkStrings.saveDraft, 'حفظ المسودة');
  String get publish => _ui(FanWorkStrings.publish, 'نشر');
  String get preview => _ui(FanWorkStrings.preview, 'معاينة');
  String get archive => _ui(FanWorkStrings.archive, 'أرشفة');
  String get deleteDraft => _ui(FanWorkStrings.deleteDraft, 'حذف المسودة');
  String get share => _ui(FanWorkStrings.share, 'مشاركة العمل');
  String get copyLink => _ui(FanWorkStrings.copyLink, 'نسخ الرابط');
  String get copied => _ui(FanWorkStrings.copied, 'تم نسخ رابط العمل');
  String get report => _ui(FanWorkStrings.report, 'إبلاغ');
  String get like => _ui(FanWorkStrings.like, 'أعجبني');
  String get liked => _ui(FanWorkStrings.liked, 'أعجبك');
  String get bookmark => _ui(FanWorkStrings.bookmark, 'حفظ');
  String get bookmarked => _ui(FanWorkStrings.bookmarked, 'تم الحفظ');
  String get rating => _ui(FanWorkStrings.rating, 'قيّم');
  String get comments => _ui(FanWorkStrings.comments, 'التعليقات');
  String get addComment => _ui(FanWorkStrings.addComment, 'أضف تعليقاً');
  String get sendComment => _ui(FanWorkStrings.sendComment, 'إرسال التعليق');
  String get noComments => _ui(FanWorkStrings.noComments, 'لا تعليقات بعد');
  String get noCommentsMessage =>
      _ui(FanWorkStrings.noCommentsMessage, 'كن أول من يرد على هذا العمل.');
  String get reply => _ui(FanWorkStrings.reply, 'رد');
  String get likeComment => _ui(FanWorkStrings.likeComment, 'أعجبني بالتعليق');
  String get deleteComment => _ui(FanWorkStrings.deleteComment, 'حذف التعليق');
  String get reportComment =>
      _ui(FanWorkStrings.reportComment, 'الإبلاغ عن التعليق');
  String get missing => _ui(FanWorkStrings.missing, 'هذا العمل غير متاح.');
  String get missingHint => _ui(
    'It may be a draft, archived, or removed.',
    'قد يكون مسودة أو مؤرشفاً أو محذوفاً.',
  );
  String get emptyTitle => _ui(FanWorkStrings.emptyTitle, 'لا توجد أعمال بعد');
  String get emptyMessage => _ui(
    FanWorkStrings.emptyMessage,
    'كن أول من ينشر مانغا أو قصة أو رسمة أو شخصية.',
  );
  String get draftsEmpty => _ui(FanWorkStrings.draftsEmpty, 'لا مسودات بعد');
  String get draftsEmptyMessage => _ui(
    'Start a work and it will be saved here until you publish it.',
    'ابدأ عملاً وسيُحفظ هنا حتى تنشره.',
  );
  String get offlineCached =>
      _ui(FanWorkStrings.offlineCached, 'عرض أعمال محفوظة. أنت غير متصل.');
  String get offline =>
      _ui(FanWorkStrings.offline, 'أنت غير متصل. اتصل وحاول مجدداً.');
  String get aiAssisted => _ui(FanWorkStrings.aiAssisted, 'بمساعدة الذكاء');
  String get draftSaved => _ui(FanWorkStrings.draftSaved, 'تم حفظ المسودة');
  String get published => _ui(FanWorkStrings.published, 'تم نشر العمل');
  String get publishFailed =>
      _ui(FanWorkStrings.publishFailed, 'فشل النشر. تم الاحتفاظ بمسودتك.');
  String get uploadFailed =>
      _ui(FanWorkStrings.uploadFailed, 'فشل الرفع. تم الاحتفاظ بمسودتك.');
  String get uploadingMedia => _ui(FanWorkStrings.uploadingMedia, 'جارٍ الرفع');
  String get cancelUpload => _ui(FanWorkStrings.cancelUpload, 'إلغاء الرفع');
  String get retryUpload =>
      _ui(FanWorkStrings.retryUpload, 'إعادة محاولة الرفع');
  String get uploadCanceled =>
      _ui(FanWorkStrings.uploadCanceled, 'أُلغي الرفع. تم الاحتفاظ بمسودتك.');
  String get uploadAlreadyRunning =>
      _ui(FanWorkStrings.uploadAlreadyRunning, 'هناك رفع قيد التقدم بالفعل.');
  String get uploadNothingToRetry =>
      _ui(FanWorkStrings.uploadNothingToRetry, 'لا يوجد رفع لإعادته.');

  String get basicInfo => _ui(FanWorkStrings.basicInfo, 'المعلومات الأساسية');
  String get category => _ui(FanWorkStrings.category, 'التصنيف');
  String get chooseCategory =>
      _ui(FanWorkStrings.chooseCategory, 'اختر التصنيف');
  String get cover => _ui(FanWorkStrings.cover, 'الغلاف');
  String get chooseCover => _ui(FanWorkStrings.chooseCover, 'اختيار الغلاف');
  String get creatorNote => _ui(FanWorkStrings.creatorNote, 'نبذة عن الكاتب');
  String get creatorNoteOptional =>
      _ui(FanWorkStrings.creatorNoteOptional, 'اختياري');
  String get creatorNoteHint => _ui(
    'Tell readers who you are or what inspired this.',
    'عرّف القرّاء بنفسك أو بما ألهمك.',
  );
  String get mangaPdf => _ui(FanWorkStrings.mangaPdf, 'ملف المانغا');
  String get mangaPdfHint => _ui(
    FanWorkStrings.mangaPdfHint,
    'ملف PDF واحد يحتوي كل الصفحات بترتيب القراءة.',
  );
  String get storyPdf => _ui(FanWorkStrings.storyPdf, 'ملف القصة');
  String get storyPdfHint => _ui(
    FanWorkStrings.storyPdfHint,
    'ملف PDF واحد يحتوي القصة كاملة بترتيب القراءة.',
  );
  String get choosePdf => _ui(FanWorkStrings.choosePdf, 'اختيار ملف PDF');
  String get replacePdf => _ui(FanWorkStrings.replacePdf, 'استبدال الملف');
  String get removePdf => _ui(FanWorkStrings.removePdf, 'إزالة الملف');
  String get drawingImage => _ui(FanWorkStrings.drawingImage, 'الرسمة');
  String get chooseDrawing =>
      _ui(FanWorkStrings.chooseDrawing, 'اختيار الرسمة');
  String get characterPortrait =>
      _ui(FanWorkStrings.characterPortrait, 'صورة الشخصية');
  String get choosePortrait =>
      _ui(FanWorkStrings.choosePortrait, 'اختيار صورة الشخصية');

  String get cast => _ui(FanWorkStrings.cast, 'الشخصيات');
  String charactersCount(int count) => _s.pick(
    count == 1 ? '1 character' : '$count characters',
    count == 1 ? 'شخصية واحدة' : '$count شخصية',
  );

  String get castEmpty => _ui(FanWorkStrings.castEmpty, 'لا توجد شخصيات بعد');
  String get castEmptyMessage => _ui(
    FanWorkStrings.castEmptyMessage,
    'أضف الشخصيات التي تظهر في هذا العمل.',
  );
  String get addCharacter => _ui(FanWorkStrings.addCharacter, 'إضافة شخصية');
  String get editCharacter =>
      _ui(FanWorkStrings.editCharacter, 'تعديل الشخصية');
  String get characterName => _ui(FanWorkStrings.characterName, 'اسم الشخصية');
  String get characterBio =>
      _ui(FanWorkStrings.characterBio, 'نبذة عن الشخصية');
  String get characterBioOptional =>
      _ui(FanWorkStrings.characterBioOptional, 'اختياري');
  String get characterImage =>
      _ui(FanWorkStrings.characterImage, 'صورة الشخصية');
  String get characterImageOptional =>
      _ui(FanWorkStrings.characterImageOptional, 'اختياري');
  String get saveCharacter => _ui(FanWorkStrings.saveCharacter, 'حفظ الشخصية');
  String get removeCharacter =>
      _ui(FanWorkStrings.removeCharacter, 'حذف الشخصية');
  String get characterStory =>
      _ui(FanWorkStrings.characterStory, 'قصة الشخصية');
  String get characterPersonality => _ui('Personality', 'الشخصية');
  String get characterStoryHint =>
      _ui('How this character thinks and feels', 'كيف يفكر هذا الشعوره ويشعر');
  String get castLimitReached => _s.pick(
    'You can add up to ${FanWorkLifecycle.maxCharacters} characters.',
    'يمكنك إضافة ${FanWorkLifecycle.maxCharacters} شخصيات كحد أقصى.',
  );
  String get characterAbilities =>
      _ui(FanWorkStrings.characterAbilities, 'القدرات');
  String get characterAbilitiesOptional =>
      _ui(FanWorkStrings.characterAbilitiesOptional, 'اختياري');
  String get characterSpecs => _ui(FanWorkStrings.characterSpecs, 'المواصفات');
  String get characterSpecsOptional =>
      _ui(FanWorkStrings.characterSpecsOptional, 'اختياري');
  String get characterOrigin =>
      _ui(FanWorkStrings.characterOrigin, 'كيف صُنعت هذه الشخصية؟');
  String get originHandmade =>
      _ui(FanWorkStrings.originHandmade, 'بصناعة اليد');
  String get originAi => _ui(FanWorkStrings.originAi, 'بمساعدة الذكاء');

  String get readNow => _ui(FanWorkStrings.readNow, 'اقرأ');
  String get continueReading =>
      _ui(FanWorkStrings.continueReading, 'أكمل القراءة');
  String get startReading => _ui(FanWorkStrings.startReading, 'ابدأ القراءة');
  String get resumeFrom => _ui(FanWorkStrings.resumeFrom, 'متابعة من');
  String get markAsRead => _ui(FanWorkStrings.markAsRead, 'تمّت القراءة');
  String get markedAsRead =>
      _ui(FanWorkStrings.markedAsRead, 'تم تعليمه كمقروء');
  String get openDocument => _ui(FanWorkStrings.openDocument, 'فتح');
  String get documentProtected =>
      _ui(FanWorkStrings.documentProtected, 'ملف محمي');
  String get documentProtectedHint => _ui(
    FanWorkStrings.documentProtectedHint,
    'يُفتح هذا الملف داخل Pubget ولا يُشارك أبداً كرابط تحميل.',
  );
  String get documentExpired => _ui(
    FanWorkStrings.documentExpired,
    'انتهت صلاحية رابط القراءة. أعد الفتح للمتابعة.',
  );
  String get documentUnavailable =>
      _ui(FanWorkStrings.documentUnavailable, 'تعذّر فتح هذا الملف.');
  String get documentPages => _ui(FanWorkStrings.documentPages, 'صفحة');
  String get tableOfContents => _ui(FanWorkStrings.tableOfContents, 'الصفحات');
  String get zoomIn => _ui('Zoom in', 'تكبير');
  String get zoomOut => _ui('Zoom out', 'تصغير');
  String get nextPage => _ui('Next page', 'الصفحة التالية');
  String get previousPage => _ui('Previous page', 'الصفحة السابقة');
  String chapterNumber(int number) =>
      _s.pick('Chapter $number', 'الفصل $number');
  String get storyNoContent =>
      _ui('This story has no readable content.', 'لا يوجد محتوى في هذه القصة.');
  String get mangaFallback => _ui('Manga', 'مانغا');
  String get storyFallback => _ui('Story', 'قصة');
  String get noPagesYet => _ui('No pages yet', 'لا توجد صفحات بعد');
  String get mangaNoPages => _ui(
    'This manga has no readable pages.',
    'لا توجد صفحات قابلة للقراءة في هذه المانغا.',
  );
  String get load => _ui('Load', 'تحميل');
  String get loadMore => _ui('Load more', 'تحميل المزيد');
  String get loading => _ui('Loading', 'جارٍ التحميل');
  String get replyingTo => _ui('Replying to', 'ترد على');
  String get cancelReply => _ui('Cancel reply', 'إلغاء الرد');
  String get replyBadge => _ui('Reply', 'رد');
  String get loadMoreComments =>
      _ui('Load more comments', 'تحميل تعليقات أكثر');
  String get editDraft => _ui('Edit draft', 'تعديل المسودة');
  String get untitledDraft => _ui('Untitled draft', 'مسودة بلا عنوان');
  String get latest => _ui('Latest', 'الأحدث');
  String get allTypes => _ui('All types', 'كل الأنواع');
  String get draftKept => _ui(
    'Your draft is still on this device.',
    'مسودتك ما زالت على هذا الجهاز.',
  );
  String get saveRevisionMetadata => _ui('Save revision', 'حفظ المراجعة');
  String get closeReader => _ui(FanWorkStrings.closeReader, 'إغلاق القارئ');
  String get goToPage => _ui(FanWorkStrings.goToPage, 'اذهب إلى صفحة');
  String get loadingDocument =>
      _ui(FanWorkStrings.loadingDocument, 'جارٍ فتح الملف');
  String get noPages => _ui('This file has no pages.', 'هذا الملف بلا صفحات.');

  String get tagsAnime => _ui(FanWorkStrings.tagsAnime, 'الوسوم والأنمي');
  String get copyright => _ui(FanWorkStrings.copyright, 'حقوق النشر والمصدر');
  String get requestRemoval => _ui(FanWorkStrings.requestRemoval, 'طلب إزالة');
  String get revised => _ui(FanWorkStrings.revised, 'تم حفظ المراجعة');
  String get revisions => _ui(FanWorkStrings.revisions, 'سجل المراجعات');
  String get noRevisions => _ui(FanWorkStrings.noRevisions, 'لا مراجعات بعد');
  String get version => _ui(FanWorkStrings.version, 'النسخة');
  String get revisionsCount => _ui(FanWorkStrings.revisionsCount, 'مراجعة');

  String get shareInApp => _s.shareInApp;
  String get shareOutside => _s.shareOutside;
  String get shareToGroup => _ui('Send to a group', 'إرسال إلى مجموعة');
  String get shareToChat => _ui('Send to a chat', 'إرسال إلى محادثة');
  String get sharePickGroup => _ui('Choose a group', 'اختر مجموعة');
  String get sharePickChat => _ui('Choose a chat', 'اختر محادثة');
  String get shareNoTargets => _ui(
    'You have no groups or chats to share to yet.',
    'لا توجد مجموعات أو محادثات لمشاركة العمل إليها بعد.',
  );
  String get shareSent => _ui('Shared', 'تمت المشاركة');
  String get sentToGroup => _ui('Sent to the group', 'أُرسل إلى المجموعة');
  String get sentToChat => _ui('Sent to the chat', 'أُرسل إلى المحادثة');

  String get myDrafts => _ui('My drafts', 'مسوداتي');
  String get myWorks => _ui('My works', 'أعمالي');
  String get analytics => _ui('Statistics', 'إحصاءات');
  String readMinutes(int minutes) => _s.readMinutes(minutes);
  String get editWork => _ui('Edit', 'تعديل');
  String get confirmPublish => _ui('Publish this work?', 'نشر هذا العمل؟');
  String get confirmPublishHint => _ui(
    'Once published it appears in discovery and other readers can interact.',
    'بعد النشر سيظهر في الاكتشاف ويستطيع الآخرون التفاعل معه.',
  );
  String get discardDraftHint => _ui(
    'This draft will be deleted permanently.',
    'ستُحذف هذه المسودة نهائياً.',
  );
  String get workSavedLocally => _ui(
    'Your draft is saved on this device until it is published.',
    'مسودتك محفوظة على هذا الجهاز حتى نشرها.',
  );
  String get typeStep => _ui('Type', 'النوع');
  String get detailsStep => _ui('Details', 'التفاصيل');
  String get contentStep => _ui('Content', 'المحتوى');
  String get previewStep => _ui('Preview', 'المعاينة');
  String get next => _ui('Next', 'التالي');
  String get back => _ui('Back', 'رجوع');
  String get finish => _ui('Finish', 'إنهاء');
  String get invalidPdf => _ui(
    'That file is not a readable PDF.',
    'هذا الملف ليس PDF قابلاً للقراءة.',
  );
  String get emptyPdf => _ui('That PDF has no pages.', 'هذا الملف بلا صفحات.');
  String get protectedPdf => _ui(
    'Password-protected PDFs are not supported. Remove the password and retry.',
    'ملفات PDF المحمية بكلمة مرور غير مدعومة. أزل كلمة المرور وأعد المحاولة.',
  );
  String get ratingLabel => _ui('Your rating', 'تقييمك');
  String get rateThisWork => _ui('Rate this work', 'قيّم هذا العمل');
  String get clearRating => _ui('Remove rating', 'إزالة التقييم');
  String get fromCreator => _ui('Published by', 'نشره');
  String get unknownCreator => _ui('Unknown creator', 'ناشر غير معروف');
  String get noDescription =>
      _ui('The creator did not add a description.', 'لم يضف الناشر وصفاً.');
  String get noCreatorNote =>
      _ui('The creator did not add a note.', 'لم يضف الناشر نبذة.');
  String get anonymousName => _ui('Reader', 'قارئ');
  String get worksInThis => _ui('More in this series', 'المزيد من هذه الأعمال');
  String get nothingPublished =>
      _ui('Nothing published yet.', 'لم يُنشر شيء بعد.');

  String get works => _ui('Works', 'الأعمال');
  String get couldNotLoadFanWorks =>
      _s.pick('Fan Works could not be loaded.', 'تعذّر تحميل أعمال المعجبين.');
  String get noFanWorksOwner => _s.pick(
    'You have not published a Fan Work yet.',
    'لم تنشر أي عمل خاص بعد.',
  );
  String get noFanWorksVisitor => _s.pick(
    'This creator has no Fan Works yet.',
    'لا توجد أعمال لهذا الناشر بعد.',
  );
  String get shareAWorkHint => _s.pick(
    'Publish a manga, story, drawing, or character and it will appear here.',
    'انشر مانغا أو قصة أو رسمة أو شخصية وستظهر هنا.',
  );
  String get creatorNoWorksHint =>
      _s.pick('Nothing to show here yet.', 'لا يوجد ما يُعرض هنا بعد.');
  String get analyticsOwnOnly => _s.pick(
    'Only the creator can see these statistics.',
    'الإحصاءات تظهر للناشر فقط.',
  );
  String get totalWorks => _ui('Works', 'إجمالي الأعمال');
  String get publishedLabel => _ui('Published', 'منشور');
  String get draftsLabel => _ui('Drafts', 'مسودات');
  String get totalLikes => _ui('Likes', 'الإعجابات');
  String get totalSaves => _ui('Saves', 'الحفظ');
  String get totalComments => _ui('Comments', 'التعليقات');
  String get avgRating => _ui('Avg. rating', 'متوسط التقييم');
  String get totalRatings => _ui('Ratings', 'التقييمات');
  String get worksByType => _ui('Works by type', 'الأعمال حسب النوع');
  String get topWorks => _ui('Most appreciated', 'الأكثر تقديراً');

  String get untitled => _ui('Untitled', 'بلا عنوان');
  String get homeStripEmpty =>
      _ui('No Fan Works to show yet.', 'لا توجد أعمال المعجبين لعرضها بعد.');
  String titleHint(FanWorkType type) => switch (type) {
    FanWorkType.character => _ui('Name this character', 'اكتب اسم هذه الشخصية'),
    FanWorkType.manga => _ui('Title of the manga', 'عنوان المانغا'),
    FanWorkType.story => _ui('Title of the story', 'عنوان القصة'),
    _ => _ui('Title of this work', 'عنوان هذا العمل'),
  };
  String descriptionHint(FanWorkType type) => switch (type) {
    FanWorkType.character => _ui(
      'Tell readers this character story in at least 40 characters.',
      'اكتب قصة الشخصية في 40 حرفاً على الأقل.',
    ),
    _ => _ui('What should readers know?', 'ما الذي يجب أن يعرفه القارئ؟'),
  };
  String get tagsLabel => _ui('Tags', 'الوسوم');
  String get tagsHint =>
      _ui('Separate tags with commas', 'افصل بين الوسوم بفواصل');
  String get tagsHelper => _ui(
    'Up to 8 tags, 2 to 24 characters each.',
    'حتى 8 وسوم، كل وسم من 2 إلى 24 حرفاً.',
  );
  String get relatedAnimeId => _ui('Related anime ID', 'معرّف الأنمي المرتبط');
  String get relatedAnimeTitle =>
      _ui('Related anime title', 'عنوان الأنمي المرتبط');
  String get optionalAnimeIdentifier => _ui('Optional', 'اختياري');
  String get optionalDisplayTitle =>
      _ui('Shown to readers, optional', 'يظهر للقارئ، اختياري');
  String get aiAssistedNotice => _ui(
    'Readers are told this character was AI-assisted.',
    'يُعلَم القرّاء أن هذه الشخصية بمساعدة الذكاء.',
  );
  String get replaceFile => _ui('Replace', 'استبدال');
  String get removeFile => _ui('Remove', 'إزالة');
  String get fileTooLarge =>
      _ui('That file is too large.', 'حجم الملف كبير جداً.');
  String get moveUp => _ui('Move up', 'تحريك لأعلى');
  String get moveDown => _ui('Move down', 'تحريك لأسفل');
  String get chooseCategoryFirst =>
      _ui('Choose a category first.', 'اختر التصنيف أولاً.');
  String get categoryHint => _ui(
    'Categories come from a fixed list so search works.',
    'التصنيفات من قائمة ثابتة ليعمل البحث.',
  );
  String get documentSlotTitle => _ui('Reading file', 'ملف القراءة');
  String get artworkSlotTitle => _ui('Artwork', 'الرسمة');
  String get portraitSlotTitle => _ui('Character image', 'صورة الشخصية');

  String typeLabel(FanWorkType type) => switch (type) {
    FanWorkType.manga => _ui('Manga', 'مانغا'),
    FanWorkType.story => _ui('Story', 'قصة'),
    FanWorkType.drawing => _ui('Drawing', 'رسمة'),
    FanWorkType.character => _ui('Character', 'شخصية'),
    FanWorkType.worldbuilding => _ui('Worldbuilding', 'بناء عالم'),
    FanWorkType.other => _ui('Other', 'أخرى'),
  };

  String categoryLabel(FanWorkType type, String id) {
    final category = FanWorkCategories.byId(type, id);
    if (category == null) return '';
    return category.label(arabic: _s.isArabic);
  }

  String originLabel(FanWorkOrigin origin) => switch (origin) {
    FanWorkOrigin.handmade => originHandmade,
    FanWorkOrigin.aiGenerated => originAi,
  };

  /// The field name a creator sees for "title" on a given type. A character
  /// work is named after the character, not after a piece of prose.
  String titleLabel(FanWorkType type) => switch (type) {
    FanWorkType.character => characterName,
    _ => _ui('Title', 'العنوان'),
  };

  String descriptionLabel(FanWorkType type) => switch (type) {
    FanWorkType.character => characterStory,
    _ => _ui('Description', 'الوصف'),
  };

  String creatorNoteLabel(FanWorkType type) => switch (type) {
    FanWorkType.manga ||
    FanWorkType.story => _ui('Note from the author', 'نبذة عن الكاتب'),
    FanWorkType.drawing => _ui('Note from the artist', 'نبذة عن الرسام'),
    FanWorkType.character => _ui(
      'Note from the creator',
      'نبذة عن صانع الشخصية',
    ),
    _ => creatorNote,
  };

  String documentLabel(FanWorkType type) =>
      type == FanWorkType.story ? storyPdf : mangaPdf;
  String documentHint(FanWorkType type) =>
      type == FanWorkType.story ? storyPdfHint : mangaPdfHint;

  String reportReason(FanWorkReportReason reason) =>
      _s.reportReasonLabel(reason.name);

  String publishedOn(DateTime publishedAt) {
    final date = publishedAt.toLocal().toIso8601String().split('T').first;
    return _s.pick('Published $date', 'نُشر في $date');
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

  String likes(int count) => _s.pick(
    count == 1 ? '1 like' : '$count likes',
    count == 1 ? 'إعجاب واحد' : '$count إعجاب',
  );

  String commentsCount(int count) => _s.pick(
    count == 1 ? '1 comment' : '$count comments',
    count == 1 ? 'تعليق واحد' : '$count تعليق',
  );

  String saves(int count) => _s.pick(
    count == 1 ? '1 save' : '$count saves',
    count == 1 ? 'حفظ واحد' : '$count حفظ',
  );

  String ratings(int count) => _s.pick(
    count == 1 ? '1 rating' : '$count ratings',
    count == 1 ? 'تقييم واحد' : '$count تقييم',
  );

  String pageOf(int total, int n) =>
      _s.pick('Page $n of $total', 'الصفحة $n من $total');

  String pageNumber(int n) => _s.pick('Page $n', 'الصفحة $n');

  String pagesCount(int n) => _s.pick(
    n == 1 ? '1 page' : '$n pages',
    n == 1 ? 'صفحة واحدة' : '$n صفحة',
  );

  String sizeMb(int bytes) {
    final mb = (bytes / (1024 * 1024)).ceil();
    return _s.pick('$mb MB', '$mb ميغابايت');
  }

  String progress(int percent) =>
      _s.pick('$percent% uploaded', 'تم رفع $percent٪');

  String percentRead(int percent) =>
      _s.pick('$percent% read', 'قرأت $percent٪');

  String draftStillOnDevice(String error) => _s.pick(
    '$error Your draft is still on this device.',
    '$error المسودة ما زالت على هذا الجهاز.',
  );

  /// Server messages are authored in English and echoed verbatim; this maps
  /// them to Arabic by lookup so a rejection never leaks an English string.
  String lifecycleError(String? message) {
    if (message == null || message.isEmpty) return '';
    return switch (message) {
      'A title between 3 and 80 characters is required.' => _s.pick(
        message,
        'العنوان المطلوب بين 3 و80 حرفاً.',
      ),
      'Choose a category.' => _s.pick(message, 'اختر التصنيف.'),
      'Choose a valid category.' => _s.pick(message, 'اختر تصنيفاً صحيحاً.'),
      'Attach the manga PDF.' => _s.pick(
        message,
        'أرفق ملف المانغا بصيغة PDF.',
      ),
      'Attach the story PDF.' => _s.pick(message, 'أرفق ملف القصة بصيغة PDF.'),
      'Attach the drawing.' => _s.pick(message, 'أرفق الرسمة.'),
      'Attach the character portrait.' => _s.pick(
        message,
        'أرفق صورة الشخصية.',
      ),
      'Tell the character story in at least 40 characters.' => _s.pick(
        message,
        'اكتب قصة الشخصية في 40 حرفاً على الأقل.',
      ),
      'Too many characters.' => _s.pick(message, 'عدد الشخصيات كبير جداً.'),
      'The creator note is too long.' => _s.pick(
        message,
        'نبذة الكاتب طويلة جداً.',
      ),
      'That file does not belong here.' => _s.pick(
        message,
        'هذا الملف غير مناسب هنا.',
      ),
      'Only PDF files are accepted.' => _s.pick(
        message,
        'يُقبل ملفات PDF فقط.',
      ),
      'PDF files must be 50 MB or smaller.' => _s.pick(
        message,
        'يجب ألا يتجاوز حجم ملف PDF 50 ميغابايت.',
      ),
      'Use a JPEG, PNG, WEBP, or GIF image.' => _s.pick(
        message,
        'استخدم صورة JPEG أو PNG أو WEBP أو GIF.',
      ),
      'Images must be 12 MB or smaller.' => _s.pick(
        message,
        'يجب ألا يتجاوز حجم الصور 12 ميغابايت.',
      ),
      'That image is empty.' => _s.pick(message, 'الصورة فارغة.'),
      'That PDF is empty.' => _s.pick(message, 'ملف PDF فارغ.'),
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
      'Media can only be added to drafts.' => _s.pick(
        message,
        'لا يمكن إضافة وسائط إلا إلى المسودات.',
      ),
      'Only drafts can be edited.' => _s.pick(
        message,
        'لا يمكن تعديل سوى المسودات.',
      ),
      'Only drafts can be published.' => _s.pick(
        message,
        'لا يمكن نشر سوى المسودات.',
      ),
      'You already published a work today.' => _s.pick(
        message,
        'لقد نشرت عملاً اليوم بالفعل.',
      ),
      'You reached the daily limit for new works.' => _s.pick(
        message,
        'بلغت الحد اليومي للأعمال الجديدة.',
      ),
      'This file is still uploading.' => _s.pick(
        message,
        'لا يزال رفع هذا الملف جارياً.',
      ),
      'The file is not readable yet.' => _s.pick(
        message,
        'الملف غير قابل للقراءة بعد.',
      ),
      'That file is too large.' => _s.pick(message, 'حجم الملف كبير جداً.'),
      _ => message,
    };
  }

  String _ui(String en, String ar) => _s.pick(en, ar);
}
