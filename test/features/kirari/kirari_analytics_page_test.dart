import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/features/kirari/data/kirari_repository.dart';
import 'package:pubget/features/kirari/screens/kirari_analytics_page.dart';

KirariAnalytics _analytics({int reelCount = 1}) => KirariAnalytics.fromMap({
  'overview': <dynamic, dynamic>{
    'reelCount': reelCount,
    'impressions': 300,
    'views': 120,
    'completionRate': 64,
  },
  'scope': <dynamic, dynamic>{
    'reelCount': reelCount,
    'maxReels': 200,
    'truncated': false,
  },
  'items': const <dynamic>[],
  'topReels': reelCount == 0
      ? const <dynamic>[]
      : <dynamic>[
          <dynamic, dynamic>{
            'id': 'reel-1',
            'caption': 'Top reel',
            'views': 120,
            'completionRate': 64,
          },
        ],
  'trending': const <dynamic>[],
  'unavailableMetrics': <dynamic>['uniqueViewers'],
  'generatedAt': 1,
});

class _FakeAnalyticsRepository extends Fake implements KirariRepository {
  _FakeAnalyticsRepository({this.analytics, this.error});

  final KirariAnalytics? analytics;
  final Object? error;
  int calls = 0;

  @override
  Future<KirariAnalytics> getCreatorAnalytics({int limit = 5}) async {
    calls++;
    if (error != null) throw error!;
    return analytics!;
  }
}

Future<void> _pump(WidgetTester tester, KirariRepository repository) async {
  await tester.pumpWidget(
    Provider<KirariRepository>.value(
      value: repository,
      child: const MaterialApp(home: KirariAnalyticsPage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('analytics page renders server counters and ranked reels', (
    tester,
  ) async {
    final repository = _FakeAnalyticsRepository(analytics: _analytics());

    await _pump(tester, repository);

    expect(repository.calls, 1);
    expect(find.text('Creator analytics'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Top reel'), findsOneWidget);
    expect(find.text('120'), findsWidgets);
  });

  testWidgets('analytics page shows an honest empty state', (tester) async {
    final repository = _FakeAnalyticsRepository(
      analytics: _analytics(reelCount: 0),
    );

    await _pump(tester, repository);

    expect(find.textContaining('No published videos yet'), findsOneWidget);
    expect(find.text('Top reel'), findsNothing);
  });

  testWidgets('analytics page shows a retryable failure state', (tester) async {
    final repository = _FakeAnalyticsRepository(
      error: StateError('server unavailable'),
    );

    await _pump(tester, repository);

    expect(find.textContaining('Could not load analytics'), findsOneWidget);
    expect(find.text('Retry'), findsWidgets);
  });
}
