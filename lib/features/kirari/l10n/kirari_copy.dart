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
  String get retry => _strings.pick('Retry', 'إعادة المحاولة');
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
