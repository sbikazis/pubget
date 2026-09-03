import 'fan_work_models.dart';

abstract final class FanWorkLifecycle {
  static const titleMin = 3;
  static const titleMax = 80;
  static const descriptionMax = 2000;
  static const maxTags = 8;
  static const tagMin = 2;
  static const tagMax = 24;
  static const maxPages = 40;
  static const maxImages = 8;
  static const maxChapters = 20;
  static const storyBodyMax = 20000;
  static const minStoryChars = 20;
  static const maxMediaBytes = 10 * 1024 * 1024;
  static const allowedMimeTypes = <String>{
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
  };

  static bool canEdit(FanWorkStatus status) => status == FanWorkStatus.draft;
  static bool canDelete(FanWorkStatus status) => status == FanWorkStatus.draft;
  static bool canPublish(FanWorkStatus status) => status == FanWorkStatus.draft;
  static bool canArchive(FanWorkStatus status) =>
      status == FanWorkStatus.published;

  static bool isPubliclyListed(FanWork work) => work.isPubliclyListed;

  static List<String> normalizeTags(Iterable<String> raw) {
    final seen = <String>{};
    final tags = <String>[];
    for (final item in raw) {
      final tag = item
          .trim()
          .replaceFirst(RegExp(r'^#+'), '')
          .toLowerCase()
          .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '');
      if (tag.length < tagMin || tag.length > tagMax) continue;
      if (!seen.add(tag)) continue;
      tags.add(tag);
      if (tags.length >= maxTags) break;
    }
    return tags;
  }

  static String? publishError(FanWork work) {
    final title = work.title.trim();
    if (title.length < titleMin || title.length > titleMax) {
      return 'A title between 3 and 80 characters is required.';
    }
    switch (work.type) {
      case FanWorkType.manga:
        if (work.content.orderedPages.isEmpty) {
          return 'Manga needs at least one page.';
        }
      case FanWorkType.drawing:
        if (work.content.images.isEmpty && (work.cover?.path.isEmpty ?? true)) {
          return 'A drawing needs at least one image.';
        }
      case FanWorkType.story:
        final body = work.content.body.trim();
        final hasChapter = work.content.orderedChapters.any(
          (chapter) => chapter.body.trim().length >= minStoryChars,
        );
        if (body.length < minStoryChars && !hasChapter) {
          return 'A story needs written content.';
        }
      case FanWorkType.character:
      case FanWorkType.aiCharacter:
        if (work.content.name.trim().length < 2) {
          return 'A character name is required.';
        }
        if (work.description.trim().length < 10 &&
            work.content.background.trim().length < 10) {
          return 'A character needs a description or background.';
        }
      case FanWorkType.worldbuilding:
        if (work.content.lore.trim().length < minStoryChars &&
            work.description.trim().length < minStoryChars) {
          return 'Worldbuilding needs lore or a description.';
        }
      case FanWorkType.other:
        final hasMedia =
            work.content.images.isNotEmpty ||
            (work.cover?.path.isNotEmpty ?? false);
        if (work.description.trim().length < minStoryChars &&
            work.content.body.trim().length < minStoryChars &&
            !hasMedia) {
          return 'This work needs a description, written content, or media.';
        }
    }
    return null;
  }

  static String? mediaError({required String contentType, required int size}) {
    if (!allowedMimeTypes.contains(contentType.toLowerCase())) {
      return 'Use a JPEG, PNG, WEBP, or GIF image.';
    }
    if (size <= 0 || size > maxMediaBytes) {
      return 'Images must be 10 MB or smaller.';
    }
    return null;
  }
}

abstract final class FanWorkTypeCatalog {
  static const labels = <FanWorkType, String>{
    FanWorkType.manga: 'Manga',
    FanWorkType.drawing: 'Drawing',
    FanWorkType.story: 'Story',
    FanWorkType.character: 'Character',
    FanWorkType.aiCharacter: 'AI-assisted character',
    FanWorkType.worldbuilding: 'Worldbuilding',
    FanWorkType.other: 'Other',
  };

  static String label(FanWorkType type) => labels[type] ?? type.name;
}

abstract final class FanWorkStrings {
  static const feedTitle = 'Fan Works';
  static const seeAll = 'See all Fan Works';
  static const create = 'Create Fan Work';
  static const saveDraft = 'Save draft';
  static const publish = 'Publish';
  static const preview = 'Preview';
  static const archive = 'Archive';
  static const deleteDraft = 'Delete draft';
  static const share = 'Share Fan Work';
  static const copyLink = 'Copy link';
  static const copied = 'Fan Work link copied';
  static const report = 'Report';
  static const like = 'Like';
  static const bookmark = 'Save';
  static const missing = 'This Fan Work is unavailable.';
  static const emptyTitle = 'No Fan Works yet';
  static const emptyMessage = 'Be the first to publish a drawing, story, or manga.';
  static const draftsEmpty = 'No drafts yet';
  static const offlineCached = 'Showing cached Fan Works. You are offline.';
  static const offline = 'You are offline. Connect and try again.';
  static const aiAssisted = 'AI-assisted';
  static const draftSaved = 'Draft saved';
  static const published = 'Fan Work published';
  static const publishFailed = 'Publishing failed. Your draft was kept.';
  static const uploadFailed = 'Upload failed. Your draft was kept.';
  static const chooseType = 'Choose a type';
  static const basicInfo = 'Basic information';
  static const mediaContent = 'Media and content';
  static const tagsAnime = 'Tags and anime';
  static const copyright = 'Copyright and source';
  static const requestRemoval = 'Request removal';
  static const revised = 'Revision saved';
}
