import 'package:flutter/widgets.dart';

import '../../../core/l10n/app_strings.dart';

final class EditCopy {
  const EditCopy(this._s);
  final AppStrings _s;

  static EditCopy of(BuildContext context) => EditCopy(AppStrings.of(context));

  String get feedTitle => _s.pick('Edits', 'المقاطع');
  String get uploadTitle => _s.pick('Upload Edit', 'رفع مقطع');
  String get chooseVideo => _s.pick('Choose video', 'اختيار فيديو');
  String get caption => _s.pick('Caption', 'الوصف');
  String get animeTag => _s.pick('Anime tag (optional)', 'وسم الأنمي (اختياري)');
  String get publish => _s.pick('Upload Edit', 'رفع المقطع');
  String get retry => _s.pick('Retry upload', 'إعادة محاولة الرفع');
  String get retryProcessing => _s.pick('Retry processing', 'إعادة المعالجة');
  String get deleteDraft => _s.pick('Delete draft', 'حذف المسودة');
  String get cancelUpload => _s.pick('Cancel upload', 'إلغاء الرفع');
  String get uploading => _s.pick('Uploading', 'جارٍ الرفع');
  String get paused => _s.pick('Paused — waiting for connection', 'متوقف مؤقتًا — بانتظار الاتصال');
  String get processing => _s.pick('Processing on the server', 'جارٍ المعالجة على الخادم');
  String get published => _s.pick('Published', 'تم النشر');
  String get noEdits => _s.pick('No Edits yet', 'لا مقاطع بعد');
  String get noEditsMessage => _s.pick(
    'Be the first creator to share a video.',
    'كن أول مبدع يشارك فيديو.',
  );
  String get failedLoad => _s.pick('Edits could not load.', 'تعذّر تحميل المقاطع.');
  String get like => _s.pick('Like', 'إعجاب');
  String get comment => _s.pick('Comment', 'تعليق');
  String get share => _s.pick('Share', 'مشاركة');
  String get save => _s.pick('Save', 'حفظ');
  String get respect => _s.pick('Respect', 'احترام');
  String get more => _s.pick('More', 'المزيد');
  String get repost => _s.pick('Repost', 'إعادة نشر');
  String get originalCreator => _s.pick('Original creator', 'المبدع الأصلي');
  String get comments => _s.pick('Comments', 'التعليقات');
  String get newest => _s.pick('Newest', 'الأحدث');
  String get top => _s.pick('Top', 'الأكثر إعجابًا');
  String get report => _s.pick('Report', 'إبلاغ');
  String get delete => _s.pick('Delete', 'حذف');
  String get mention => _s.pick('Mention', 'إشارة');
  String get sticker => _s.pick('Sticker', 'ملصق');
  String get openEdit => _s.pick('Open published Edit', 'فتح المقطع المنشور');
  String views(int count) => _s.pick('$count views', '$count مشاهدة');

  String compactCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return '$count';
  }
}
