import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/edits/models/edit_models.dart';

/// Axis 15 §15 — comment paging cursors.
///
/// The list query orders by one field, but Firestore always appends `__name__`
/// as an implicit final tiebreaker. A cursor built from the sort key alone
/// therefore means "resume after *every* comment that ties with this one", which
/// made tied comments vanish from the list and made paging skip rows.
void main() {
  EditComment comment({
    String id = 'c1',
    int likes = 3,
    DateTime? createdAt,
  }) {
    return EditComment(
      id: id,
      authorId: 'bob',
      text: 'Insane timing',
      likesCount: likes,
      createdAt: createdAt,
    );
  }

  test('top cursor carries likesCount and the document id', () {
    final values = editCommentCursor(
      comment(id: 'c9', likes: 7),
      EditCommentSort.top,
    );
    expect(values, <Object>[7, 'c9']);
  });

  test('newest cursor carries the timestamp and the document id', () {
    final at = DateTime.utc(2026, 8, 2, 10, 30);
    final values = editCommentCursor(
      comment(id: 'c4', createdAt: at),
      EditCommentSort.newest,
    );
    expect(values, <Object>[Timestamp.fromDate(at), 'c4']);
  });

  test('two comments tied on likesCount produce distinct cursors', () {
    // This is the exact scenario that silently dropped rows: identical
    // likesCount, different ids.
    final a = editCommentCursor(comment(id: 'c1', likes: 5), EditCommentSort.top);
    final b = editCommentCursor(comment(id: 'c2', likes: 5), EditCommentSort.top);
    expect(a, isNot(equals(b)));
    expect(a!.length, 2);
    expect(b!.length, 2);
  });

  test('two comments written in the same millisecond produce distinct cursors', () {
    final at = DateTime.utc(2026, 8, 2, 10, 30, 15);
    final a = editCommentCursor(
      comment(id: 'c1', createdAt: at),
      EditCommentSort.newest,
    );
    final b = editCommentCursor(
      comment(id: 'c2', createdAt: at),
      EditCommentSort.newest,
    );
    expect(a, isNot(equals(b)));
  });

  test('a newest comment without a timestamp yields no cursor', () {
    // Returning null makes the caller omit `startAfter`, which restarts the list
    // -- safe, because a comment with no timestamp cannot be ordered at all.
    expect(
      editCommentCursor(comment(id: 'c1'), EditCommentSort.newest),
      isNull,
    );
  });

  test('a top cursor works even without a timestamp', () {
    expect(
      editCommentCursor(comment(id: 'c1', likes: 2), EditCommentSort.top),
      <Object>[2, 'c1'],
    );
  });

  test('local timestamps are normalised to UTC so the cursor matches the index', () {
    // The server writes UTC; a device in another zone must still produce the
    // same cursor value for the same instant.
    final utc = DateTime.utc(2026, 8, 2, 10, 30);
    final localEquivalent = utc.toLocal();
    expect(
      editCommentCursor(comment(id: 'c1', createdAt: localEquivalent), EditCommentSort.newest),
      editCommentCursor(comment(id: 'c1', createdAt: utc), EditCommentSort.newest),
    );
  });
}