import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/fan_works/models/fan_work_lifecycle.dart';
import 'package:pubget/features/fan_works/models/fan_work_models.dart';
import 'package:pubget/features/fan_works/models/fan_work_taxonomy.dart';

/// Locks the client validation rules.
///
/// Every expectation here mirrors a case in
/// `functions/test/fanWorksDomain.test.js`, because the two run against the
/// same wording: the server rejects, this copy previews the rejection. If one
/// side changes a limit and the other does not, a creator sees a button that
/// fails after they press it.
void main() {
  final now = DateTime.utc(2026, 1, 1);
  FanWork work({
    FanWorkType type = FanWorkType.manga,
    String title = 'A Long Enough Title',
    String description = '',
    String categoryId = 'action',
    FanWorkContent? content,
    String creatorNote = '',
  }) => FanWork(
    id: 'w1',
    creatorId: 'u1',
    type: type,
    title: title,
    description: description,
    categoryId: categoryId,
    content: content ?? const FanWorkContent(),
    creatorNote: creatorNote,
    status: FanWorkStatus.draft,
    moderationStatus: FanWorkModerationStatus.approved,
    visibility: FanWorkVisibility.public,
    createdAt: now,
    updatedAt: now,
  );

  FanWorkContent document({int pageCount = 10}) => FanWorkContent(
    document: FanWorkDocument(
      mediaId: 'm1',
      path: 'fanWorks/w1/media/n_m1.pdf',
      contentType: 'application/pdf',
      pageCount: pageCount,
      sizeBytes: 1024,
    ),
  );

  group('title', () {
    test('rejects too short and too long', () {
      expect(
        FanWorkLifecycle.publishError(work(title: 'ab')),
        FanWorkLifecycle.publishMissingTitle,
      );
      expect(
        FanWorkLifecycle.publishError(
          work(title: 'a' * (FanWorkLifecycle.titleMax + 1)),
        ),
        FanWorkLifecycle.publishMissingTitle,
      );
    });

    test('accepts the existing 3..80 boundary', () {
      final published = work(title: 'abc', content: document());
      expect(FanWorkLifecycle.publishError(published), isNull);
    });

    test('trims before measuring', () {
      final padded = work(title: '   abc   ', content: document());
      expect(FanWorkLifecycle.publishError(padded), isNull);
    });
  });

  group('category', () {
    test('manga and story require a category from the closed list', () {
      expect(
        FanWorkLifecycle.publishError(
          work(content: document(), categoryId: ''),
        ),
        FanWorkLifecycle.publishMissingCategory,
      );
      expect(
        FanWorkLifecycle.publishError(
          work(content: document(), categoryId: 'made-up'),
        ),
        FanWorkLifecycle.publishInvalidCategory,
      );
    });

    test('a cross-type id is invalid, not merely unknown', () {
      expect(
        FanWorkLifecycle.publishError(
          work(content: document(), categoryId: 'portrait'),
        ),
        FanWorkLifecycle.publishInvalidCategory,
      );
    });

    test('drawing accepts an art category', () {
      final drawing = work(
        type: FanWorkType.drawing,
        categoryId: 'fanArt',
        content: const FanWorkContent(
          artwork: FanWorkMedia(mediaId: 'm2', path: 'fanWorks/w1/media/a.png'),
        ),
      );
      expect(FanWorkLifecycle.publishError(drawing), isNull);
    });
  });

  group('per-type required content', () {
    test('manga and story require their PDF', () {
      expect(
        FanWorkLifecycle.publishError(work(type: FanWorkType.manga)),
        FanWorkLifecycle.publishMangaMissingPdf,
      );
      expect(
        FanWorkLifecycle.publishError(work(type: FanWorkType.story)),
        FanWorkLifecycle.publishStoryMissingPdf,
      );
    });

    test('character requires a portrait and a real story', () {
      expect(
        FanWorkLifecycle.publishError(
          work(
            type: FanWorkType.character,
            categoryId: 'human',
            description: 'A character who is described properly here.',
          ),
        ),
        FanWorkLifecycle.publishCharacterMissingPortrait,
      );
      expect(
        FanWorkLifecycle.publishError(
          work(
            type: FanWorkType.character,
            categoryId: 'human',
            description: 'too short',
            content: const FanWorkContent(
              portrait: FanWorkMedia(
                mediaId: 'm3',
                path: 'fanWorks/w1/media/p.png',
              ),
            ),
          ),
        ),
        FanWorkLifecycle.publishCharacterShortStory,
      );
    });

    test('a complete character publishes', () {
      final character = work(
        type: FanWorkType.character,
        categoryId: 'demon',
        description: 'A demon who guards the northern gate of the old city.',
        content: const FanWorkContent(
          portrait: FanWorkMedia(
            mediaId: 'm3',
            path: 'fanWorks/w1/media/p.png',
          ),
        ),
      );
      expect(FanWorkLifecycle.publishError(character), isNull);
    });

    test('drawing accepts the artwork slot', () {
      final drawing = work(
        type: FanWorkType.drawing,
        categoryId: 'chibi',
        content: const FanWorkContent(
          artwork: FanWorkMedia(mediaId: 'm2', path: 'fanWorks/w1/media/a.png'),
        ),
      );
      expect(FanWorkLifecycle.publishError(drawing), isNull);
      expect(
        FanWorkLifecycle.publishError(
          work(type: FanWorkType.drawing, categoryId: 'chibi'),
        ),
        FanWorkLifecycle.publishDrawingMissingImage,
      );
    });

    test('legacy types stay readable and still validate their old shape', () {
      final world = work(
        type: FanWorkType.worldbuilding,
        categoryId: '',
        content: const FanWorkContent(lore: 'A continent of floating cities.'),
      );
      expect(FanWorkLifecycle.publishError(world), isNull);
    });
  });

  group('upload guard', () {
    test('only a pdf may fill the document slot', () {
      expect(
        FanWorkLifecycle.uploadError(
          type: FanWorkType.manga,
          role: FanWorkMediaRole.document,
          contentType: 'application/pdf',
          sizeBytes: 2048,
        ),
        isNull,
      );
      expect(
        FanWorkLifecycle.uploadError(
          type: FanWorkType.manga,
          role: FanWorkMediaRole.document,
          contentType: 'image/png',
          sizeBytes: 2048,
        ),
        isNotNull,
      );
    });

    test('an image may not fill the document slot', () {
      expect(
        FanWorkLifecycle.uploadError(
          type: FanWorkType.story,
          role: FanWorkMediaRole.document,
          contentType: 'image/jpeg',
          sizeBytes: 2048,
        ),
        isNotNull,
      );
    });

    test('a drawing has no document slot at all', () {
      expect(
        FanWorkLifecycle.uploadError(
          type: FanWorkType.drawing,
          role: FanWorkMediaRole.document,
          contentType: 'application/pdf',
          sizeBytes: 2048,
        ),
        isNotNull,
      );
    });

    test('size ceilings are enforced at 50 MB and 12 MB', () {
      expect(
        FanWorkLifecycle.uploadError(
          type: FanWorkType.manga,
          role: FanWorkMediaRole.document,
          contentType: 'application/pdf',
          sizeBytes: FanWorkLifecycle.maxDocumentBytes + 1,
        ),
        isNotNull,
      );
      expect(
        FanWorkLifecycle.uploadError(
          type: FanWorkType.manga,
          role: FanWorkMediaRole.cover,
          contentType: 'image/png',
          sizeBytes: FanWorkLifecycle.maxImageBytes + 1,
        ),
        isNotNull,
      );
    });

    test('a zero byte file is rejected before any network call', () {
      expect(
        FanWorkLifecycle.uploadError(
          type: FanWorkType.manga,
          role: FanWorkMediaRole.cover,
          contentType: 'image/png',
          sizeBytes: 0,
        ),
        isNotNull,
      );
    });

    test('an unsupported mime is rejected', () {
      expect(
        FanWorkLifecycle.uploadError(
          type: FanWorkType.manga,
          role: FanWorkMediaRole.cover,
          contentType: 'image/svg+xml',
          sizeBytes: 1024,
        ),
        isNotNull,
      );
    });
  });

  group('tags', () {
    test('normalizes, dedupes, and caps', () {
      expect(
        FanWorkLifecycle.normalizeTags([
          '  Action ',
          '#action',
          'Sci-Fi',
          'a',
          '',
        ]),
        <String>['action', 'scifi'],
      );
      expect(
        FanWorkLifecycle.normalizeTags(
          List.generate(20, (i) => 'tag$i'),
        ).length,
        FanWorkLifecycle.maxTags,
      );
    });
  });

  group('cast', () {
    test('manga and story allow a cast, drawing does not', () {
      expect(
        FanWorkLifecycle.acceptsRole(
          FanWorkType.manga,
          FanWorkMediaRole.characterPortrait,
        ),
        isTrue,
      );
      expect(
        FanWorkLifecycle.acceptsRole(
          FanWorkType.drawing,
          FanWorkMediaRole.characterPortrait,
        ),
        isFalse,
      );
    });
  });

  group('lifecycle state', () {
    test('only drafts can be edited, published, or deleted', () {
      expect(FanWorkLifecycle.canEdit(FanWorkStatus.draft), isTrue);
      expect(FanWorkLifecycle.canEdit(FanWorkStatus.published), isFalse);
      expect(FanWorkLifecycle.canPublish(FanWorkStatus.draft), isTrue);
      expect(FanWorkLifecycle.canDelete(FanWorkStatus.published), isFalse);
      expect(FanWorkLifecycle.canArchive(FanWorkStatus.published), isTrue);
      expect(FanWorkLifecycle.canArchive(FanWorkStatus.draft), isFalse);
    });
  });

  group('taxonomy wiring', () {
    test('every creatable type supports a category', () {
      for (final type in FanWorkType.creatable) {
        expect(
          FanWorkCategories.supportsCategory(type),
          isTrue,
          reason: type.name,
        );
      }
    });
  });
}
