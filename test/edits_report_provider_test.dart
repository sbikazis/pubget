import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/features/edits/providers/edits_provider.dart';

import 'edits_test_support.dart';

/// Axis 15 §15.18 — reporting a Reel and the distinct "not interested" taste
/// signal.
///
/// A report is a moderation action: it sends a validated category through the
/// `reportEdit` callable and must never be conflated with the private negative
/// signal used to soften recommendations.
void main() {
  EditsProvider providerWith(FakeEditsRepository repository) {
    final provider = EditsProvider(repository: repository);
    addTearDown(provider.dispose);
    return provider;
  }

  test('report sends a categorized moderation report to the server', () async {
    final repository = FakeEditsRepository(feed: [testEdit(id: 'e1')]);
    final provider = providerWith(repository);

    final result = await provider.report(
      'e1',
      category: 'harassment',
      detail: 'keeps following viewers around',
    );

    expect(result.isSuccess, isTrue);
    expect(repository.reportCalls.length, 1);
    expect(repository.reportCalls.single['editId'], 'e1');
    expect(repository.reportCalls.single['category'], 'harassment');
    expect(repository.reportCalls.single['detail'], 'keeps following viewers around');
  });

  test('a rejected report is reported as a failure, not swallowed', () async {
    final repository = FakeEditsRepository(
      feed: [testEdit(id: 'e1')],
    )..reportFailure = NetworkError();
    final provider = providerWith(repository);

    final result = await provider.report('e1', category: 'spam');

    expect(result.isSuccess, isFalse);
    expect(repository.reportCalls.length, 1);
  });

  test('notInterested is a private negative signal, not a moderation report',
      () async {
    final repository = FakeEditsRepository(
      feed: [testEdit(id: 'e1'), testEdit(id: 'e2')],
    );
    final provider = providerWith(repository);
    await provider.load();
    expect(provider.items.length, 2);

    final result = await provider.notInterested('e1');

    expect(result.isSuccess, isTrue);
    expect(
      repository.reportCalls,
      isEmpty,
      reason: 'a taste preference must not open a moderation ticket',
    );
    expect(
      provider.items.map((e) => e.id),
      <String>['e2'],
      reason: 'the Reel is hidden locally',
    );
  });

  test('notInterested never hides the whole feed', () async {
    final repository = FakeEditsRepository(
      feed: [testEdit(id: 'e1')],
    );
    final provider = providerWith(repository);
    await provider.load();

    await provider.notInterested('e1');

    expect(provider.items, isEmpty);
  });
}