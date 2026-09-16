import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/fan_works/models/fan_work_lifecycle.dart';
import 'package:pubget/features/fan_works/models/fan_work_models.dart';

void main() {
  test('FanWork round-trips through toMap and fromMap', () {
    final original = FanWork(
      id: 'w1',
      creatorId: 'alice',
      creatorSnapshot: const FanWorkCreatorSnapshot(username: 'Alice'),
      type: FanWorkType.manga,
      title: 'Blade notes',
      description: 'A short manga',
      cover: const FanWorkMedia(mediaId: 'c1', path: 'fan_works/alice/w1/c1.jpg'),
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

  test('aiCharacter is a distinct typed value', () {
    final work = FanWork.fromMap(const <String, dynamic>{
      'type': 'aiCharacter',
      'title': 'Kiro',
    }, id: 'ai-1');
    expect(work.type, FanWorkType.aiCharacter);
    expect(work.isAiAssisted, isTrue);
    expect(FanWorkTypeCatalog.label(work.type), contains('AI-assisted'));
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

  test('publish validation covers each type without treating other as a bypass', () {
    expect(
      FanWorkLifecycle.publishError(
        FanWork(
          id: 'd',
          creatorId: 'alice',
          type: FanWorkType.drawing,
          title: 'Sketch',
          description: '',
          content: const FanWorkContent(),
          status: FanWorkStatus.draft,
          moderationStatus: FanWorkModerationStatus.pending,
          visibility: FanWorkVisibility.unpublished,
          createdAt: DateTime.utc(2026, 9, 1),
          updatedAt: DateTime.utc(2026, 9, 1),
        ),
      ),
      contains('drawing'),
    );
    expect(
      FanWorkLifecycle.publishError(
        FanWork(
          id: 'o',
          creatorId: 'alice',
          type: FanWorkType.other,
          title: 'Notes',
          description: '',
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
  });

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
}
