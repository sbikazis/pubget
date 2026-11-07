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
  String get cancelUpload => _strings.pick('Cancel upload', 'إلغاء الرفع');
  String get uploadReceived => _strings.pick(
    'Kirari upload received.',
    'تم استلام فيديو كيراري.',
  );
}
