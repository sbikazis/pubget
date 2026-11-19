import 'package:flutter/widgets.dart';

import '../../../core/l10n/app_strings.dart';

final class KirariCopy {
  const KirariCopy(this._strings);
  final AppStrings _strings;

  static KirariCopy of(BuildContext context) =>
      KirariCopy(AppStrings.of(context));

  String get title => _strings.pick('Kirari', 'كيراري');
  String get forYou => _strings.pick('For You', 'لك');
  String get following => _strings.pick('Following', 'تتابعهم');
  String get trending => _strings.pick('Trending', 'الرائج');
  String get create => _strings.pick('Create video', 'إنشاء فيديو');
  String get chooseVideo => _strings.pick(
    'Choose a video from your gallery',
    'اختر فيديو من معرض الصور',
  );
  String get videoLimits => _strings.pick(
    'Vertical video · 3–60 seconds · up to 500 MB',
    'فيديو عمودي · من 3 إلى 60 ثانية · حتى 500 ميغابايت',
  );
  String get videoFormat => _strings.pick(
    'Only MP4 videos are supported.',
    'يدعم النظام فيديوهات MP4 فقط.',
  );
  String get caption => _strings.pick('Caption', 'الوصف');
  String get hashtags => _strings.pick('Hashtags', 'الوسوم');
  String get trim => _strings.pick('Trim video', 'قص الفيديو');
  String get speed => _strings.pick('Playback speed', 'سرعة الفيديو');
  String get filter => _strings.pick('Color filter', 'فلتر الألوان');
  String get overlayText => _strings.pick('Text overlay', 'نص على الفيديو');
  String get coverFrame => _strings.pick('Cover frame', 'إطار الغلاف');
  String get audioLibrary => _strings.pick('Audio library', 'مكتبة الصوت');
  String get originalAudio => _strings.pick('Use original audio', 'استخدم الصوت الأصلي');
  String get originalVolume => _strings.pick('Original audio volume', 'مستوى صوت الفيديو الأصلي');
  String get addedVolume => _strings.pick('Added audio volume', 'مستوى صوت الموسيقى المضافة');
  String get textStart => _strings.pick('Text timing · start', 'بداية ظهور النص');
  String get textEnd => _strings.pick('Text timing · end', 'نهاية ظهور النص');
  String get chooseCover => _strings.pick('Choose cover image', 'اختر صورة الغلاف');
  String get frameCover => _strings.pick('Use a frame from the video', 'استخدم إطارًا من الفيديو');
  String get customCoverSelected => _strings.pick('Custom 9:16 cover selected', 'تم اختيار غلاف مخصص بنسبة 9:16');
  String get adjustCover => _strings.pick('Adjust reel cover', 'ضبط غلاف الريل');
  String get coverError => _strings.pick('Unable to prepare this cover image.', 'تعذّر تجهيز صورة الغلاف.');
  String get searchAnime => _strings.pick('Search anime', 'ابحث عن أنمي');
  String get searchCharacters => _strings.pick('Search characters', 'ابحث عن الشخصيات');
  String get searchPeople => _strings.pick('Search people', 'ابحث عن الأشخاص');
  String get mentions => _strings.pick('Mentions', 'الإشارات');
  String get noMentionsSelected => _strings.pick('No people mentioned', 'لم تتم الإشارة إلى أشخاص');
  String get addMention => _strings.pick('Mention a person', 'أشر إلى شخص');
  String get contentCategory => _strings.pick('Content category', 'تصنيف المحتوى');
  String get animeTags => _strings.pick('Anime tags', 'الأنميات المرتبطة');
  String get characterTags => _strings.pick('Character tags', 'الشخصيات المرتبطة');
  String get noAnimeSelected => _strings.pick('No anime selected', 'لم يتم اختيار أنمي');
  String get noCharactersSelected => _strings.pick('No characters selected', 'لم يتم اختيار شخصيات');
  String get addAnime => _strings.pick('Add anime', 'أضف أنمي');
  String get addCharacter => _strings.pick('Add character', 'أضف شخصية');
  String get categoryAnimeEdit => _strings.pick('Anime edit', 'تعديل أنمي');
  String get categoryAmv => _strings.pick('AMV', 'فيديو موسيقي أنمي');
  String get categoryCosplay => _strings.pick('Cosplay', 'كوسبلاي');
  String get categoryMeme => _strings.pick('Meme', 'ميم');
  String get categoryReview => _strings.pick('Review', 'مراجعة');
  String get categoryTheory => _strings.pick('Theory', 'نظرية');
  String get categoryRecommendation => _strings.pick('Recommendation', 'ترشيح');
  String get categoryFanArt => _strings.pick('Fan art', 'فن المعجبين');
  String get categoryOther => _strings.pick('Other', 'أخرى');
  String categoryLabel(String value) => switch (value) {
    'anime_edit' => categoryAnimeEdit,
    'amv' => categoryAmv,
    'cosplay' => categoryCosplay,
    'meme' => categoryMeme,
    'review' => categoryReview,
    'theory' => categoryTheory,
    'recommendation' => categoryRecommendation,
    'fan_art' => categoryFanArt,
    _ => categoryOther,
  };
  String get allowAudioReuse => _strings.pick('Allow others to reuse my original audio', 'السماح للآخرين بإعادة استخدام صوتي الأصلي');
  String get audioReuseRights => _strings.pick('Only enable this if you own the audio or have permission to share it. New tracks remain private until approved.', 'فعّل هذا الخيار فقط إذا كنت تملك حقوق الصوت أو تملك إذنًا بمشاركته. ستظل المقاطع الصوتية خاصة حتى مراجعتها والموافقة عليها.');
  String get chooseAudio => _strings.pick('Choose audio', 'اختر صوتًا');
  String get resumeUpload => _strings.pick('Resume previous upload', 'استئناف الرفع السابق');
  String get comments => _strings.pick('Comments', 'التعليقات');
  String get addComment => _strings.pick('Add a comment…', 'أضف تعليقًا…');
  String get send => _strings.pick('Send', 'إرسال');
  String get muteCreator => _strings.pick('Mute creator', 'كتم المنشئ');
  String get report => _strings.pick('Report', 'إبلاغ');
  String get retry => _strings.pick('Retry', 'إعادة المحاولة');
  String get publish => _strings.pick('Publish video', 'نشر الفيديو');
  String get uploading => _strings.pick('Uploading…', 'جارٍ الرفع…');
  String get processing => _strings.pick(
    'Processing video and creating quality versions…',
    'جارٍ تجهيز الفيديو وإنشاء نسخ بجودات مختلفة…',
  );
  String get received => _strings.pick(
    'Upload received. Processing continues in the background.',
    'تم استلام الفيديو. تستمر المعالجة في الخلفية.',
  );
  String get noVideos => _strings.pick(
    'No videos yet. Be the first to create one.',
    'لا توجد فيديوهات بعد. كن أول من ينشر فيديو.',
  );
  String get loadError => _strings.pick(
    'Could not load Kirari. Check your connection and retry.',
    'تعذّر تحميل كيراري. تحقق من الاتصال وحاول مجددًا.',
  );
  String get reelUnavailable => _strings.pick(
    'This Reel is not available',
    'هذا الريل غير متاح',
  );
  String get actionError => _strings.pick('Could not save that action. Please retry.', 'تعذّر حفظ هذا الإجراء. حاول مجددًا.');
  String get uploadError => _strings.pick(
    'Upload failed. Check your connection and retry.',
    'فشل رفع الفيديو. تحقق من الاتصال وحاول مجددًا.',
  );
  String get playbackError => _strings.pick(
    'This video could not be played. Swipe to continue.',
    'تعذّر تشغيل هذا الفيديو. مرّر للمتابعة.',
  );
  String get like => _strings.pick('Like', 'إعجاب');
  String get save => _strings.pick('Save', 'حفظ');
  String get notInterested => _strings.pick('Not interested', 'لست مهتمًا');
  String get cancelUpload => _strings.pick('Cancel upload and edit', 'إلغاء الرفع والتعديل');
  String get uploadCanceled => _strings.pick('Upload canceled. Your local draft is ready to edit.', 'تم إلغاء الرفع. مسودتك المحلية جاهزة للتعديل.');
  String get uploadReceived => _strings.pick(
    'Kirari upload received.',
    'تم استلام فيديو كيراري.',
  );
  String get analyticsTitle => _strings.pick('Creator analytics', 'تحليلات الصانع');
  String get analyticsRefresh => _strings.pick('Refresh analytics', 'تحديث التحليلات');
  String get analyticsNoData => _strings.pick('No published videos yet. Analytics appear after your first reel is live.', 'لا توجد فيديوهات منشورة بعد. ستظهر التحليلات بعد نشر أول ريل.');
  String get analyticsLoadError => _strings.pick('Could not load analytics. Check your connection and retry.', 'تعذّر تحميل التحليلات. تحقق من الاتصال وحاول مجددًا.');
  String get analyticsOverview => _strings.pick('Overview', 'نظرة عامة');
  String get analyticsImpressions => _strings.pick('Impressions', 'الظهور');
  String get analyticsViews => _strings.pick('Views', 'المشاهدات');
  String get analyticsQualifiedViews => _strings.pick('Qualified views', 'مشاهدات مؤهلة');
  String get analyticsWatchTime => _strings.pick('Watch time', 'وقت المشاهدة');
  String get analyticsAverageWatch => _strings.pick('Average watch', 'متوسط المشاهدة');
  String get analyticsCompletionRate => _strings.pick('Completion rate', 'نسبة الإكمال');
  String get analyticsReplayRate => _strings.pick('Replay rate', 'نسبة الإعادة');
  String get analyticsEngagementRate => _strings.pick('Engagement rate', 'معدل التفاعل');
  String get analyticsEarlySkips => _strings.pick('Early skips', 'تخطٍ مبكر');
  String get analyticsLikes => _strings.pick('Likes', 'الإعجابات');
  String get analyticsComments => _strings.pick('Comments', 'التعليقات');
  String get analyticsSaves => _strings.pick('Saves', 'الحفظ');
  String get analyticsShares => _strings.pick('Shares', 'المشاركات');
  String get analyticsReels => _strings.pick('Reels', 'الريلز');
  String get analyticsTopReels => _strings.pick('Top reels', 'أفضل الريلز');
  String get analyticsTrending => _strings.pick('Trending reels', 'الريلز الرائجة');
  String get analyticsTopHashtags => _strings.pick('Top hashtags', 'أفضل الوسوم');
  String get analyticsTopAnime => _strings.pick('Top anime', 'أفضل الأنميات');
  String get analyticsTopCharacters => _strings.pick('Top characters', 'أفضل الشخصيات');
  String get analyticsTopAudio => _strings.pick('Top audio', 'أفضل الصوتيات');
  String get analyticsScope => _strings.pick('Based on the latest published reels', 'بناءً على آخر الريلز المنشورة');
  String get analyticsScopeTruncated => _strings.pick('Showing the most recent reels only', 'عرض الريلز الأحدث فقط');
  String get analyticsNotTracked => _strings.pick('Not tracked yet: unique viewers, replies, new fans, respect, profile visits, traffic sources and retention.', 'غير متاحة بعد: المشاهدون الفريدون، الردود، المعجبون الجدد، الاحترام، زيارات الملف، مصادر الزيارة ومنحنى الاحتفاظ.');
  String get pinnedComment => _strings.pick('Pinned', 'مثبّت');
  String get pinComment => _strings.pick('Pin comment', 'تثبيت التعليق');
  String get unpinComment => _strings.pick('Unpin comment', 'إلغاء تثبيت التعليق');
}
