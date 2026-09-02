import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/analytics/analytics.dart';
import 'package:pubget/core/links/pubget_links.dart';
import 'package:pubget/features/anime/widgets/anime_widgets.dart';
import 'package:pubget/features/events/widgets/event_widgets.dart';
import 'package:pubget/features/fan_works/widgets/fan_work_widgets.dart';
import 'package:pubget/features/games/widgets/game_widgets.dart';

void main() {
  late _RecordingAnalytics analytics;

  setUp(() {
    analytics = _RecordingAnalytics();
    PubgetLinks.analytics = analytics;
  });

  tearDown(() {
    PubgetLinks.analytics = null;
    PubgetLinks.debugNativeShare = null;
  });

  test('canonical URLs are deterministic and share one host', () {
    expect(EventLinks.canonical('abc 1'), PubgetLinks.event('abc 1'));
    expect(FanWorkLinks.canonical('w 1'), PubgetLinks.fanWork('w 1'));
    expect(GameLinks.canonical('g1'), 'https://pubget-aaf27.web.app/game/g1');
    expect(AnimeLinks.canonical('21'), 'https://pubget-aaf27.web.app/anime/21');
    expect(PubgetLinks.group('grp'), 'https://pubget-aaf27.web.app/group/grp');
    expect(
      PubgetLinks.profile('user'),
      'https://pubget-aaf27.web.app/profile/user',
    );
  });

  test('missing or blank entity ids are not shareable', () {
    expect(PubgetLinks.event('  '), isEmpty);
    expect(PubgetLinks.fanWork(''), isEmpty);
    expect(GameLinks.canonical(''), isEmpty);
  });

  testWidgets('native share and copy use the same canonical URL', (
    tester,
  ) async {
    String? shared;
    PubgetLinks.debugNativeShare = (text, subject) async {
      shared = text;
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Column(
            children: <Widget>[
              TextButton(
                onPressed: () => EventLinks.share(context, 'e1', title: 'Quiz'),
                child: const Text('Share'),
              ),
              TextButton(
                onPressed: () => EventLinks.copy(context, 'e1'),
                child: const Text('Copy'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(shared, 'https://pubget-aaf27.web.app/event/e1');
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(analytics.names, containsAll(<String>['share_started', 'share_completed', 'copy_link']));
    expect(
      analytics.events.every((event) => !event.toString().contains('e1')),
      isTrue,
    );
  });

  testWidgets('blank ids do not start a share', (tester) async {
    var called = false;
    PubgetLinks.debugNativeShare = (text, subject) async {
      called = true;
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => PubgetLinks.share(context, url: ''),
            child: const Text('Share'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(called, isFalse);
    expect(analytics.names, isEmpty);
  });
}

final class _RecordingAnalytics implements Analytics {
  final List<String> names = <String>[];
  final List<Map<String, Object?>> events = <Map<String, Object?>>[];

  @override
  void logEvent(String name, {Map<String, Object?> parameters = const {}}) {
    names.add(name);
    events.add(parameters);
  }
}
