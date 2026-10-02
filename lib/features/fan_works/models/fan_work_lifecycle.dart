import 'fan_work_models.dart';
import 'fan_work_taxonomy.dart';

/// The single source of truth for what a Fan Work is allowed to contain.
///
/// Every limit here is mirrored, message for message, by
/// `functions/src/fanWorksDomain.js`. The client copy exists to fail fast and
/// to give an Arabic message; the server copy is the one that actually gates.
abstract final class FanWorkLifecycle {
  /// 3..80 is the pre-existing product rule (the master spec is silent on the
  /// minimum), kept identical in `functions/src/fanWorksDomain.js`.
  static const titleMin = 3;
  static const titleMax = 80;
  static const descriptionMax = 4000;
  static const creatorNoteMax = 1200;

  /// Character-only prose fields.
  static const maxPersonality = 1200;
  static const maxAbilities = 1200;
  static const maxSpecs = 1200;

  /// A brand new character must carry a real story, not a name.
  static const characterStoryMin = 40;

  /// Pre-rebuild `worldbuilding`/`other` rows were validated at 20 characters
  /// by the server. They are read-only now, but the floor still has to match
  /// `MIN_STORY_CHARS` in `functions/src/fanWorksDomain.js` so an old document
  /// that the server considers valid is not reported invalid on the client.
  static const legacyProseMin = 20;

  static const maxTags = 8;
  static const tagMin = 2;
  static const tagMax = 24;

  /// Cast list bounds for a manga or a story.
  static const maxCharacters = 24;
  static const characterNameMax = 60;
  static const characterBioMax = 600;

  static const maxImageBytes = 12 * 1024 * 1024;
  static const maxDocumentBytes = 50 * 1024 * 1024;

  static const allowedImageMimeTypes = <String>{
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
  };
  static const documentMimeType = 'application/pdf';

  /// The exact rejections the server returns, kept here so the editor and the
  /// server never disagree about wording.
  static const publishMissingTitle =
      'A title between 3 and 80 characters is required.';
  static const publishMissingCategory = 'Choose a category.';
  static const publishInvalidCategory = 'Choose a valid category.';
  static const publishMangaMissingPdf = 'Attach the manga PDF.';
  static const publishStoryMissingPdf = 'Attach the story PDF.';
  static const publishDrawingMissingImage = 'Attach the drawing.';
  static const publishCharacterMissingPortrait =
      'Attach the character portrait.';
  static const publishCharacterShortStory =
      'Tell the character story in at least 40 characters.';

  /// Anti-abuse (spec §2.4): a creator cannot flood the public feed.
  static const maxWorksPerDay = 10;
  static const maxCommentLength = 500;

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

  /// Which uploads a type accepts, and what the payload ceiling is.
  static Set<FanWorkMediaRole> rolesFor(FanWorkType type) => switch (type) {
    FanWorkType.manga || FanWorkType.story => const <FanWorkMediaRole>{
      FanWorkMediaRole.cover,
      FanWorkMediaRole.document,
      FanWorkMediaRole.characterPortrait,
    },
    FanWorkType.drawing => const <FanWorkMediaRole>{
      FanWorkMediaRole.cover,
      FanWorkMediaRole.artwork,
    },
    FanWorkType.character => const <FanWorkMediaRole>{
      FanWorkMediaRole.cover,
      FanWorkMediaRole.portrait,
    },
    FanWorkType.worldbuilding ||
    FanWorkType.other => const <FanWorkMediaRole>{FanWorkMediaRole.cover},
  };

  static bool acceptsRole(FanWorkType type, FanWorkMediaRole role) =>
      rolesFor(type).contains(role);

  /// Rejects an upload before a single byte leaves the device.
  static String? uploadError({
    required FanWorkType type,
    required FanWorkMediaRole role,
    required String contentType,
    required int sizeBytes,
  }) {
    final normalized = contentType.toLowerCase();
    if (!acceptsRole(type, role)) {
      return 'That file does not belong here.';
    }
    if (role == FanWorkMediaRole.document) {
      if (normalized != documentMimeType) return 'Only PDF files are accepted.';
      if (sizeBytes <= 0) return 'That PDF is empty.';
      if (sizeBytes > maxDocumentBytes) {
        return 'PDF files must be 50 MB or smaller.';
      }
      return null;
    }
    if (!allowedImageMimeTypes.contains(normalized)) {
      return 'Use a JPEG, PNG, WEBP, or GIF image.';
    }
    if (sizeBytes <= 0) return 'That image is empty.';
    if (sizeBytes > maxImageBytes) return 'Images must be 12 MB or smaller.';
    return null;
  }

  /// What is still missing before this work can go live. Returns `null` when
  /// it is publishable. The wording matches the server exactly.
  static String? publishError(FanWork work) {
    final title = work.title.trim();
    if (title.length < titleMin || title.length > titleMax) {
      return publishMissingTitle;
    }
    if (work.type.isCreatable &&
        FanWorkCategories.supportsCategory(work.type) &&
        work.categoryId.isEmpty) {
      return publishMissingCategory;
    }
    if (work.type.isCreatable &&
        FanWorkCategories.byId(work.type, work.categoryId) == null) {
      return publishInvalidCategory;
    }
    if (work.creatorNote.length > creatorNoteMax) {
      return 'The creator note is too long.';
    }
    final cast = work.content.orderedCharacters;
    if (cast.length > maxCharacters) return 'Too many characters.';

    switch (work.type) {
      case FanWorkType.manga:
        if (!work.content.hasDocument) return publishMangaMissingPdf;
      case FanWorkType.story:
        if (!work.content.hasDocument) return publishStoryMissingPdf;
      case FanWorkType.drawing:
        if (!work.content.hasArtwork && !work.content.hasPortrait) {
          return publishDrawingMissingImage;
        }
      case FanWorkType.character:
        if (work.description.trim().length < characterStoryMin) {
          return publishCharacterShortStory;
        }
        if (!work.content.hasPortrait) return publishCharacterMissingPortrait;
      case FanWorkType.worldbuilding:
        if (work.content.lore.trim().length < legacyProseMin &&
            work.description.trim().length < legacyProseMin) {
          return 'Worldbuilding needs lore or a description.';
        }
      case FanWorkType.other:
        final hasMedia = work.content.hasArtwork || work.hasCreatorNote;
        if (work.description.trim().length < legacyProseMin &&
            work.content.body.trim().length < legacyProseMin &&
            !hasMedia) {
          return 'This work needs a description, written content, or media.';
        }
    }
    return null;
  }
}

abstract final class FanWorkTypeCatalog {
  static const labels = <FanWorkType, String>{
    FanWorkType.manga: 'Manga',
    FanWorkType.story: 'Story',
    FanWorkType.drawing: 'Drawing',
    FanWorkType.character: 'Character',
    FanWorkType.worldbuilding: 'Worldbuilding',
    FanWorkType.other: 'Other',
  };

  static String label(FanWorkType type) => labels[type] ?? type.name;
}

/// Canonical English copy tokens. The Arabic renderings live in
/// `FanWorkCopy`; the server echoes these exact strings back in
/// `HttpsError` messages so a failure is localized by lookup, not by guesswork.
abstract final class FanWorkStrings {
  static const feedTitle = 'Fan Works';
  static const seeAll = 'See all Fan Works';
  static const create = 'Create Fan Work';
  static const chooseType = 'Choose a type';
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
  static const liked = 'Liked';
  static const bookmark = 'Save';
  static const bookmarked = 'Saved';
  static const rating = 'Rate';
  static const comments = 'Comments';
  static const addComment = 'Add a comment';
  static const sendComment = 'Send comment';
  static const noComments = 'No comments yet';
  static const noCommentsMessage = 'Be the first to reply to this Fan Work.';
  static const reply = 'Reply';
  static const likeComment = 'Like comment';
  static const deleteComment = 'Delete comment';
  static const reportComment = 'Report comment';
  static const missing = 'This Fan Work is unavailable.';
  static const emptyTitle = 'No Fan Works yet';
  static const emptyMessage =
      'Be the first to publish a drawing, story, manga, or character.';
  static const draftsEmpty = 'No drafts yet';
  static const offlineCached = 'Showing cached Fan Works. You are offline.';
  static const offline = 'You are offline. Connect and try again.';
  static const aiAssisted = 'AI-assisted';
  static const draftSaved = 'Draft saved';
  static const published = 'Fan Work published';
  static const publishFailed = 'Publishing failed. Your draft was kept.';
  static const uploadFailed = 'Upload failed. Your draft was kept.';
  static const uploadingMedia = 'Uploading file';
  static const cancelUpload = 'Cancel upload';
  static const retryUpload = 'Retry upload';
  static const uploadCanceled = 'Upload canceled. Your draft was kept.';
  static const uploadAlreadyRunning = 'An upload is already in progress.';
  static const uploadNothingToRetry = 'There is no upload to retry.';
  static const basicInfo = 'Basic information';
  static const category = 'Category';
  static const chooseCategory = 'Choose a category';
  static const cover = 'Cover';
  static const chooseCover = 'Choose a cover';
  static const creatorNote = 'Note from the creator';
  static const creatorNoteOptional = 'Optional';
  static const mangaPdf = 'Manga file';
  static const mangaPdfHint =
      'A single PDF that holds every page, in reading order.';
  static const storyPdf = 'Story file';
  static const storyPdfHint =
      'A single PDF that holds the whole story, in reading order.';
  static const choosePdf = 'Choose PDF';
  static const replacePdf = 'Replace PDF';
  static const removePdf = 'Remove PDF';
  static const drawingImage = 'Drawing';
  static const chooseDrawing = 'Choose drawing';
  static const characterPortrait = 'Portrait';
  static const choosePortrait = 'Choose portrait';
  static const cast = 'Characters';
  static const castEmpty = 'No characters yet';
  static const castEmptyMessage =
      'Add the characters that appear in this work.';
  static const addCharacter = 'Add a character';
  static const editCharacter = 'Edit character';
  static const characterName = 'Character name';
  static const characterBio = 'About this character';
  static const characterBioOptional = 'Optional';
  static const characterImage = 'Character image';
  static const characterImageOptional = 'Optional';
  static const saveCharacter = 'Save character';
  static const removeCharacter = 'Remove character';
  static const characterStory = 'Character story';
  static const characterAbilities = 'Abilities';
  static const characterAbilitiesOptional = 'Optional';
  static const characterSpecs = 'Specs';
  static const characterSpecsOptional = 'Optional';
  static const characterOrigin = 'How was this character made?';
  static const originHandmade = 'Hand-made';
  static const originAi = 'AI-assisted';
  static const readNow = 'Read';
  static const continueReading = 'Continue reading';
  static const startReading = 'Start reading';
  static const resumeFrom = 'Resume';
  static const markAsRead = 'Mark as read';
  static const markedAsRead = 'Marked as read';
  static const openDocument = 'Open';
  static const documentProtected = 'Protected file';
  static const documentProtectedHint =
      'This file opens inside Pubget and is never shared as a download link.';
  static const documentExpired =
      'The reading link expired. Reopen to continue.';
  static const documentUnavailable = 'This file could not be opened.';
  static const documentPages = 'pages';
  static const tableOfContents = 'Pages';
  static const closeReader = 'Close reader';
  static const goToPage = 'Go to page';
  static const loadingDocument = 'Opening the file';
  static const tagsAnime = 'Tags and anime';
  static const copyright = 'Copyright and source';
  static const requestRemoval = 'Request removal';
  static const revised = 'Revision saved';
  static const revisions = 'Revision history';
  static const noRevisions = 'No revisions yet';
  static const version = 'Version';
  static const revisionsCount = 'revisions';
}
