import 'package:cloud_firestore/cloud_firestore.dart';

import 'fan_work_taxonomy.dart';

/// The closed, creatable Fan Work types (owner brief: manga · story · drawing ·
/// character).
///
/// [worldbuilding] and [other] are retained read-only so Fan Works published
/// before the rebuild keep rendering; they are intentionally absent from the
/// creation catalog. The removed `aiCharacter` type is folded into
/// [character] + [FanWorkOrigin.aiGenerated] per spec §17.1.
enum FanWorkType {
  manga,
  story,
  drawing,
  character,
  worldbuilding,
  other;

  /// The four types a creator can publish today, in presentation order.
  static const creatable = <FanWorkType>[manga, story, drawing, character];

  bool get isCreatable => creatable.contains(this);

  /// True when the reading experience is a protected, in-app document.
  bool get readsAsDocument => this == manga || this == story;
}

enum FanWorkStatus { draft, published, archived }

enum FanWorkModerationStatus { pending, approved, rejected, flagged }

enum FanWorkVisibility { unpublished, public }

enum FanWorkReportReason { inappropriate, spam, copyright, harassment, other }

/// Where an uploaded file lands inside the work. Each role has its own storage
/// slot and its own server-side validation (a PDF may only fill [document], an
/// image may not).
enum FanWorkMediaRole {
  cover,
  document,
  artwork,
  portrait,
  characterPortrait;

  bool get isDocument => this == document;
}

final class FanWorkMedia {
  const FanWorkMedia({
    required this.mediaId,
    required this.path,
    this.contentType = 'image/jpeg',
    this.sizeBytes = 0,
  });

  final String mediaId;
  final String path;
  final String contentType;
  final int sizeBytes;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'mediaId': mediaId,
    'path': path,
    'contentType': contentType,
    if (sizeBytes > 0) 'sizeBytes': sizeBytes,
  };

  factory FanWorkMedia.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const FanWorkMedia(mediaId: '', path: '');
    }
    return FanWorkMedia(
      mediaId: map['mediaId'] as String? ?? '',
      path: map['path'] as String? ?? '',
      contentType: map['contentType'] as String? ?? 'image/jpeg',
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isEmpty => path.isEmpty;
  bool get isPdf => contentType == 'application/pdf';
}

/// The protected document that backs a manga or a story. It is never exposed as
/// a URL: readers stream it through a short-lived, server-minted signed URL
/// (see `FanWorkRepository.getDocumentAccess`).
final class FanWorkDocument {
  const FanWorkDocument({
    required this.mediaId,
    required this.path,
    this.contentType = 'application/pdf',
    this.sizeBytes = 0,
    this.pageCount,
  });

  final String mediaId;
  final String path;
  final String contentType;
  final int sizeBytes;
  final int? pageCount;

  bool get isEmpty => path.isEmpty;

  FanWorkMedia get media => FanWorkMedia(
    mediaId: mediaId,
    path: path,
    contentType: contentType,
    sizeBytes: sizeBytes,
  );

  Map<String, dynamic> toMap() => <String, dynamic>{
    'mediaId': mediaId,
    'path': path,
    'contentType': contentType,
    if (sizeBytes > 0) 'sizeBytes': sizeBytes,
    if (pageCount != null && pageCount! > 0) 'pageCount': pageCount,
  };

  factory FanWorkDocument.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const FanWorkDocument(mediaId: '', path: '');
    }
    final pageCount = (map['pageCount'] as num?)?.toInt();
    return FanWorkDocument(
      mediaId: map['mediaId'] as String? ?? '',
      path: map['path'] as String? ?? '',
      contentType: map['contentType'] as String? ?? 'application/pdf',
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      pageCount: pageCount != null && pageCount > 0 ? pageCount : null,
    );
  }
}

/// One character that appears inside a manga or a story.
///
/// The brief requires a `+` sheet that collects an optional portrait, a name
/// and a short bio, appending to a list until the creator publishes. Entries
/// stay inside the work document: they are small, they are only ever read with
/// the work, and a subcollection would cost a fan-out on the detail page.
final class FanWorkCharacter {
  const FanWorkCharacter({
    required this.id,
    required this.name,
    this.bio = '',
    this.imagePath = '',
    this.imageMediaId = '',
    this.index = 0,
  });

  final String id;
  final String name;
  final String bio;
  final String imagePath;
  final String imageMediaId;
  final int index;

  bool get hasImage => imagePath.isNotEmpty;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'name': name,
    'bio': bio,
    'imagePath': imagePath,
    'imageMediaId': imageMediaId,
    'index': index,
  };

  factory FanWorkCharacter.fromMap(Map<String, dynamic> map, {int? index}) {
    return FanWorkCharacter(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      bio: map['bio'] as String? ?? '',
      imagePath: map['imagePath'] as String? ?? '',
      imageMediaId: map['imageMediaId'] as String? ?? '',
      index: (map['index'] as num?)?.toInt() ?? index ?? 0,
    );
  }

  FanWorkCharacter copyWith({
    String? name,
    String? bio,
    String? imagePath,
    String? imageMediaId,
    int? index,
  }) => FanWorkCharacter(
    id: id,
    name: name ?? this.name,
    bio: bio ?? this.bio,
    imagePath: imagePath ?? this.imagePath,
    imageMediaId: imageMediaId ?? this.imageMediaId,
    index: index ?? this.index,
  );
}

/// Which reader a work has to be rendered with.
///
/// Pre-rebuild works have no PDF, so the reader cannot be chosen from the type
/// alone: a legacy manga is a list of page images and a legacy story is prose,
/// while everything written after the rebuild is a single document.
enum FanWorkReaderShape {
  /// A single PDF, opened by the document reader.
  document,

  /// Pre-rebuild image pages, opened by the legacy page reader.
  legacyPages,

  /// Pre-rebuild prose, opened by the legacy prose reader.
  legacyProse,

  /// The work has no readable content at all.
  unknown,
}

/// Per-reader progress for a document-backed work. Private to its owner.
final class FanWorkReadingProgress {
  const FanWorkReadingProgress({
    this.page = 0,
    this.pageCount = 0,
    this.progress = 0,
    this.completed = false,
    this.updatedAt,
  });

  /// Zero-based page index the reader stopped on.
  final int page;
  final int pageCount;

  /// 0..1 — a monotonic "how far in" measure, so a shortened re-upload never
  /// moves a reader backwards past what they already finished.
  final double progress;
  final bool completed;
  final DateTime? updatedAt;

  bool get isStarted => page > 0 || progress > 0;

  String get resumeLabel {
    if (pageCount > 0) return '$page / $pageCount';
    return progress > 0 ? '${(progress * 100).round()}%' : '';
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'page': page,
    'pageCount': pageCount,
    'progress': progress,
    'completed': completed,
  };

  factory FanWorkReadingProgress.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const FanWorkReadingProgress();
    final rawProgress = (map['progress'] as num?)?.toDouble() ?? 0;
    return FanWorkReadingProgress(
      page: (map['page'] as num?)?.toInt() ?? 0,
      pageCount: (map['pageCount'] as num?)?.toInt() ?? 0,
      progress: rawProgress.clamp(0.0, 1.0),
      completed: map['completed'] == true,
      updatedAt: _date(map['updatedAt']),
    );
  }
}

/// A short-lived grant to stream a work's protected document.
final class FanWorkDocumentAccess {
  const FanWorkDocumentAccess({
    required this.url,
    required this.expiresAt,
    this.pageCount,
  });

  final String url;
  final DateTime expiresAt;
  final int? pageCount;

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt.toUtc());
}

/// Legacy image page inside a pre-rebuild manga. Kept so published works keep
/// rendering; new manga publish a PDF instead.
final class FanWorkPage {
  const FanWorkPage({
    required this.mediaId,
    required this.path,
    required this.index,
    this.contentType = 'image/jpeg',
    this.caption = '',
  });

  final String mediaId;
  final String path;
  final int index;
  final String contentType;
  final String caption;

  FanWorkMedia get media =>
      FanWorkMedia(mediaId: mediaId, path: path, contentType: contentType);

  Map<String, dynamic> toMap() => <String, dynamic>{
    'mediaId': mediaId,
    'path': path,
    'contentType': contentType,
    'index': index,
    'caption': caption,
  };

  factory FanWorkPage.fromMap(Map<String, dynamic> map, {required int index}) {
    return FanWorkPage(
      mediaId: map['mediaId'] as String? ?? '',
      path: map['path'] as String? ?? '',
      index: (map['index'] as num?)?.toInt() ?? index,
      contentType: map['contentType'] as String? ?? 'image/jpeg',
      caption: map['caption'] as String? ?? '',
    );
  }
}

final class FanWorkChapter {
  const FanWorkChapter({
    required this.id,
    required this.title,
    required this.body,
    required this.index,
  });

  final String id;
  final String title;
  final String body;
  final int index;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'title': title,
    'body': body,
    'index': index,
  };

  factory FanWorkChapter.fromMap(
    Map<String, dynamic> map, {
    required int index,
  }) {
    return FanWorkChapter(
      id: map['id'] as String? ?? 'ch-${index + 1}',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      index: (map['index'] as num?)?.toInt() ?? index,
    );
  }
}

/// The type-specific body of a work. Only the fields relevant to the work's
/// type are ever populated; the rest stay at their defaults so a manga document
/// is not padded with dead keys.
final class FanWorkContent {
  const FanWorkContent({
    this.document,
    this.artwork,
    this.portrait,
    this.characters = const <FanWorkCharacter>[],
    this.personality = '',
    this.abilities = '',
    this.specs = '',
    this.body = '',
    this.chapters = const <FanWorkChapter>[],
    this.pages = const <FanWorkPage>[],
    this.lore = '',
  });

  /// PDF for manga/story.
  final FanWorkDocument? document;

  /// The single artwork of a drawing.
  final FanWorkMedia? artwork;

  /// The portrait of a character work.
  final FanWorkMedia? portrait;

  /// Cast list for manga/story.
  final List<FanWorkCharacter> characters;

  /// Character-only: personality sketch.
  final String personality;

  /// Character-only: abilities.
  final String abilities;

  /// Character-only: specs / measurements / class.
  final String specs;

  /// Legacy story body, kept so published prose works keep rendering.
  final String body;

  /// Legacy story chapters.
  final List<FanWorkChapter> chapters;

  /// Legacy manga image pages.
  final List<FanWorkPage> pages;

  /// Legacy worldbuilding lore.
  final String lore;

  List<FanWorkCharacter> get orderedCharacters {
    final copy = [...characters]..sort((a, b) => a.index.compareTo(b.index));
    return copy;
  }

  List<FanWorkChapter> get orderedChapters {
    final copy = [...chapters]..sort((a, b) => a.index.compareTo(b.index));
    return copy;
  }

  List<FanWorkPage> get orderedPages {
    final copy = [...pages]..sort((a, b) => a.index.compareTo(b.index));
    return copy;
  }

  bool get hasDocument => document?.isEmpty == false;
  bool get hasArtwork => artwork?.isEmpty == false;
  bool get hasPortrait => portrait?.isEmpty == false;
  bool get hasCast => orderedCharacters.any((entry) => entry.name.isNotEmpty);

  Map<String, dynamic> toMap() => <String, dynamic>{
    'document': document?.toMap(),
    'artwork': artwork?.toMap(),
    'portrait': portrait?.toMap(),
    'characters': characters
        .map((entry) => entry.toMap())
        .toList(growable: false),
    'personality': personality,
    'abilities': abilities,
    'specs': specs,
    'body': body,
    'chapters': chapters
        .map((chapter) => chapter.toMap())
        .toList(growable: false),
    'pages': pages.map((page) => page.toMap()).toList(growable: false),
    'lore': lore,
  };

  factory FanWorkContent.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const FanWorkContent();
    return FanWorkContent(
      document: _document(map['document']),
      artwork: _media(map['artwork']) ?? _media(map['image']),
      portrait: _media(map['portrait']) ?? _media(map['image']),
      characters: _characters(map['characters']),
      personality: map['personality'] as String? ?? '',
      abilities: map['abilities'] as String? ?? '',
      specs: map['specs'] as String? ?? map['background'] as String? ?? '',
      body: map['body'] as String? ?? '',
      chapters: _chapters(map['chapters']),
      pages: _pages(map['pages']),
      lore: map['lore'] as String? ?? '',
    );
  }

  FanWorkContent copyWith({
    FanWorkDocument? document,
    bool clearDocument = false,
    FanWorkMedia? artwork,
    bool clearArtwork = false,
    FanWorkMedia? portrait,
    bool clearPortrait = false,
    List<FanWorkCharacter>? characters,
    String? personality,
    String? abilities,
    String? specs,
    String? body,
    List<FanWorkChapter>? chapters,
    List<FanWorkPage>? pages,
    String? lore,
  }) => FanWorkContent(
    document: clearDocument ? null : document ?? this.document,
    artwork: clearArtwork ? null : artwork ?? this.artwork,
    portrait: clearPortrait ? null : portrait ?? this.portrait,
    characters: characters ?? this.characters,
    personality: personality ?? this.personality,
    abilities: abilities ?? this.abilities,
    specs: specs ?? this.specs,
    body: body ?? this.body,
    chapters: chapters ?? this.chapters,
    pages: pages ?? this.pages,
    lore: lore ?? this.lore,
  );
}

final class FanWorkCreatorSnapshot {
  const FanWorkCreatorSnapshot({this.username = '', this.avatarUrl = ''});

  final String username;
  final String avatarUrl;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'username': username,
    'avatarUrl': avatarUrl,
  };

  factory FanWorkCreatorSnapshot.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const FanWorkCreatorSnapshot();
    return FanWorkCreatorSnapshot(
      username: map['username'] as String? ?? '',
      avatarUrl: map['avatarUrl'] as String? ?? '',
    );
  }
}

/// The light contract every surface (feed, home, search, profile) needs. Home
/// must not download a whole work document to draw a card, so the preview
/// carries only what a card can show.
final class FanWorkPreview {
  const FanWorkPreview({
    required this.id,
    required this.type,
    required this.title,
    required this.creatorId,
    this.creatorName = '',
    this.coverPath = '',
    this.categoryId = '',
    this.origin = FanWorkOrigin.handmade,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.bookmarksCount = 0,
    this.hasDocument = false,
    this.documentPageCount,
    this.hasCast = false,
    this.publishedAt,
  });

  final String id;
  final FanWorkType type;
  final String title;
  final String creatorId;
  final String creatorName;
  final String coverPath;
  final String categoryId;
  final FanWorkOrigin origin;
  final int likesCount;
  final int commentsCount;
  final int bookmarksCount;
  final bool hasDocument;
  final int? documentPageCount;
  final bool hasCast;
  final DateTime? publishedAt;

  FanWorkCategory? get category => FanWorkCategories.byId(type, categoryId);

  factory FanWorkPreview.fromWork(FanWork work) => FanWorkPreview(
    id: work.id,
    type: work.type,
    title: work.title,
    creatorId: work.creatorId,
    creatorName: work.creatorSnapshot.username,
    coverPath: work.coverPath,
    categoryId: work.categoryId,
    origin: work.origin,
    likesCount: work.likesCount,
    commentsCount: work.commentsCount,
    bookmarksCount: work.bookmarksCount,
    hasDocument: work.content.hasDocument,
    documentPageCount: work.content.document?.pageCount,
    hasCast: work.content.hasCast,
    publishedAt: work.publishedAt,
  );

  factory FanWorkPreview.fromMap(
    Map<String, dynamic> map, {
    required String id,
  }) {
    final cover = _media(map['cover']);
    final document = _document(map['document']);
    final snapshot = map['creatorSnapshot'] is Map
        ? FanWorkCreatorSnapshot.fromMap(
            Map<String, dynamic>.from(map['creatorSnapshot'] as Map),
          )
        : const FanWorkCreatorSnapshot();
    final content = map['content'] is Map
        ? Map<String, dynamic>.from(map['content'] as Map)
        : const <String, dynamic>{};
    final characters = content['characters'];
    return FanWorkPreview(
      id: id,
      type: fanWorkTypeFrom(map['type']),
      title: map['title'] as String? ?? '',
      creatorId: map['creatorId'] as String? ?? '',
      creatorName: snapshot.username,
      coverPath: cover?.path ?? _media(content['artwork'])?.path ?? '',
      categoryId: map['category'] as String? ?? '',
      origin: FanWorkOrigin.from(map['origin']),
      likesCount: (map['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (map['commentsCount'] as num?)?.toInt() ?? 0,
      bookmarksCount: (map['bookmarksCount'] as num?)?.toInt() ?? 0,
      hasDocument: document?.isEmpty == false,
      documentPageCount: document?.pageCount,
      hasCast: characters is List && characters.isNotEmpty,
      publishedAt: _date(map['publishedAt']),
    );
  }
}

final class FanWorkCopyright {
  const FanWorkCopyright({
    this.originalWorkId = '',
    this.sourceTitle = '',
    this.credit = '',
    this.license = 'fan-work',
  });

  final String originalWorkId;
  final String sourceTitle;
  final String credit;
  final String license;

  bool get isEmpty =>
      originalWorkId.isEmpty && sourceTitle.isEmpty && credit.isEmpty;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'originalWorkId': originalWorkId,
    'sourceTitle': sourceTitle,
    'credit': credit,
    'license': license,
  };

  factory FanWorkCopyright.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const FanWorkCopyright();
    return FanWorkCopyright(
      originalWorkId: map['originalWorkId'] as String? ?? '',
      sourceTitle: map['sourceTitle'] as String? ?? '',
      credit: map['credit'] as String? ?? '',
      license: map['license'] as String? ?? 'fan-work',
    );
  }

  FanWorkCopyright copyWith({
    String? originalWorkId,
    String? sourceTitle,
    String? credit,
    String? license,
  }) => FanWorkCopyright(
    originalWorkId: originalWorkId ?? this.originalWorkId,
    sourceTitle: sourceTitle ?? this.sourceTitle,
    credit: credit ?? this.credit,
    license: license ?? this.license,
  );
}

final class FanWork {
  const FanWork({
    required this.id,
    required this.creatorId,
    required this.type,
    required this.title,
    required this.description,
    required this.content,
    required this.status,
    required this.moderationStatus,
    required this.visibility,
    required this.createdAt,
    required this.updatedAt,
    this.creatorSnapshot = const FanWorkCreatorSnapshot(),
    this.cover,
    this.categoryId = '',
    this.creatorNote = '',
    this.origin = FanWorkOrigin.handmade,
    this.tags = const <String>[],
    this.animeId = '',
    this.animeTitle = '',
    this.characterIds = const <String>[],
    this.likesCount = 0,
    this.commentsCount = 0,
    this.bookmarksCount = 0,
    this.reportsCount = 0,
    this.ratingsCount = 0,
    this.ratingsAverage = 0,
    this.publishedAt,
    this.version = 1,
    this.schemaVersion = 1,
    this.copyright = const FanWorkCopyright(),
    this.removalRequested = false,
  });

  final String id;
  final String creatorId;
  final FanWorkCreatorSnapshot creatorSnapshot;
  final FanWorkType type;

  /// For [FanWorkType.character] this is the character's name; for every other
  /// type it is the work's title. One field keeps search, cards, comments and
  /// share text uniform across all four types.
  final String title;

  /// For [FanWorkType.character] this is the character's story.
  final String description;

  final FanWorkMedia? cover;
  final FanWorkContent content;
  final String categoryId;

  /// نبذة عن الكاتب/الرسام/صانع الشخصية. Optional on every type.
  final String creatorNote;
  final FanWorkOrigin origin;
  final List<String> tags;
  final String animeId;
  final String animeTitle;
  final List<String> characterIds;
  final FanWorkVisibility visibility;
  final FanWorkStatus status;
  final FanWorkModerationStatus moderationStatus;
  final int likesCount;
  final int commentsCount;
  final int bookmarksCount;
  final int reportsCount;
  final int ratingsCount;
  final double ratingsAverage;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? publishedAt;
  final int version;
  final int schemaVersion;
  final FanWorkCopyright copyright;
  final bool removalRequested;

  bool get isDraft => status == FanWorkStatus.draft;
  bool get isPublished => status == FanWorkStatus.published;
  bool get isArchived => status == FanWorkStatus.archived;
  bool get isAiAssisted => origin == FanWorkOrigin.aiGenerated;
  bool get hasCreatorNote => creatorNote.trim().isNotEmpty;
  bool get isPubliclyListed =>
      status == FanWorkStatus.published &&
      moderationStatus == FanWorkModerationStatus.approved &&
      visibility == FanWorkVisibility.public;

  FanWorkCategory? get category => FanWorkCategories.byId(type, categoryId);

  /// The image a card should draw: artwork, then portrait, then cover.
  String get coverPath {
    final artwork = content.artwork?.path ?? '';
    if (artwork.isNotEmpty) return artwork;
    final portrait = content.portrait?.path ?? '';
    if (portrait.isNotEmpty) return portrait;
    return cover?.path ?? '';
  }

  /// The reading surface: a PDF for manga/story, legacy image pages for a
  /// pre-rebuild manga, or the single artwork for a drawing.
  bool get hasReader =>
      content.hasDocument ||
      content.orderedPages.isNotEmpty ||
      content.hasArtwork ||
      content.hasPortrait;

  FanWorkPreview get preview => FanWorkPreview.fromWork(this);

  Map<String, dynamic> toMap() => <String, dynamic>{
    'creatorId': creatorId,
    'creatorSnapshot': creatorSnapshot.toMap(),
    'type': type.name,
    'title': title,
    'description': description,
    'cover': cover?.toMap(),
    'category': categoryId,
    'creatorNote': creatorNote,
    'origin': origin.name,
    'content': content.toMap(),
    'tags': tags,
    'animeId': animeId,
    'animeTitle': animeTitle,
    'characterIds': characterIds,
    'visibility': visibility.name,
    'status': status.name,
    'moderationStatus': moderationStatus.name,
    'likesCount': likesCount,
    'commentsCount': commentsCount,
    'bookmarksCount': bookmarksCount,
    'reportsCount': reportsCount,
    'ratingsCount': ratingsCount,
    'ratingsAverage': ratingsAverage,
    'createdAt': createdAt?.toUtc().toIso8601String(),
    'updatedAt': updatedAt?.toUtc().toIso8601String(),
    'publishedAt': publishedAt?.toUtc().toIso8601String(),
    'version': version,
    'schemaVersion': schemaVersion,
    'copyright': copyright.toMap(),
    'removalRequested': removalRequested,
    'searchTitle': title.trim().toLowerCase(),
  };

  factory FanWork.fromMap(Map<String, dynamic> map, {required String id}) {
    final rawType = map['type'] as String?;
    return FanWork(
      id: id,
      creatorId: map['creatorId'] as String? ?? '',
      creatorSnapshot: FanWorkCreatorSnapshot.fromMap(
        map['creatorSnapshot'] is Map
            ? Map<String, dynamic>.from(map['creatorSnapshot'] as Map)
            : null,
      ),
      type: fanWorkTypeFrom(rawType),
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      cover: _media(map['cover']),
      categoryId: map['category'] as String? ?? '',
      creatorNote: map['creatorNote'] as String? ?? '',
      origin: FanWorkOrigin.from(
        map['origin'] ?? (rawType == 'aiCharacter' ? 'aiGenerated' : null),
      ),
      content: FanWorkContent.fromMap(
        map['content'] is Map
            ? Map<String, dynamic>.from(map['content'] as Map)
            : null,
      ),
      tags:
          (map['tags'] as List<Object?>?)?.whereType<String>().toList() ??
          const <String>[],
      animeId: map['animeId'] as String? ?? '',
      animeTitle: map['animeTitle'] as String? ?? '',
      characterIds:
          (map['characterIds'] as List<Object?>?)
              ?.whereType<String>()
              .toList() ??
          const <String>[],
      visibility: FanWorkVisibility.values.firstWhere(
        (value) => value.name == map['visibility'],
        orElse: () => FanWorkVisibility.unpublished,
      ),
      status: FanWorkStatus.values.firstWhere(
        (value) => value.name == map['status'],
        orElse: () => FanWorkStatus.draft,
      ),
      moderationStatus: FanWorkModerationStatus.values.firstWhere(
        (value) => value.name == map['moderationStatus'],
        orElse: () => FanWorkModerationStatus.pending,
      ),
      likesCount: (map['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (map['commentsCount'] as num?)?.toInt() ?? 0,
      bookmarksCount: (map['bookmarksCount'] as num?)?.toInt() ?? 0,
      reportsCount: (map['reportsCount'] as num?)?.toInt() ?? 0,
      ratingsCount: (map['ratingsCount'] as num?)?.toInt() ?? 0,
      ratingsAverage: (map['ratingsAverage'] as num?)?.toDouble() ?? 0,
      createdAt: _date(map['createdAt']),
      updatedAt: _date(map['updatedAt']),
      publishedAt: _date(map['publishedAt']),
      version: (map['version'] as num?)?.toInt() ?? 1,
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
      copyright: FanWorkCopyright.fromMap(
        map['copyright'] is Map
            ? Map<String, dynamic>.from(map['copyright'] as Map)
            : null,
      ),
      removalRequested: map['removalRequested'] == true,
    );
  }

  FanWork copyWith({
    String? title,
    String? description,
    FanWorkType? type,
    FanWorkContent? content,
    FanWorkMedia? cover,
    bool clearCover = false,
    String? categoryId,
    String? creatorNote,
    FanWorkOrigin? origin,
    List<String>? tags,
    String? animeId,
    String? animeTitle,
    List<String>? characterIds,
    FanWorkStatus? status,
    FanWorkModerationStatus? moderationStatus,
    FanWorkVisibility? visibility,
    FanWorkCopyright? copyright,
    int? version,
    bool? removalRequested,
  }) => FanWork(
    id: id,
    creatorId: creatorId,
    creatorSnapshot: creatorSnapshot,
    type: type ?? this.type,
    title: title ?? this.title,
    description: description ?? this.description,
    cover: clearCover ? null : cover ?? this.cover,
    content: content ?? this.content,
    categoryId: categoryId ?? this.categoryId,
    creatorNote: creatorNote ?? this.creatorNote,
    origin: origin ?? this.origin,
    tags: tags ?? this.tags,
    animeId: animeId ?? this.animeId,
    animeTitle: animeTitle ?? this.animeTitle,
    characterIds: characterIds ?? this.characterIds,
    visibility: visibility ?? this.visibility,
    status: status ?? this.status,
    moderationStatus: moderationStatus ?? this.moderationStatus,
    likesCount: likesCount,
    commentsCount: commentsCount,
    bookmarksCount: bookmarksCount,
    reportsCount: reportsCount,
    ratingsCount: ratingsCount,
    ratingsAverage: ratingsAverage,
    createdAt: createdAt,
    updatedAt: updatedAt,
    publishedAt: publishedAt,
    version: version ?? this.version,
    schemaVersion: schemaVersion,
    copyright: copyright ?? this.copyright,
    removalRequested: removalRequested ?? this.removalRequested,
  );
}

final class FanWorkComment {
  const FanWorkComment({
    required this.id,
    required this.authorId,
    required this.text,
    this.likesCount = 0,
    this.createdAt,
    this.replyToCommentId,
    this.mentions = const <String>[],
  });

  final String id;
  final String authorId;
  final String text;
  final int likesCount;
  final DateTime? createdAt;
  final String? replyToCommentId;
  final List<String> mentions;

  factory FanWorkComment.fromMap(
    Map<String, dynamic> map, {
    required String id,
  }) {
    return FanWorkComment(
      id: id,
      authorId: map['authorId'] as String? ?? '',
      text: map['text'] as String? ?? '',
      likesCount: (map['likesCount'] as num?)?.toInt() ?? 0,
      createdAt: _date(map['createdAt']),
      replyToCommentId: map['replyToCommentId'] as String?,
      mentions:
          (map['mentions'] as List<Object?>?)?.whereType<String>().toList() ??
          const <String>[],
    );
  }
}

final class FanWorkRevision {
  const FanWorkRevision({
    required this.version,
    required this.title,
    required this.description,
    required this.content,
    required this.copyright,
    required this.createdAt,
    required this.creatorId,
  });

  final int version;
  final String title;
  final String description;
  final FanWorkContent content;
  final FanWorkCopyright copyright;
  final DateTime? createdAt;
  final String creatorId;

  factory FanWorkRevision.fromMap(
    Map<String, dynamic> map, {
    required int version,
  }) {
    return FanWorkRevision(
      version: version,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      content: FanWorkContent.fromMap(
        map['content'] is Map
            ? Map<String, dynamic>.from(map['content'] as Map)
            : null,
      ),
      copyright: FanWorkCopyright.fromMap(
        map['copyright'] is Map
            ? Map<String, dynamic>.from(map['copyright'] as Map)
            : null,
      ),
      createdAt: _date(map['createdAt']),
      creatorId: map['creatorId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'version': version,
    'title': title,
    'description': description,
    'content': content.toMap(),
    'copyright': copyright.toMap(),
    'createdAt': createdAt?.toUtc().toIso8601String(),
    'creatorId': creatorId,
  };
}

/// The autosaved, device-local shape of an in-progress work. Restored after
/// the app is killed so a creator never loses typed text (spec §17.2).
final class FanWorkDraft {
  const FanWorkDraft({
    this.workId,
    required this.type,
    this.title = '',
    this.description = '',
    this.categoryId = '',
    this.creatorNote = '',
    this.origin = FanWorkOrigin.handmade,
    this.tags = const <String>[],
    this.animeId = '',
    this.animeTitle = '',
    this.characterIds = const <String>[],
    this.characters = const <FanWorkCharacter>[],
    this.personality = '',
    this.abilities = '',
    this.specs = '',
    this.clearCover = false,
    this.copyright = const FanWorkCopyright(),
  });

  final String? workId;
  final FanWorkType type;
  final String title;
  final String description;
  final String categoryId;
  final String creatorNote;
  final FanWorkOrigin origin;
  final List<String> tags;
  final String animeId;
  final String animeTitle;
  final List<String> characterIds;
  final List<FanWorkCharacter> characters;
  final String personality;
  final String abilities;
  final String specs;
  final bool clearCover;
  final FanWorkCopyright copyright;

  bool get isNew => workId == null || workId!.isEmpty;

  Map<String, dynamic> toCallableMap() => <String, dynamic>{
    if (workId != null && workId!.isNotEmpty) 'workId': workId,
    'type': type.name,
    'title': title,
    'description': description,
    'category': categoryId,
    'creatorNote': creatorNote,
    'origin': origin.name,
    'tags': tags,
    'animeId': animeId,
    'animeTitle': animeTitle,
    'characterIds': characterIds,
    'characters': characters.map((entry) => entry.toMap()).toList(),
    'personality': personality,
    'abilities': abilities,
    'specs': specs,
    'clearCover': clearCover,
    'copyright': copyright.toMap(),
  };

  Map<String, dynamic> toLocalMap() => <String, dynamic>{
    'workId': workId,
    'type': type.name,
    'title': title,
    'description': description,
    'categoryId': categoryId,
    'creatorNote': creatorNote,
    'origin': origin.name,
    'tags': tags,
    'animeId': animeId,
    'animeTitle': animeTitle,
    'characterIds': characterIds,
    'characters': characters.map((entry) => entry.toMap()).toList(),
    'personality': personality,
    'abilities': abilities,
    'specs': specs,
    'clearCover': clearCover,
    'copyright': copyright.toMap(),
  };

  factory FanWorkDraft.fromLocalMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const FanWorkDraft(type: FanWorkType.manga);
    }
    final characters = map['characters'];
    return FanWorkDraft(
      workId: map['workId'] as String?,
      type: fanWorkTypeFrom(map['type']),
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      categoryId: map['categoryId'] as String? ?? '',
      creatorNote: map['creatorNote'] as String? ?? '',
      origin: FanWorkOrigin.from(map['origin']),
      tags:
          (map['tags'] as List<Object?>?)?.whereType<String>().toList() ??
          const <String>[],
      animeId: map['animeId'] as String? ?? '',
      animeTitle: map['animeTitle'] as String? ?? '',
      characterIds:
          (map['characterIds'] as List<Object?>?)
              ?.whereType<String>()
              .toList() ??
          const <String>[],
      characters: characters is List
          ? [
              for (var i = 0; i < characters.length; i++)
                if (characters[i] is Map)
                  FanWorkCharacter.fromMap(
                    Map<String, dynamic>.from(characters[i] as Map),
                    index: i,
                  ),
            ]
          : const <FanWorkCharacter>[],
      personality: map['personality'] as String? ?? '',
      abilities: map['abilities'] as String? ?? '',
      specs: map['specs'] as String? ?? '',
      clearCover: map['clearCover'] == true,
      copyright: FanWorkCopyright.fromMap(
        map['copyright'] is Map
            ? Map<String, dynamic>.from(map['copyright'] as Map)
            : null,
      ),
    );
  }

  factory FanWorkDraft.fromWork(FanWork work) => FanWorkDraft(
    workId: work.id,
    type: work.type,
    title: work.title,
    description: work.description,
    categoryId: work.categoryId,
    creatorNote: work.creatorNote,
    origin: work.origin,
    tags: work.tags,
    animeId: work.animeId,
    animeTitle: work.animeTitle,
    characterIds: work.characterIds,
    characters: work.content.orderedCharacters,
    personality: work.content.personality,
    abilities: work.content.abilities,
    specs: work.content.specs,
    copyright: work.copyright,
  );

  FanWorkDraft copyWith({
    String? workId,
    FanWorkType? type,
    String? title,
    String? description,
    String? categoryId,
    String? creatorNote,
    FanWorkOrigin? origin,
    List<String>? tags,
    String? animeId,
    String? animeTitle,
    List<String>? characterIds,
    List<FanWorkCharacter>? characters,
    String? personality,
    String? abilities,
    String? specs,
    bool? clearCover,
    FanWorkCopyright? copyright,
  }) => FanWorkDraft(
    workId: workId ?? this.workId,
    type: type ?? this.type,
    title: title ?? this.title,
    description: description ?? this.description,
    categoryId: categoryId ?? this.categoryId,
    creatorNote: creatorNote ?? this.creatorNote,
    origin: origin ?? this.origin,
    tags: tags ?? this.tags,
    animeId: animeId ?? this.animeId,
    animeTitle: animeTitle ?? this.animeTitle,
    characterIds: characterIds ?? this.characterIds,
    characters: characters ?? this.characters,
    personality: personality ?? this.personality,
    abilities: abilities ?? this.abilities,
    specs: specs ?? this.specs,
    clearCover: clearCover ?? this.clearCover,
    copyright: copyright ?? this.copyright,
  );
}

final class FanWorkListPage {
  const FanWorkListPage({
    required this.items,
    required this.hasMore,
    this.cursor,
  });

  final List<FanWork> items;
  final bool hasMore;
  final FanWork? cursor;
}

/// A one-shot grant to upload exactly one file into one work.
final class FanWorkUploadTicket {
  const FanWorkUploadTicket({
    required this.workId,
    required this.mediaId,
    required this.path,
    required this.contentType,
    required this.role,
    required this.uploadUrl,
    required this.maxBytes,
    required this.expiresAt,
  });

  final String workId;
  final String mediaId;
  final String path;
  final String contentType;
  final FanWorkMediaRole role;

  /// The URL the bytes go to, in one of two shapes the server chose when it
  /// minted this ticket: a V4 resumable-session URI for a document, a bounded
  /// one-shot signed `PUT` for an image. Neither ever creates a permanent
  /// `downloadToken` on the object, which is what stops a Fan Work file from
  /// being shared as a link after the fact.
  final String uploadUrl;
  final int maxBytes;
  final DateTime expiresAt;

  /// Whether [uploadUrl] speaks the resumable session protocol.
  ///
  /// Mirrors `isDocumentRole` in `functions/src/fanWorksSchema.js`: only the
  /// document role is opened as a session, every image role is a one-shot
  /// signed `PUT`. Uploading with the wrong protocol fails on every attempt.
  bool get isResumableSession => role.isDocument;
}

final class FanWorkAnalytics {
  const FanWorkAnalytics({
    required this.totalWorks,
    required this.publishedWorks,
    required this.draftWorks,
    required this.totalLikes,
    required this.totalBookmarks,
    required this.totalComments,
    required this.totalRatings,
    required this.averageRating,
    required this.worksByType,
    required this.topWorks,
  });

  final int totalWorks;
  final int publishedWorks;
  final int draftWorks;
  final int totalLikes;
  final int totalBookmarks;
  final int totalComments;
  final int totalRatings;
  final double averageRating;
  final Map<String, int> worksByType;
  final List<FanWorkPreview> topWorks;

  factory FanWorkAnalytics.fromMap(Map<String, dynamic> map) {
    return FanWorkAnalytics(
      totalWorks: (map['totalWorks'] as num?)?.toInt() ?? 0,
      publishedWorks: (map['publishedWorks'] as num?)?.toInt() ?? 0,
      draftWorks: (map['draftWorks'] as num?)?.toInt() ?? 0,
      totalLikes: (map['totalLikes'] as num?)?.toInt() ?? 0,
      totalBookmarks: (map['totalBookmarks'] as num?)?.toInt() ?? 0,
      totalComments: (map['totalComments'] as num?)?.toInt() ?? 0,
      totalRatings: (map['totalRatings'] as num?)?.toInt() ?? 0,
      averageRating: (map['averageRating'] as num?)?.toDouble() ?? 0.0,
      worksByType: Map<String, int>.from(map['worksByType'] ?? {}),
      topWorks:
          (map['topWorks'] as List?)
              ?.map(
                (entry) => FanWorkPreview.fromMap(
                  Map<String, dynamic>.from(entry as Map),
                  id: entry['id'] as String? ?? '',
                ),
              )
              .toList(growable: false) ??
          const <FanWorkPreview>[],
    );
  }
}

FanWorkType fanWorkTypeFrom(Object? raw) {
  // `aiCharacter` is a retired type: it is a character with an AI origin.
  if (raw == 'aiCharacter') return FanWorkType.character;
  return FanWorkType.values.firstWhere(
    (value) => value.name == raw,
    orElse: () => FanWorkType.other,
  );
}

FanWorkMedia? _media(Object? raw) {
  if (raw is! Map) return null;
  return FanWorkMedia.fromMap(Map<String, dynamic>.from(raw));
}

FanWorkDocument? _document(Object? raw) {
  if (raw is! Map) return null;
  return FanWorkDocument.fromMap(Map<String, dynamic>.from(raw));
}

List<FanWorkCharacter> _characters(Object? raw) {
  if (raw is! List) return const <FanWorkCharacter>[];
  return <FanWorkCharacter>[
    for (var i = 0; i < raw.length; i++)
      if (raw[i] is Map)
        FanWorkCharacter.fromMap(
          Map<String, dynamic>.from(raw[i] as Map),
          index: i,
        ),
  ];
}

List<FanWorkPage> _pages(Object? raw) {
  if (raw is! List) return const <FanWorkPage>[];
  return <FanWorkPage>[
    for (var i = 0; i < raw.length; i++)
      if (raw[i] is Map)
        FanWorkPage.fromMap(Map<String, dynamic>.from(raw[i] as Map), index: i),
  ];
}

List<FanWorkChapter> _chapters(Object? raw) {
  if (raw is! List) return const <FanWorkChapter>[];
  return <FanWorkChapter>[
    for (var i = 0; i < raw.length; i++)
      if (raw[i] is Map)
        FanWorkChapter.fromMap(
          Map<String, dynamic>.from(raw[i] as Map),
          index: i,
        ),
  ];
}

DateTime? _date(Object? value) {
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) return DateTime.tryParse(value);
  return null;
}
