import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/fan_works/models/fan_work_lifecycle.dart';
import 'package:pubget/features/fan_works/models/fan_work_models.dart';
import 'package:pubget/features/fan_works/models/fan_work_taxonomy.dart';

void main() {
  test('FanWork round-trips through toMap and fromMap', () {
    final original = FanWork(
      id: 'w1',
      creatorId: 'alice',
      creatorSnapshot: const FanWorkCreatorSnapshot(username: 'Alice'),
      type: FanWorkType.manga,
      title: 'Blade notes',
      description: 'A short manga',
      cover: const FanWorkMedia(
        mediaId: 'c1',
        path: 'fan_works/alice/w1/c1.jpg',
      ),
      content: const FanWorkContent(
        pages: <FanWorkPage>[
          FanWorkPage(
            mediaId: 'p1',
            path: 'fan_works/alice/w1/p1.jpg',
            index: 0,
            caption: 'Splash',
          ),
          FanWorkPage(
            mediaId: 'p2',
            path: 'fan_works/alice/w1/p2.jpg',
            index: 1,
          ),
        ],
      ),
      tags: const <String>['demonslayer'],
      animeId: '38000',
      animeTitle: 'Demon Slayer',
      status: FanWorkStatus.published,
      moderationStatus: FanWorkModerationStatus.approved,
      visibility: FanWorkVisibility.public,
      likesCount: 3,
      commentsCount: 2,
      createdAt: DateTime.utc(2026, 9, 1),
      updatedAt: DateTime.utc(2026, 9, 1),
      publishedAt: DateTime.utc(2026, 9, 1, 12),
      version: 2,
      schemaVersion: 1,
    );

    final restored = FanWork.fromMap(original.toMap(), id: original.id);
    expect(restored.id, original.id);
    expect(restored.type, FanWorkType.manga);
    expect(restored.content.orderedPages, hasLength(2));
    expect(restored.content.orderedPages.first.caption, 'Splash');
    expect(restored.isPubliclyListed, isTrue);
    expect(restored.schemaVersion, 1);
    expect(restored.commentsCount, 2);
  });

  test('invalid maps fall back to safe defaults', () {
    final work = FanWork.fromMap(const <String, dynamic>{}, id: 'missing');
    expect(work.type, FanWorkType.other);
    expect(work.status, FanWorkStatus.draft);
    expect(work.moderationStatus, FanWorkModerationStatus.pending);
    expect(work.title, isEmpty);
    expect(work.content.pages, isEmpty);
  });

  test('aiCharacter reads as a character with an explicit AI origin', () {
    final work = FanWork.fromMap(const <String, dynamic>{
      'type': 'aiCharacter',
      'title': 'Kiro',
    }, id: 'ai-1');
    // The type collapses into `character`; the provenance moves to `origin` so
    // nothing in the codebase has to handle a fifth type.
    expect(work.type, FanWorkType.character);
    expect(work.origin, FanWorkOrigin.aiGenerated);
    expect(work.isAiAssisted, isTrue);
  });

  test('an explicit origin survives a plain character', () {
    final work = FanWork.fromMap(const <String, dynamic>{
      'type': 'character',
      'origin': 'aiGenerated',
      'title': 'Kiro',
    }, id: 'c-1');
    expect(work.type, FanWorkType.character);
    expect(work.origin, FanWorkOrigin.aiGenerated);
    expect(work.isAiAssisted, isTrue);
  });

  test('tags are normalized and de-duplicated', () {
    expect(
      FanWorkLifecycle.normalizeTags(const <String>[
        '#DemonSlayer',
        ' demonslayer ',
        'Tanjiro',
        'x',
      ]),
      <String>['demonslayer', 'tanjiro'],
    );
  });

  test(
    'publish validation covers each type without treating other as a bypass',
    () {
      expect(
        FanWorkLifecycle.publishError(
          FanWork(
            id: 'd',
            creatorId: 'alice',
            type: FanWorkType.drawing,
            title: 'Sketch',
            description: '',
            categoryId: 'digitalArt',
            content: const FanWorkContent(),
            status: FanWorkStatus.draft,
            moderationStatus: FanWorkModerationStatus.pending,
            visibility: FanWorkVisibility.unpublished,
            createdAt: DateTime.utc(2026, 9, 1),
            updatedAt: DateTime.utc(2026, 9, 1),
          ),
        ),
        FanWorkLifecycle.publishDrawingMissingImage,
      );
      // A creatable type with no category is not publishable, and a category
      // from another type's closed list is rejected too.
      expect(
        FanWorkLifecycle.publishError(
          FanWork(
            id: 'd0',
            creatorId: 'alice',
            type: FanWorkType.drawing,
            title: 'Sketch',
            description: '',
            categoryId: '',
            content: const FanWorkContent(),
            status: FanWorkStatus.draft,
            moderationStatus: FanWorkModerationStatus.pending,
            visibility: FanWorkVisibility.unpublished,
            createdAt: DateTime.utc(2026, 9, 1),
            updatedAt: DateTime.utc(2026, 9, 1),
          ),
        ),
        FanWorkLifecycle.publishMissingCategory,
      );
      expect(
        FanWorkLifecycle.publishError(
          FanWork(
            id: 'd1',
            creatorId: 'alice',
            type: FanWorkType.drawing,
            title: 'Sketch',
            description: '',
            categoryId: 'fantasy',
            content: const FanWorkContent(),
            status: FanWorkStatus.draft,
            moderationStatus: FanWorkModerationStatus.pending,
            visibility: FanWorkVisibility.unpublished,
            createdAt: DateTime.utc(2026, 9, 1),
            updatedAt: DateTime.utc(2026, 9, 1),
          ),
        ),
        FanWorkLifecycle.publishInvalidCategory,
      );
      expect(
        FanWorkLifecycle.publishError(
          FanWork(
            id: 'o',
            creatorId: 'alice',
            type: FanWorkType.other,
            title: 'Notes',
            description: '',
            categoryId: '',
            content: const FanWorkContent(),
            status: FanWorkStatus.draft,
            moderationStatus: FanWorkModerationStatus.pending,
            visibility: FanWorkVisibility.unpublished,
            createdAt: DateTime.utc(2026, 9, 1),
            updatedAt: DateTime.utc(2026, 9, 1),
          ),
        ),
        isNotNull,
      );
    },
  );

  test('FanWorkPreview is a lightweight search/home contract', () {
    final preview = FanWorkPreview.fromMap(const <String, dynamic>{
      'type': 'story',
      'title': 'Lore',
      'creatorId': 'alice',
      'creatorSnapshot': <String, dynamic>{'username': 'Alice'},
      'cover': <String, dynamic>{'path': 'fan_works/alice/w1/c.jpg'},
    }, id: 'w1');
    expect(preview.id, 'w1');
    expect(preview.creatorName, 'Alice');
    expect(preview.coverPath, 'fan_works/alice/w1/c.jpg');
  });

  test('a ticket says which upload protocol its URL speaks', () {
    FanWorkUploadTicket ticket(FanWorkMediaRole role) => FanWorkUploadTicket(
      workId: 'w1',
      mediaId: 'm1',
      path: 'fan_works/alice/w1/m1.jpg',
      contentType: 'image/jpeg',
      role: role,
      uploadUrl: 'https://storage.test/upload/session/1',
      maxBytes: 12 * 1024 * 1024,
      expiresAt: DateTime.utc(2026, 9, 1, 12, 15),
    );

    // Only a PDF is opened as a resumable session; every image URL is a
    // one-shot signed PUT that fails unless the request matches its signature.
    expect(ticket(FanWorkMediaRole.document).isResumableSession, isTrue);
    expect(ticket(FanWorkMediaRole.artwork).isResumableSession, isFalse);
    expect(
      ticket(FanWorkMediaRole.characterPortrait).isResumableSession,
      isFalse,
    );
    expect(ticket(FanWorkMediaRole.cover).isResumableSession, isFalse);
  });
}
