import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/core/loading/loading_state.dart';
import 'package:pubget/features/edits/models/edit_models.dart';
import 'package:pubget/features/edits/providers/edits_provider.dart';

import 'edits_test_support.dart';

/// Axis 15 §15 — per-item rebuild scoping.
///
/// `_EditFeedPageState.build` used `context.watch<EditsProvider>()`, so a like on
/// one Reel rebuilt the whole `PageView` and every mounted cell. The action rail
/// already had correct `context.select` scoping, but it could not help because
/// the parent had already marked the subtree dirty.
///
/// The fix is targeted `select`s at the root, which only works if the provider's
/// `items` getter returns a *stable identity* while interaction state changes.
/// These tests pin both halves: the identity contract, and that selecting on it
/// does not report interaction-only changes as feed changes.

void main() {
  test('items keeps a stable identity while only interaction state changes', () async {
    final provider = EditsProvider(repository: FakeEditsRepository());
    await provider.load();

    final before = provider.items;
    expect(before, isNotEmpty);

    // A like changes interaction state only.
    await provider.like(before.first.id, true);

    // The cached snapshot must be the SAME instance, so a `context.select` on
    // `items` does not treat a like as a feed change.
    expect(
      identical(provider.items, before),
      isTrue,
      reason: 'a like must not invalidate the items snapshot',
    );

    // The like itself must still be observable.
    expect(provider.isLiked(before.first.id), isTrue);
  });

  test('items gets a new identity when the feed actually changes', () async {
    final provider = EditsProvider(repository: FakeEditsRepository());
    await provider.load();
    final before = provider.items;
    expect(before, isNotEmpty);

    // skipBroken removes a row — the feed genuinely changed.
    provider.skipBroken(before.first.id);
    expect(identical(provider.items, before), isFalse);
    expect(provider.items.length, before.length - 1);
  });

  test('a select on items ignores a like but fires on a skip', () async {
    final provider = EditsProvider(repository: FakeEditsRepository());
    await provider.load();

    List<Edit>? observed;
    void listener() => observed = provider.items;
    provider.addListener(listener);

    // Liking must not change what an `items` listener sees.
    final snapshotBefore = provider.items;
    await provider.like(provider.items.first.id, true);
    expect(
      identical(observed, snapshotBefore),
      isTrue,
      reason: 'items identity must survive a like',
    );

    provider.skipBroken(provider.items.first.id);
    expect(identical(observed, snapshotBefore), isFalse);

    provider.removeListener(listener);
  });

  test('state and feedType still drive the page-level selects', () async {
    final provider = EditsProvider(repository: FakeEditsRepository());
    await provider.load();
    expect(provider.state, LoadingState.loaded);
    expect(provider.feedType, FeedType.forYou);

    provider.setFeedType(FeedType.trending);
    await provider.load();
    expect(provider.feedType, FeedType.trending);
    expect(provider.state, LoadingState.loaded);
  });

  testWidgets('a like does not rebuild sibling feed cells', (tester) async {
    final provider = EditsProvider(
      repository: FakeEditsRepository(
        feed: [testEdit(id: 'e1'), testEdit(id: 'e2')],
      ),
    );
    await provider.load();
    expect(provider.items.length, 2);

    final builds = <String, int>{};

    Widget cell(Edit edit) {
      return ChangeNotifierProvider<EditsProvider>.value(
        value: provider,
        child: Builder(
          builder: (context) {
            // Mirror the real rail: a per-item select, not a root watch.
            final liked = context.select<EditsProvider, bool>(
              (p) => p.isLiked(edit.id),
            );
            builds[edit.id] = (builds[edit.id] ?? 0) + 1;
            return SizedBox(
              key: ValueKey('cell-${edit.id}-$liked'),
              width: 10,
              height: 10,
            );
          },
        ),
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [for (final edit in provider.items) cell(edit)],
          ),
        ),
      ),
    );

    final target = provider.items.first.id;
    final other = provider.items[1].id;
    final otherBuildsBefore = builds[other] ?? 0;

    await provider.like(target, true);
    await tester.pump();

    // The liked cell rebuilt...
    expect(
      (builds[target] ?? 0),
      greaterThan(1),
      reason: 'the interacted cell must rebuild',
    );
    // ...and its sibling did not.
    expect(
      builds[other] ?? 0,
      otherBuildsBefore,
      reason: 'a like on one Reel must not rebuild sibling cells',
    );
  });
}
