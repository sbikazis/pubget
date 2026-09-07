import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/anime/l10n/anime_copy.dart';
import 'package:pubget/features/anime/models/anime_models.dart';
import 'package:pubget/features/anime/models/anime_rating_models.dart';
import 'package:pubget/features/anime/widgets/anime_widgets.dart';

void main() {
  test('maps catalog terms to Arabic and keeps original titles', () {
    final copy = AnimeCopy.forLocale(const Locale('ar'));
    expect(copy.status('Finished Airing'), 'مكتمل');
    expect(copy.typeLabel('TV'), 'تلفزيون');
    expect(copy.genre('Action'), 'أكشن');
    expect(copy.season(AnimeSeason.fall), 'خريف');
    expect(copy.voiceLanguage('Japanese'), 'اليابانية / Japanese');
    expect(copy.nothingFound, 'لا يوجد أنمي');
    expect(copy.ui('Frieren'), 'Frieren');
  });

  test('English locale keeps Jikan term spelling', () {
    final copy = AnimeCopy.forLocale(const Locale('en'));
    expect(copy.status('Finished Airing'), 'Finished Airing');
    expect(copy.typeLabel('TV'), 'TV');
    expect(copy.genre('Action'), 'Action');
    expect(copy.voiceLanguage('Japanese'), 'Japanese');
    expect(copy.nothingFound, AnimeStrings.nothingFound);
  });

  testWidgets('score badge stacks A over M when the app has ratings', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnimeScoreBadge(
            malScore: 7.2,
            community: AnimeCommunityStats(
              animeId: '1',
              averageScore: 8.8,
              ratingCount: 3,
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('score-badge-app')), findsOneWidget);
    expect(find.byKey(const Key('score-badge-mal')), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
    expect(find.text('8.8'), findsOneWidget);
    expect(find.text('7.2'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('score-badge-app'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('score-badge-mal'))).dy),
    );
  });

  testWidgets('score badge shows only M when N is 0', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnimeScoreBadge(malScore: 7.2),
        ),
      ),
    );
    expect(find.byKey(const Key('score-badge-app')), findsNothing);
    expect(find.byKey(const Key('score-badge-mal')), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
    expect(find.text('A'), findsNothing);
  });
}
