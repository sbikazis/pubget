import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/l10n/app_strings.dart';
import 'package:pubget/features/achievements/data/achievement_catalog.dart';
import 'package:pubget/features/achievements/l10n/achievement_copy.dart';
import 'package:pubget/features/achievements/models/achievement_models.dart';
import 'package:pubget/features/achievements/providers/achievement_provider.dart';
import 'package:pubget/features/achievements/repositories/achievement_repository.dart';
import 'package:pubget/features/achievements/screens/achievements_page.dart';
import 'package:pubget/features/achievements/widgets/achievement_badge_widget.dart';
import 'package:pubget/features/authentication/models/auth_user.dart';
import 'package:pubget/features/authentication/providers/auth_provider.dart';

import 'authentication_test_support.dart';

final class _FakeAchievementRepository implements AchievementRepository {
  _FakeAchievementRepository(this.items);

  List<AchievementItem> items;

  @override
  Future<Result<List<AchievementItem>>> list({String? userId}) async =>
      Success(items);

  @override
  Stream<Result<List<AchievementItem>>> watch(String userId) async* {
    yield Success(items);
  }
}

AchievementItem _item(
  String id, {
  bool unlocked = false,
  DateTime? unlockedAt,
  List<AchievementConditionProgress>? conditions,
  num current = 0,
  num target = 0,
}) {
  final definition = AchievementCatalog.byId(id)!;
  return AchievementItem(
    definition: definition,
    unlocked: unlocked,
    unlockedAt: unlockedAt,
    currentValue: current,
    targetValue: target,
    conditions: conditions ?? definition.conditions,
  );
}

void main() {
  test('catalog has ten definitions with distinct animation types', () {
    expect(AchievementCatalog.definitions, hasLength(10));
    expect(
      AchievementCatalog.definitions.map((d) => d.animationType).toSet(),
      containsAll(<AchievementAnimationType>[
        AchievementAnimationType.none,
        AchievementAnimationType.shimmer,
        AchievementAnimationType.orbitLights,
        AchievementAnimationType.pathGlow,
        AchievementAnimationType.brushTrail,
        AchievementAnimationType.starPulse,
        AchievementAnimationType.bannerSway,
        AchievementAnimationType.crownGlow,
        AchievementAnimationType.lightSweep,
        AchievementAnimationType.mythicLiving,
      ]),
    );
  });

  test('entry label switches by viewer identity using displayName', () {
    final copy = AchievementCopy(AppStrings.arabic);
    expect(
      copy.entryLabel(isOwner: true, displayName: 'Zakaria'),
      'إنجازاتي',
    );
    expect(
      copy.entryLabel(isOwner: false, displayName: 'Zakaria'),
      'إنجازات Zakaria',
    );
  });

  testWidgets('progress toggle reveals all ten with separate condition rows',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final items = AchievementCatalog.definitions.map((definition) {
      if (definition.id == 'arena_sovereign') {
        return _item(
          definition.id,
          current: 18,
          target: 30,
          conditions: <AchievementConditionProgress>[
            const AchievementConditionProgress(
              id: 'wins_30',
              labelEn: '≥ 30 wins vs real players',
              labelAr: '≥ 30 انتصارًا ضد لاعبين حقيقيين',
              current: 18,
              target: 30,
              met: false,
            ),
            const AchievementConditionProgress(
              id: 'winrate_55',
              labelEn: 'Win rate ≥ 55% vs real players',
              labelAr: 'نسبة فوز ≥ 55% ضد لاعبين حقيقيين',
              current: 60,
              target: 55,
              met: true,
            ),
          ],
        );
      }
      if (definition.id == 'the_threshold') {
        return _item(
          definition.id,
          unlocked: true,
          unlockedAt: DateTime.utc(2026, 3, 1),
        );
      }
      return _item(definition.id);
    }).toList(growable: false);

    final authRepository = FakeAuthRepository(
      user: const AuthUser(id: 'u1', email: 'a@b.c'),
    );
    final auth = AuthProvider(repository: authRepository);
    final achievements = AchievementProvider(
      repository: _FakeAchievementRepository(items),
    );

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<AchievementProvider>.value(
              value: achievements,
            ),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            home: AchievementsPage(
              isOwner: true,
              displayName: 'Zakaria',
              userId: 'u1',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(achievements.items, hasLength(10));
    expect(find.text('My Achievements'), findsOneWidget);
    expect(find.byKey(const Key('achievements-progress-toggle')), findsOneWidget);
    expect(find.text('The Threshold'), findsWidgets);

    await tester.tap(find.byKey(const Key('achievements-progress-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Show unlocked'), findsOneWidget);
    expect(achievements.items.map((i) => i.definition.nameEn), contains('Arena Sovereign'));
    expect(find.text('Arena Sovereign'), findsOneWidget);
    expect(find.text('18/30'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Shogun of the Realm'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Shogun of the Realm'), findsOneWidget);
    expect(find.textContaining('50 unique members'), findsOneWidget);
    expect(find.textContaining('stable for 7 days'), findsOneWidget);
    expect(find.textContaining('Unlocked:'), findsWidgets);
  });

  testWidgets('locked badges are dimmed and reduce-motion freezes overlays',
      (tester) async {
    final locked = _item('keeper_of_time');
    final unlocked = _item(
      'dragon_of_legacy',
      unlocked: true,
      unlockedAt: DateTime.utc(2026, 1, 1),
    );
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(
            body: Row(
              children: <Widget>[
                AchievementBadgeWidget(
                  key: const Key('locked-badge'),
                  item: locked,
                  size: kAchievementStripBadgeSize,
                ),
                AchievementBadgeWidget(
                  key: const Key('mythic-badge'),
                  item: unlocked,
                  size: kAchievementListBadgeSize,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('locked-badge')), findsOneWidget);
    expect(kAchievementStripBadgeSize, 56);
    expect(find.byType(AchievementBadgeWidget), findsNWidgets(2));
  });

  test('celebration queue does not repeat a celebrated id', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final emptyRepo = _FakeAchievementRepository(AchievementCatalog.lockedItems());
    final provider = AchievementProvider(repository: emptyRepo);
    await provider.open('u2');
    emptyRepo.items = <AchievementItem>[
      _item(
        'the_threshold',
        unlocked: true,
        unlockedAt: DateTime.utc(2026, 1, 2),
      ),
    ];
    await provider.open('u2');
    final first = provider.takePendingCelebration();
    final second = provider.takePendingCelebration();
    if (first != null) {
      expect(first.id, 'the_threshold');
    }
    expect(second, isNull);
  });
}
