import 'package:flutter/widgets.dart';

import '../../../core/errors/failure.dart';
import '../../../core/l10n/app_strings.dart';
import '../models/edit_models.dart';

final class EditCopy {
  const EditCopy(this._s);
  final AppStrings _s;

  static EditCopy of(BuildContext context) => EditCopy(AppStrings.of(context));

  String get feedTitle => _s.pick('Reels', 'ريلز');
  String get uploadTitle => _s.pick('Create Reel', 'إنشاء ريل');
  String get chooseVideo => _s.pick('Choose video', 'اختيار فيديو');
  String get recordVideo => _s.pick('Camera', 'الكاميرا');
  String get recordVideoHint => _s.pick('Record video', 'تسجيل فيديو');
  String get replaceVideo => _s.pick('Replace video', 'استبدال الفيديو');
  String get caption => _s.pick('Caption', 'الوصف');
  String get captionHint =>
      _s.pick('Write a caption…', 'اكتب وصفًا…');
  String get animeTag => _s.pick('Anime tag (optional)', 'وسم الأنمي (اختياري)');
  String get animeTagHint =>
      _s.pick('e.g. one_piece', 'مثال: one_piece');
  String get publish => _s.pick('Publish Reel', 'نشر الريل');
  String get continueUpload => _s.pick('Continue', 'متابعة');
  String get retry => _s.pick('Retry upload', 'إعادة محاولة الرفع');
  String get retryProcessing => _s.pick('Retry processing', 'إعادة المعالجة');
  String get saveDraft => _s.pick('Save draft', 'حفظ المسودة');
  String get deleteDraft => _s.pick('Delete draft', 'حذف المسودة');
  String get cancelUpload => _s.pick('Cancel upload', 'إلغاء الرفع');
  String get uploading => _s.pick('Uploading', 'جارٍ الرفع');
  String get queued => _s.pick('Queued', 'في الانتظار');
  String get dismiss => _s.pick('Dismiss', 'إخفاء');
  String get paused =>
      _s.pick('Paused — waiting for connection', 'متوقف مؤقتًا — بانتظار الاتصال');
  String get processing =>
      _s.pick('Processing on the server', 'جارٍ المعالجة على الخادم');
  String get published => _s.pick('Published', 'تم النشر');
  String get needsReview => _s.pick(
    'Held for review',
    'قيد المراجعة الإشرافية',
  );
  String get publishedMessage => _s.pick(
    'Your Reel is live. Open it in the feed.',
    'الريل متاح الآن. افتحه من الريلز.',
  );
  String get publishingInBackground => _s.pick(
    'Publishing in the background…',
    'جارٍ النشر في الخلفية…',
  );
  String queueCount(int count) =>
      _s.pick('$count uploads', '$count رفع');
  String get draftStatus => _s.pick('Draft', 'مسودة');
  String get readyStatus => _s.pick('Ready to publish', 'جاهز للنشر');
  String get failedStatus => _s.pick('Needs attention', 'يحتاج إجراءً');
  String get publishedNotificationTitle =>
      _s.pick('Reel published', 'تم نشر الريل');
  String get publishedNotificationBody => _s.pick(
    'Your Reel is live. Open Reels to watch it.',
    'الريل متاح الآن. افتح الريلز لمشاهدته.',
  );
  String get failedNotificationBody => _s.pick(
    'Reel processing failed. Open the app to retry or delete the draft.',
    'فشلت معالجة المقطع. افتح التطبيق لإعادة المحاولة أو حذف المسودة.',
  );
  String get videoReadyOffer => _s.pick(
    'Your Reel is ready — watch it now?',
    'مقطعك جاهز — شاهده الآن؟',
  );
  String get watchNow => _s.pick('Watch now', 'شاهده الآن');
  String get openEdit =>
      _s.pick('Open published Reel', 'فتح الريل المنشور');
  String get noVideoYet => _s.pick(
    'Add an MP4 to begin — any aspect ratio works',
    'أضف فيديو MP4 للبدء — أي نسبة عرض مدعومة',
  );
  String get previewUnavailable => _s.pick(
    'Preview unavailable — the local file is gone. Choose the video again.',
    'المعاينة غير متاحة — الملف المحلي غير موجود. اختر الفيديو مرة أخرى.',
  );
  String get syncing => _s.pick('Syncing with server…', 'مزامنة مع الخادم…');
  String get noEdits => _s.pick('No Reels yet', 'لا ريلز بعد');
  String get noEditsMessage => _s.pick(
    'Be the first creator to share a video.',
    'كن أول مبدع يشارك فيديو.',
  );
  String get failedLoad =>
      _s.pick('Reels could not load.', 'تعذّر تحميل الريلز.');
  String get brokenClip => _s.pick(
    'This clip could not be played.',
    'تعذّر تشغيل هذا المقطع.',
  );
  String get offlineClip => _s.pick(
    'Offline — retry when you are connected.',
    'بدون اتصال — أعد المحاولة عند توفر الإنترنت.',
  );
  String get retryClip => _s.pick('Retry', 'إعادة المحاولة');
  String get becameFan => _s.pick(
    'You are now a Fan of this creator!',
    'أصبحت الآن من معجبي هذا المبدع!',
  );
  String get fan => _s.pick('Fan', 'مشجع');
  String get like => _s.pick('Like', 'إعجاب');
  String get comment => _s.pick('Comment', 'تعليق');
  String get share => _s.pick('Share', 'مشاركة');
  String get save => _s.pick('Save', 'حفظ');
  String get respect => _s.pick('Respect', 'احترام');
  String get more => _s.pick('More', 'المزيد');
  String get repost => _s.pick('Repost', 'إعادة نشر');
  String get originalCreator =>
      _s.pick('Original creator', 'المبدع الأصلي');
  String get comments => _s.pick('Comments', 'التعليقات');
  String get newest => _s.pick('Newest', 'الأحدث');
  String get top => _s.pick('Top', 'الأكثر إعجابًا');
  String get report => _s.pick('Report', 'إبلاغ');
  String get delete => _s.pick('Delete', 'حذف');
  String get mention => _s.pick('Mention', 'إشارة');
  String get sticker => _s.pick('Sticker', 'ملصق');
  String get mute => _s.pick('Mute', 'كتم');
  String get unmute => _s.pick('Unmute', 'إلغاء الكتم');
  String get play => _s.pick('Play', 'تشغيل');
  String get pause => _s.pick('Pause', 'إيقاف');
  String views(int count) => _s.pick('$count views', '$count مشاهدة');

  String primaryActionLabel({
    required bool hasVideo,
    required String phase,
  }) {
    return switch (phase) {
      'uploading' => uploading,
      'processing' => processing,
      'published' => published,
      'failed' || 'paused' => retry,
      _ => hasVideo ? publish : chooseVideo,
    };
  }

  String failureFor(Edit edit) {
    if (edit.statusEnum == EditStatus.needsReview ||
        edit.moderationStatus == 'needs_review') {
      return edit.moderationReason ??
          _s.pick(
            'This Edit is held for review (possible third-party watermark).',
            'هذا المقطع قيد المراجعة (احتمال وجود علامة مائية لمنصة أخرى).',
          );
    }
    if (edit.moderationStatus == 'flagged' ||
        edit.statusEnum == EditStatus.rejected) {
      return edit.moderationReason ??
          _s.pick(
            'This Edit was flagged and was not published.',
            'تم وسم هذا المقطع ولم يُنشر.',
          );
    }
    return switch (edit.failureReason) {
      'invalid-video' => _s.pick(
          'This video is not a supported MP4, or it is too large.',
          'هذا الفيديو ليس MP4 مدعومًا، أو حجمه كبير جدًا.',
        ),
      'duration' => _s.pick(
          'Videos can be up to 3 minutes long.',
          'مدة الفيديو يمكن أن تصل إلى 3 دقائق.',
        ),
      'aspect-unrecoverable' => _s.pick(
          'We could not prepare this video for full-screen display. Delete the draft or try another file.',
          'تعذر تجهيز هذا الفيديو للعرض بملء الشاشة. احذف المسودة أو جرّب ملفًا آخر.',
        ),
      _ => _s.pick(
          'Processing failed. You can retry or replace the video.',
          'فشلت المعالجة. يمكنك إعادة المحاولة أو استبدال الفيديو.',
        ),
    };
  }

  String friendlyFailure(Failure failure) {
    if (failure is PermissionError) {
      final raw = failure.message.toLowerCase();
      if (raw.contains('sign in again') || raw.contains('unauthenticated')) {
        return _s.pick(
          'Could not upload this video securely. Sign in again, then retry.',
          'تعذر رفع الفيديو بشكل آمن. سجّل الدخول مجددًا ثم أعد المحاولة.',
        );
      }
      return _s.pick(
        'Upload was blocked by storage security. Stay signed in and retry in a moment.',
        'تم حظر الرفع بواسطة أمان التخزين. ابقَ مسجّل الدخول وأعد المحاولة بعد لحظات.',
      );
    }
    if (failure is NetworkError) {
      return _s.pick(
        'No connection — your draft is saved. Retry when you are online.',
        'لا يوجد اتصال — مسودتك محفوظة. أعد المحاولة عند توفر الإنترنت.',
      );
    }
    if (failure is CancelledError) {
      return _s.pick('Upload canceled.', 'تم إلغاء الرفع.');
    }
    final raw = failure.message.toLowerCase();
    if (raw.contains('not authorized') || raw.contains('permission')) {
      return _s.pick(
        'Could not prepare the video right now. Please retry.',
        'تعذر تجهيز الفيديو الآن. أعد المحاولة.',
      );
    }
    return failure.message;
  }

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
