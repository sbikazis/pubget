import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/features/edits/providers/edits_provider.dart';

import 'edits_test_support.dart';

/// Axis 15 §15 — muting a Reels creator.
///
/// The mute is server truth (`reelMutes/{viewerId}/creators`); these tests pin
/// the immediate client behaviour on top of it: the creator's loaded Reels leave
/// the feed at once, and a rejected write re-reads the feed instead of leaving a
/// lie on screen.
void main() {
  EditsProvider providerWith(FakeEditsRepository repository) {
    final provider = EditsProvider(repository: repository);
    addTearDown(provider.dispose);
    return provider;
  }

  test('muting removes that creator from the loaded feed', () async {
    final repository = FakeEditsRepository(
      feed: [
        testEdit(id: 'e1', creatorId: 'alice'),
        testEdit(id: 'e2', creatorId: 'bob'),
      ],
    );
    final provider = providerWith(repository);
    await provider.load();
    expect(provider.items.length, 2);

    final result = await provider.muteCreator('bob', mute: true);

    expect(result.isSuccess, isTrue);
    expect(
      provider.items.map((e) => e.id),
      <String>['e1'],
      reason: 'muted creator must leave the feed immediately',
    );
    expect(provider.isMuted('bob'), isTrue);
    expect(repository.muteCalls.single['creatorId'], 'bob');
    expect(repository.muteCalls.single['mute'], true);
  });

  test('muting the same creator twice is idempotent', () async {
    final repository = FakeEditsRepository(feed: [testEdit(id: 'e1', creatorId: 'bob')]);
    final provider = providerWith(repository);
    await provider.load();

    await provider.muteCreator('bob', mute: true);
    await provider.muteCreator('bob', mute: true);

    expect(repository.muteCalls.length, 1, reason: 'the second call must be a no-op');
  });

  test('a failed mute does not report success and re-reads the feed', () async {
    final repository = FakeEditsRepository(
      feed: [testEdit(id: 'e1', creatorId: 'bob')],
    )..muteFailure = NetworkError();
    final provider = providerWith(repository);
    await provider.load();

    final result = await provider.muteCreator('bob', mute: true);

    expect(result.isSuccess, isFalse);
    expect(
      provider.isMuted('bob'),
      isFalse,
      reason: 'a rejected mute must not leave the creator marked as muted',
    );
    expect(provider.lastActionFailure, isNotNull);
  });

  test('unmuting clears the local flag and calls the server', () async {
    final repository = FakeEditsRepository(feed: [testEdit(id: 'e1', creatorId: 'bob')]);
    final provider = providerWith(repository);
    await provider.load();
    await provider.muteCreator('bob', mute: true);

    final result = await provider.muteCreator('bob', mute: false);

    expect(result.isSuccess, isTrue);
    expect(provider.isMuted('bob'), isFalse);
    expect(repository.muteCalls.last['mute'], false);
  });

  test('muting yourself is refused by the client as a no-op', () async {
    // The server also rejects self-mute; the client must not send it.
    final repository = FakeEditsRepository(feed: [testEdit(id: 'e1')]);
    final provider = providerWith(repository);
    await provider.load();

    await provider.muteCreator('', mute: true);

    expect(repository.muteCalls, isEmpty);
  });

  test('muting is scoped to the named creator only', () async {
    final repository = FakeEditsRepository(
      feed: [
        testEdit(id: 'e1', creatorId: 'bob'),
        testEdit(id: 'e2', creatorId: 'carol'),
        testEdit(id: 'e3', creatorId: 'bob'),
        testEdit(id: 'e4', creatorId: 'alice'),
      ],
    );
    final provider = providerWith(repository);
    await provider.load();

    await provider.muteCreator('bob', mute: true);

    expect(
      provider.items.map((e) => e.id).toSet(),
      <String>{'e2', 'e4'},
      reason: 'every Reel by the muted creator goes, others stay',
    );
  });
}