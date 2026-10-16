import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/app/app_route.dart';
import 'package:pubget/app/app_router.dart';
import 'package:pubget/app/app_shell_scope.dart';
import 'package:pubget/app/app_shell_tab.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/widgets/pubget_design_system.dart';
import 'package:pubget/features/achievements/providers/achievement_provider.dart';
import 'package:pubget/features/achievements/repositories/unavailable_achievement_repository.dart';
import 'package:pubget/features/authentication/models/auth_user.dart';
import 'package:pubget/features/authentication/providers/auth_provider.dart';
import 'package:pubget/features/authentication/providers/onboarding_provider.dart';
import 'package:pubget/features/edits/providers/edits_provider.dart';
import 'package:pubget/features/edits/repositories/unavailable_edits_repository.dart';
import 'package:pubget/features/events/providers/event_providers.dart';
import 'package:pubget/features/events/repositories/unavailable_event_repository.dart';
import 'package:pubget/features/fan_works/providers/fan_work_providers.dart';
import 'package:pubget/features/fan_works/repositories/unavailable_fan_work_repository.dart';
import 'package:pubget/features/groups/models/group_models.dart';
import 'package:pubget/features/home/models/home_models.dart';
import 'package:pubget/features/home/providers/home_provider.dart';
import 'package:pubget/features/home/repositories/home_repository.dart';
import 'package:pubget/features/home/screens/home_page.dart';
import 'package:pubget/features/notifications/providers/unread_engine.dart';
import 'package:pubget/features/social/models/public_profile.dart';

import 'authentication_test_support.dart';

/// Pins two Master Spec obligations on Home that were previously untested:
///
/// * §5.3 — sections with a standalone page expose a "See all" action, and it
///   goes to a real destination rather than nowhere.
/// * §2.1 — Offline is its own state. A group or people strip that failed to
///   refresh keeps its rows and says so, instead of silently rendering as if
///   the refresh had succeeded.
void main() {
  testWidgets('sections that have a page expose See all to that page', (
    tester,
  ) async {
    final harness = await _pumpHome(tester);

    for (final section in <Key>[
      const Key('home-promoted'),
      const Key('home-edits'),
      const Key('home-people'),
    ]) {
      expect(
        find.descendant(of: find.byKey(section), matching: find.text('See all')),
        findsOneWidget,
        reason: '$section must offer §5.3 see-more',
      );
    }

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('home-promoted')),
        matching: find.text('See all'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      harness.delegate.currentConfiguration,
      isA<ParameterizedRoute>(),
    );
    expect(
      (harness.delegate.currentConfiguration as ParameterizedRoute).path,
      '/groups',
      reason: 'See all must land on a real destination',
    );
    expect(find.text('Groups destination'), findsOneWidget);
  });

  testWidgets('a failed refresh keeps group rows and marks the section stale', (
    tester,
  ) async {
    final harness = await _pumpHome(tester);
    expect(find.byType(PubgetStaleBanner), findsNothing);
    expect(find.text('Promoted One'), findsOneWidget);

    harness.repository.fail = true;
    await harness.home.refresh();
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('home-promoted')),
        matching: find.byType(PubgetStaleBanner),
      ),
      findsOneWidget,
      reason: '§2.1 Offline must be surfaced on group strips, not swallowed',
    );
    expect(
      find.text('Promoted One'),
      findsOneWidget,
      reason: 'rows the user can already act on survive a failed refresh',
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('home-promoted')),
        matching: find.text('Nothing here yet'),
      ),
      findsNothing,
      reason: 'a network failure is not an empty section',
    );
  });
}

typedef _Harness = ({
  AppRouterDelegate delegate,
  HomeProvider home,
  _FlakyHomeRepository repository,
});

Future<_Harness> _pumpHome(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final authRepository = FakeAuthRepository(
    user: const AuthUser(id: 'alice', email: 'alice@example.com'),
  );
  final auth = AuthProvider(repository: authRepository);
  await auth.initialize();
  addTearDown(authRepository.close);
  addTearDown(auth.dispose);

  final homeRepository = _FlakyHomeRepository();
  final home = HomeProvider(repository: homeRepository);
  addTearDown(home.dispose);

  final onboarding = OnboardingProvider(repository: FakeUserRepository());
  addTearDown(onboarding.dispose);
  final edits = EditsProvider(
    repository: const UnavailableEditsRepository('offline'),
  );
  addTearDown(edits.dispose);
  final events = EventListProvider(
    repository: UnavailableEventRepository('offline'),
  );
  addTearDown(events.dispose);
  final works = FanWorkFeedProvider(
    repository: UnavailableFanWorkRepository('offline'),
  );
  addTearDown(works.dispose);
  final achievements = AchievementProvider(
    repository: UnavailableAchievementRepository(),
  );
  addTearDown(achievements.dispose);
  final unread = UnreadEngine()..sync(notifications: 3);
  addTearDown(unread.dispose);

  final delegate = AppRouterDelegate(
    homePage: HomePage(),
    domainPages: <String, Widget>{
      '/groups': Text('Groups destination'),
      '/search': Text('Search destination'),
      '/reels': Text('Reels destination'),
      '/unknown': Text('Unknown destination'),
    },
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<OnboardingProvider>.value(value: onboarding),
        ChangeNotifierProvider<HomeProvider>.value(value: home),
        ChangeNotifierProvider<EditsProvider>.value(value: edits),
        ChangeNotifierProvider<EventListProvider>.value(value: events),
        ChangeNotifierProvider<FanWorkFeedProvider>.value(value: works),
        ChangeNotifierProvider<AchievementProvider>.value(value: achievements),
        ChangeNotifierProvider<UnreadEngine>.value(value: unread),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: AppShellScope(
            openDrawer: () {},
            currentTab: AppShellTab.discover,
            child: Router<AppRoute>(
              routerDelegate: delegate,
              routeInformationParser: AppRouteInformationParser(),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return (delegate: delegate, home: home, repository: homeRepository);
}

Group _group(String id, String name) => Group(
  id: id,
  name: name,
  description: '',
  type: GroupType.public,
  animeId: null,
  founderId: 'groupowner',
  membersCount: 3,
  maxMembers: 100,
  joinPolicy: JoinPolicy.open,
  isSearchable: true,
  createdAt: DateTime(2026),
  chatBackgroundUrl: null,
  rules: '',
  activityScore: 12,
);

final class _FlakyHomeRepository implements HomeRepository {
  bool fail = false;

  Result<T> _result<T>(T value) =>
      fail ? FailureResult<T>(const NetworkError()) : Success<T>(value);

  @override
  Future<Result<List<Group>>> getPromotedGroups({
    int limit = 10,
    Group? after,
  }) async => _result(<Group>[_group('p1', 'Promoted One')]);

  @override
  Future<Result<List<Group>>> getRisingGroups({
    int limit = 10,
    Group? after,
  }) async => _result(const <Group>[]);

  @override
  Future<Result<List<Group>>> getRecommendedGroups({
    int limit = 10,
    Group? after,
  }) async => _result(const <Group>[]);

  @override
  Future<Result<List<Group>>> getCommunityActivity({
    int limit = 10,
    Group? after,
  }) async => _result(const <Group>[]);

  @override
  Future<Result<List<PublicProfile>>> getRecommendedPeople({
    required String userId,
    int limit = 10,
    PublicProfile? after,
  }) async => _result(const <PublicProfile>[]);

  @override
  Future<Result<DiscoverySearchResults>> search(String query) async =>
      _result(const DiscoverySearchResults());

  @override
  Future<Result<Map<String, DiscoverySectionPage>>> getHomeSections({
    String? section,
    int limit = 8,
  }) async => _result(const <String, DiscoverySectionPage>{});

  @override
  Future<Result<DiscoveryFeed>> getDiscoveryFeed({
    String? section,
    String? cursor,
    int limit = 8,
  }) async => _result(const DiscoveryFeed());
}
