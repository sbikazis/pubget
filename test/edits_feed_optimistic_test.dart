import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/features/edits/models/edit_models.dart';
import 'package:pubget/features/edits/providers/edits_provider.dart';
import 'package:pubget/features/social/models/social_models.dart';
import 'package:pubget/features/social/providers/social_provider.dart';

import 'edits_test_support.dart';
import 'social_test_support.dart';

void main() {
  test('optimistic like flips UI before the awaited server call resolves', () async {
    final gate = Completer<Result<void>>();
    final repository = FakeEditsRepository();
    repository.likeHandler = (_) => gate.future;
    final provider = EditsProvider(repository: repository);
    addTearDown(provider.dispose);
    await provider.load();

    final pending = provider.like('e1', true);
    expect(provider.isLiked('e1'), isTrue);
    expect(provider.likesCountOf('e1'), 3);

    gate.complete(const Success<void>(null));
    await pending;
    expect(provider.isLiked('e1'), isTrue);
  });

  test('optimistic like rolls back when the server rejects', () async {
    final gate = Completer<Result<void>>();
    final repository = FakeEditsRepository();
    repository.likeHandler = (_) => gate.future;
    final provider = EditsProvider(repository: repository);
    addTearDown(provider.dispose);
    await provider.load();

    final pending = provider.like('e1', true);
    expect(provider.isLiked('e1'), isTrue);

    gate.complete(const FailureResult<void>(ValidationError('blocked')));
    await pending;
    expect(provider.isLiked('e1'), isFalse);
    expect(provider.likesCountOf('e1'), 2);
    expect(provider.lastActionFailure, isA<ValidationError>());
  });

  test('optimistic save rolls back on signal failure', () async {
    final repository = FakeEditsRepository();
    repository.signalFailure = const NetworkError('offline');
    final provider = EditsProvider(repository: repository);
    addTearDown(provider.dispose);
    await provider.load();

    await provider.save('e1', save: true);
    expect(provider.isSaved('e1'), isFalse);
    expect(provider.lastActionFailure, isNotNull);
  });

  test('giveRespect updates snapshot immediately and reports fan crossover', () async {
    final repository = FakeSocialRepository();
    final provider = SocialProvider(repository: repository);
    addTearDown(provider.dispose);
    await provider.load('fan-1');

    final result = await provider.giveRespect(toUserId: 'creator-9', value: 5);
    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull, isTrue);
    expect(
      provider.snapshot.givenRespect.any(
        (item) =>
            item.toUserId == 'creator-9' &&
            item.value >= SocialSnapshot.fanThreshold,
      ),
      isTrue,
    );
  });

  test('skipBroken hides unplayable clips from the feed list', () async {
    final repository = FakeEditsRepository(
      feed: <Edit>[testEdit(id: 'bad'), testEdit(id: 'good')],
    );
    final provider = EditsProvider(repository: repository);
    addTearDown(provider.dispose);
    await provider.load();
    expect(provider.items.length, 2);
    provider.skipBroken('bad');
    expect(provider.items.map((e) => e.id), ['good']);
  });
}
