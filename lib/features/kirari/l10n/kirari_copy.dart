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
  String get chooseAudio => _strings.pick('Choose audio', 'اختر صوتًا');
  String get resumeUpload => _strings.pick('Resume previous upload', 'استئناف الرفع السابق');
  String get comments => _strings.pick('Comments', 'التعليقات');
  String get addComment => _strings.pick('Add a comment…', 'أضف تعليقًا…');
  String get send => _strings.pick('Send', 'إرسال');
  String get muteCreator => _strings.pick('Mute creator', 'كتم المنشئ');
  String get unmuteCreator => _strings.pick('Unmute creator', 'إلغاء كتم المنشئ');
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
  String get giveRespect => _strings.pick('Give Respect', 'منح الاحترام');
  String get save => _strings.pick('Save', 'حفظ');
  String get notInterested => _strings.pick('Not interested', 'لست مهتمًا');
  String get undo => _strings.pick('Undo', 'تراجع');
  String get cancelUpload => _strings.pick('Cancel upload', 'إلغاء الرفع');
  String get uploadReceived => _strings.pick(
    'Kirari upload received.',
    'تم استلام فيديو كيراري.',
  );
}
