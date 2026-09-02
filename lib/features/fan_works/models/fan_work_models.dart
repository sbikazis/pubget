import 'package:cloud_firestore/cloud_firestore.dart';

enum FanWorkType {
  manga,
  drawing,
  story,
  character,
  aiCharacter,
  worldbuilding,
  other,
}

enum FanWorkStatus { draft, published, archived }

enum FanWorkModerationStatus { pending, approved, rejected, flagged }

enum FanWorkVisibility { unpublished, public }

enum FanWorkReportReason { inappropriate, spam, copyright, harassment, other }

enum FanWorkMediaRole { cover, page, image, extra }

final class FanWorkMedia {
  const FanWorkMedia({
    required this.mediaId,
    required this.path,
    this.contentType = 'image/jpeg',
  });

  final String mediaId;
  final String path;
  final String contentType;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'mediaId': mediaId,
    'path': path,
    'contentType': contentType,
  };

  factory FanWorkMedia.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const FanWorkMedia(mediaId: '', path: '');
    }
    return FanWorkMedia(
      mediaId: map['mediaId'] as String? ?? '',
      path: map['path'] as String? ?? '',
      contentType: map['contentType'] as String? ?? 'image/jpeg',
    );
  }

  bool get isEmpty => path.isEmpty;
}

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
      contentType: map['contentType'] as String? ?? 'image/jpeg',
      index: (map['index'] as num?)?.toInt() ?? index,
      caption: map['caption'] as String? ?? '',
    );
  }

  FanWorkPage copyWith({String? caption, int? index}) => FanWorkPage(
    mediaId: mediaId,
    path: path,
    contentType: contentType,
    index: index ?? this.index,
    caption: caption ?? this.caption,
  );
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

  FanWorkChapter copyWith({String? title, String? body, int? index}) =>
      FanWorkChapter(
        id: id,
        title: title ?? this.title,
        body: body ?? this.body,
        index: index ?? this.index,
      );
}

final class FanWorkNamedEntry {
  const FanWorkNamedEntry({required this.name, this.description = ''});

  final String name;
  final String description;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'name': name,
    'description': description,
  };

  factory FanWorkNamedEntry.fromMap(Map<String, dynamic> map) {
    return FanWorkNamedEntry(
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
    );
  }
}

final class FanWorkContent {
  const FanWorkContent({
    this.pages = const <FanWorkPage>[],
    this.images = const <FanWorkMedia>[],
    this.body = '',
    this.chapters = const <FanWorkChapter>[],
    this.name = '',
    this.personality = '',
    this.abilities = '',
    this.background = '',
    this.image,
    this.lore = '',
    this.locations = const <FanWorkNamedEntry>[],
    this.factions = const <FanWorkNamedEntry>[],
    this.characters = const <FanWorkNamedEntry>[],
  });

  final List<FanWorkPage> pages;
  final List<FanWorkMedia> images;
  final String body;
  final List<FanWorkChapter> chapters;
  final String name;
  final String personality;
  final String abilities;
  final String background;
  final FanWorkMedia? image;
  final String lore;
  final List<FanWorkNamedEntry> locations;
  final List<FanWorkNamedEntry> factions;
  final List<FanWorkNamedEntry> characters;

  List<FanWorkPage> get orderedPages {
    final copy = [...pages]..sort((a, b) => a.index.compareTo(b.index));
    return copy;
  }

  List<FanWorkChapter> get orderedChapters {
    final copy = [...chapters]..sort((a, b) => a.index.compareTo(b.index));
    return copy;
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'pages': pages.map((page) => page.toMap()).toList(growable: false),
    'images': images.map((image) => image.toMap()).toList(growable: false),
    'body': body,
    'chapters': chapters
        .map((chapter) => chapter.toMap())
        .toList(growable: false),
    'name': name,
    'personality': personality,
    'abilities': abilities,
    'background': background,
    'image': image?.toMap(),
    'lore': lore,
    'locations': locations
        .map((entry) => entry.toMap())
        .toList(growable: false),
    'factions': factions.map((entry) => entry.toMap()).toList(growable: false),
    'characters': characters
        .map((entry) => entry.toMap())
        .toList(growable: false),
  };

  factory FanWorkContent.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const FanWorkContent();
    return FanWorkContent(
      pages: _pages(map['pages']),
      images: _mediaList(map['images']),
      body: map['body'] as String? ?? '',
      chapters: _chapters(map['chapters']),
      name: map['name'] as String? ?? '',
      personality: map['personality'] as String? ?? '',
      abilities: map['abilities'] as String? ?? '',
      background: map['background'] as String? ?? '',
      image: map['image'] is Map
          ? FanWorkMedia.fromMap(Map<String, dynamic>.from(map['image'] as Map))
          : null,
      lore: map['lore'] as String? ?? '',
      locations: _entries(map['locations']),
      factions: _entries(map['factions']),
      characters: _entries(map['characters']),
    );
  }

  FanWorkContent copyWith({
    List<FanWorkPage>? pages,
    List<FanWorkMedia>? images,
    String? body,
    List<FanWorkChapter>? chapters,
    String? name,
    String? personality,
    String? abilities,
    String? background,
    FanWorkMedia? image,
    bool clearImage = false,
    String? lore,
    List<FanWorkNamedEntry>? locations,
    List<FanWorkNamedEntry>? factions,
    List<FanWorkNamedEntry>? characters,
  }) => FanWorkContent(
    pages: pages ?? this.pages,
    images: images ?? this.images,
    body: body ?? this.body,
    chapters: chapters ?? this.chapters,
    name: name ?? this.name,
    personality: personality ?? this.personality,
    abilities: abilities ?? this.abilities,
    background: background ?? this.background,
    image: clearImage ? null : image ?? this.image,
    lore: lore ?? this.lore,
    locations: locations ?? this.locations,
    factions: factions ?? this.factions,
    characters: characters ?? this.characters,
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

final class FanWorkPreview {
  const FanWorkPreview({
    required this.id,
    required this.type,
    required this.title,
    required this.creatorId,
    this.creatorName = '',
    this.coverPath = '',
    this.publishedAt,
  });

  final String id;
  final FanWorkType type;
  final String title;
  final String creatorId;
  final String creatorName;
  final String coverPath;
  final DateTime? publishedAt;

  factory FanWorkPreview.fromWork(FanWork work) => FanWorkPreview(
    id: work.id,
    type: work.type,
    title: work.title,
    creatorId: work.creatorId,
    creatorName: work.creatorSnapshot.username,
    coverPath: work.cover?.path ?? '',
    publishedAt: work.publishedAt,
  );

  factory FanWorkPreview.fromMap(
    Map<String, dynamic> map, {
    required String id,
  }) {
    final cover = map['cover'] is Map
        ? FanWorkMedia.fromMap(Map<String, dynamic>.from(map['cover'] as Map))
        : null;
    final snapshot = map['creatorSnapshot'] is Map
        ? FanWorkCreatorSnapshot.fromMap(
            Map<String, dynamic>.from(map['creatorSnapshot'] as Map),
          )
        : const FanWorkCreatorSnapshot();
    return FanWorkPreview(
      id: id,
      type: fanWorkTypeFrom(map['type']),
      title: map['title'] as String? ?? '',
      creatorId: map['creatorId'] as String? ?? '',
      creatorName: snapshot.username,
      coverPath: cover?.path ?? '',
      publishedAt: _date(map['publishedAt']),
    );
  }
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
    this.tags = const <String>[],
    this.animeId = '',
    this.animeTitle = '',
    this.characterIds = const <String>[],
    this.likesCount = 0,
    this.bookmarksCount = 0,
    this.reportsCount = 0,
    this.publishedAt,
    this.version = 1,
    this.schemaVersion = 1,
  });

  final String id;
  final String creatorId;
  final FanWorkCreatorSnapshot creatorSnapshot;
  final FanWorkType type;
  final String title;
  final String description;
  final FanWorkMedia? cover;
  final FanWorkContent content;
  final List<String> tags;
  final String animeId;
  final String animeTitle;
  final List<String> characterIds;
  final FanWorkVisibility visibility;
  final FanWorkStatus status;
  final FanWorkModerationStatus moderationStatus;
  final int likesCount;
  final int bookmarksCount;
  final int reportsCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? publishedAt;
  final int version;
  final int schemaVersion;

  bool get isDraft => status == FanWorkStatus.draft;
  bool get isPublished => status == FanWorkStatus.published;
  bool get isArchived => status == FanWorkStatus.archived;
  bool get isAiAssisted => type == FanWorkType.aiCharacter;
  bool get isPubliclyListed =>
      status == FanWorkStatus.published &&
      moderationStatus == FanWorkModerationStatus.approved &&
      visibility == FanWorkVisibility.public;

  FanWorkPreview get preview => FanWorkPreview.fromWork(this);

  Map<String, dynamic> toMap() => <String, dynamic>{
    'creatorId': creatorId,
    'creatorSnapshot': creatorSnapshot.toMap(),
    'type': type.name,
    'title': title,
    'description': description,
    'cover': cover?.toMap(),
    'content': content.toMap(),
    'tags': tags,
    'animeId': animeId,
    'animeTitle': animeTitle,
    'characterIds': characterIds,
    'visibility': visibility.name,
    'status': status.name,
    'moderationStatus': moderationStatus.name,
    'likesCount': likesCount,
    'bookmarksCount': bookmarksCount,
    'reportsCount': reportsCount,
    'createdAt': createdAt?.toUtc().toIso8601String(),
    'updatedAt': updatedAt?.toUtc().toIso8601String(),
    'publishedAt': publishedAt?.toUtc().toIso8601String(),
    'version': version,
    'schemaVersion': schemaVersion,
    'searchTitle': title.trim().toLowerCase(),
  };

  factory FanWork.fromMap(Map<String, dynamic> map, {required String id}) {
    return FanWork(
      id: id,
      creatorId: map['creatorId'] as String? ?? '',
      creatorSnapshot: FanWorkCreatorSnapshot.fromMap(
        map['creatorSnapshot'] is Map
            ? Map<String, dynamic>.from(map['creatorSnapshot'] as Map)
            : null,
      ),
      type: fanWorkTypeFrom(map['type']),
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      cover: map['cover'] is Map
          ? FanWorkMedia.fromMap(Map<String, dynamic>.from(map['cover'] as Map))
          : null,
      content: FanWorkContent.fromMap(
        map['content'] is Map
            ? Map<String, dynamic>.from(map['content'] as Map)
            : null,
      ),
      tags: (map['tags'] as List<Object?>?)?.whereType<String>().toList() ??
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
      bookmarksCount: (map['bookmarksCount'] as num?)?.toInt() ?? 0,
      reportsCount: (map['reportsCount'] as num?)?.toInt() ?? 0,
      createdAt: _date(map['createdAt']),
      updatedAt: _date(map['updatedAt']),
      publishedAt: _date(map['publishedAt']),
      version: (map['version'] as num?)?.toInt() ?? 1,
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }

  FanWork copyWith({
    String? title,
    String? description,
    FanWorkType? type,
    FanWorkContent? content,
    FanWorkMedia? cover,
    bool clearCover = false,
    List<String>? tags,
    String? animeId,
    String? animeTitle,
    List<String>? characterIds,
    FanWorkStatus? status,
    FanWorkModerationStatus? moderationStatus,
    FanWorkVisibility? visibility,
  }) => FanWork(
    id: id,
    creatorId: creatorId,
    creatorSnapshot: creatorSnapshot,
    type: type ?? this.type,
    title: title ?? this.title,
    description: description ?? this.description,
    cover: clearCover ? null : cover ?? this.cover,
    content: content ?? this.content,
    tags: tags ?? this.tags,
    animeId: animeId ?? this.animeId,
    animeTitle: animeTitle ?? this.animeTitle,
    characterIds: characterIds ?? this.characterIds,
    visibility: visibility ?? this.visibility,
    status: status ?? this.status,
    moderationStatus: moderationStatus ?? this.moderationStatus,
    likesCount: likesCount,
    bookmarksCount: bookmarksCount,
    reportsCount: reportsCount,
    createdAt: createdAt,
    updatedAt: updatedAt,
    publishedAt: publishedAt,
    version: version,
    schemaVersion: schemaVersion,
  );
}

final class FanWorkDraft {
  const FanWorkDraft({
    this.workId,
    required this.type,
    this.title = '',
    this.description = '',
    this.tags = const <String>[],
    this.animeId = '',
    this.animeTitle = '',
    this.characterIds = const <String>[],
    this.body = '',
    this.name = '',
    this.personality = '',
    this.abilities = '',
    this.background = '',
    this.lore = '',
    this.chapters = const <FanWorkChapter>[],
    this.locations = const <FanWorkNamedEntry>[],
    this.factions = const <FanWorkNamedEntry>[],
    this.characters = const <FanWorkNamedEntry>[],
    this.pageIds = const <String>[],
    this.pageCaptions = const <String, String>{},
    this.imageIds = const <String>[],
    this.clearCover = false,
  });

  final String? workId;
  final FanWorkType type;
  final String title;
  final String description;
  final List<String> tags;
  final String animeId;
  final String animeTitle;
  final List<String> characterIds;
  final String body;
  final String name;
  final String personality;
  final String abilities;
  final String background;
  final String lore;
  final List<FanWorkChapter> chapters;
  final List<FanWorkNamedEntry> locations;
  final List<FanWorkNamedEntry> factions;
  final List<FanWorkNamedEntry> characters;
  final List<String> pageIds;
  final Map<String, String> pageCaptions;
  final List<String> imageIds;
  final bool clearCover;

  Map<String, dynamic> toCallableMap() => <String, dynamic>{
    if (workId != null && workId!.isNotEmpty) 'workId': workId,
    'type': type.name,
    'title': title,
    'description': description,
    'tags': tags,
    'animeId': animeId,
    'animeTitle': animeTitle,
    'characterIds': characterIds,
    'body': body,
    'name': name,
    'personality': personality,
    'abilities': abilities,
    'background': background,
    'lore': lore,
    'chapters': chapters.map((chapter) => chapter.toMap()).toList(),
    'locations': locations.map((entry) => entry.toMap()).toList(),
    'factions': factions.map((entry) => entry.toMap()).toList(),
    'characters': characters.map((entry) => entry.toMap()).toList(),
    'pageIds': pageIds,
    'pageCaptions': pageCaptions,
    'imageIds': imageIds,
    'clearCover': clearCover,
  };

  factory FanWorkDraft.fromWork(FanWork work) => FanWorkDraft(
    workId: work.id,
    type: work.type,
    title: work.title,
    description: work.description,
    tags: work.tags,
    animeId: work.animeId,
    animeTitle: work.animeTitle,
    characterIds: work.characterIds,
    body: work.content.body,
    name: work.content.name,
    personality: work.content.personality,
    abilities: work.content.abilities,
    background: work.content.background,
    lore: work.content.lore,
    chapters: work.content.orderedChapters,
    locations: work.content.locations,
    factions: work.content.factions,
    characters: work.content.characters,
    pageIds: work.content.orderedPages.map((page) => page.mediaId).toList(),
    pageCaptions: {
      for (final page in work.content.pages) page.mediaId: page.caption,
    },
    imageIds: work.content.images.map((image) => image.mediaId).toList(),
  );

  FanWorkDraft copyWith({
    String? workId,
    FanWorkType? type,
    String? title,
    String? description,
    List<String>? tags,
    String? animeId,
    String? animeTitle,
    List<String>? characterIds,
    String? body,
    String? name,
    String? personality,
    String? abilities,
    String? background,
    String? lore,
    List<FanWorkChapter>? chapters,
    List<FanWorkNamedEntry>? locations,
    List<FanWorkNamedEntry>? factions,
    List<FanWorkNamedEntry>? characters,
    List<String>? pageIds,
    Map<String, String>? pageCaptions,
    List<String>? imageIds,
    bool? clearCover,
  }) => FanWorkDraft(
    workId: workId ?? this.workId,
    type: type ?? this.type,
    title: title ?? this.title,
    description: description ?? this.description,
    tags: tags ?? this.tags,
    animeId: animeId ?? this.animeId,
    animeTitle: animeTitle ?? this.animeTitle,
    characterIds: characterIds ?? this.characterIds,
    body: body ?? this.body,
    name: name ?? this.name,
    personality: personality ?? this.personality,
    abilities: abilities ?? this.abilities,
    background: background ?? this.background,
    lore: lore ?? this.lore,
    chapters: chapters ?? this.chapters,
    locations: locations ?? this.locations,
    factions: factions ?? this.factions,
    characters: characters ?? this.characters,
    pageIds: pageIds ?? this.pageIds,
    pageCaptions: pageCaptions ?? this.pageCaptions,
    imageIds: imageIds ?? this.imageIds,
    clearCover: clearCover ?? this.clearCover,
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

final class FanWorkUploadTicket {
  const FanWorkUploadTicket({
    required this.workId,
    required this.mediaId,
    required this.path,
    required this.contentType,
  });

  final String workId;
  final String mediaId;
  final String path;
  final String contentType;
}

FanWorkType fanWorkTypeFrom(Object? raw) {
  return FanWorkType.values.firstWhere(
    (value) => value.name == raw,
    orElse: () => FanWorkType.other,
  );
}

List<FanWorkPage> _pages(Object? raw) {
  if (raw is! List) return const <FanWorkPage>[];
  return [
    for (var i = 0; i < raw.length; i++)
      if (raw[i] is Map)
        FanWorkPage.fromMap(Map<String, dynamic>.from(raw[i] as Map), index: i),
  ];
}

List<FanWorkMedia> _mediaList(Object? raw) {
  if (raw is! List) return const <FanWorkMedia>[];
  return [
    for (final item in raw)
      if (item is Map)
        FanWorkMedia.fromMap(Map<String, dynamic>.from(item)),
  ];
}

List<FanWorkChapter> _chapters(Object? raw) {
  if (raw is! List) return const <FanWorkChapter>[];
  return [
    for (var i = 0; i < raw.length; i++)
      if (raw[i] is Map)
        FanWorkChapter.fromMap(
          Map<String, dynamic>.from(raw[i] as Map),
          index: i,
        ),
  ];
}

List<FanWorkNamedEntry> _entries(Object? raw) {
  if (raw is! List) return const <FanWorkNamedEntry>[];
  return [
    for (final item in raw)
      if (item is Map)
        FanWorkNamedEntry.fromMap(Map<String, dynamic>.from(item)),
  ];
}

DateTime? _date(dynamic value) {
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  try {
    return value?.toDate() as DateTime?;
  } catch (_) {
    return null;
  }
}
