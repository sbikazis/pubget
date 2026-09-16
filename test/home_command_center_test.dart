import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/l10n/app_strings.dart';
import 'package:pubget/core/widgets/pubget_design_system.dart';
import 'package:pubget/features/groups/models/group_models.dart';
import 'package:pubget/features/groups/widgets/group_list_card.dart';

void main() {
  test('locked product copy exists in both official locales', () {
    expect(AppStrings.english.homeWhatNow, 'What should I do right now?');
    expect(AppStrings.arabic.homeWhatNow, 'ماذا أفعل الآن؟');
    expect(AppStrings.english.sectionRising, 'Rising groups');
    expect(AppStrings.arabic.sectionRising, 'مجموعات صاعدة');
    expect(AppStrings.english.drawerStore, 'Dragon Store');
    expect(AppStrings.arabic.drawerStore, 'متجر التنين');
    expect(AppStrings.english.groupTypeLabel('animeRoleplay'), 'Anime Roleplay');
    expect(AppStrings.arabic.groupTypeLabel('public'), 'عامة');
  });

  testWidgets('hero and now-actions render real destinations only', (
    tester,
  ) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        home: Scaffold(
          body: Column(
            children: <Widget>[
              const PubgetHeroBanner(
                key: Key('home-command-hero'),
                title: 'Your anime world',
                subtitle: 'Discover people, groups, edits, and games.',
              ),
              PubgetNowActions(
                actions: <PubgetNowActionData>[
                  PubgetNowActionData(
                    id: 'groups',
                    label: 'Join a group',
                    icon: Icons.groups_outlined,
                    onPressed: () => tapped.add('groups'),
                  ),
                  PubgetNowActionData(
                    id: 'edits',
                    label: 'Watch Edits',
                    icon: Icons.movie_filter_outlined,
                    onPressed: () => tapped.add('edits'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('home-command-hero')), findsOneWidget);
    expect(find.text('Your anime world'), findsOneWidget);
    await tester.tap(find.byKey(const Key('home-now-action-groups')));
    await tester.tap(find.byKey(const Key('home-now-action-edits')));
    expect(tapped, <String>['groups', 'edits']);
  });

  testWidgets('group list card shows localized type instead of raw enum', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        home: Scaffold(
          body: GroupListCard(
            group: Group(
              id: 'g1',
              name: 'Founded Group B',
              description: 'A roleplay room',
              type: GroupType.animeRoleplay,
              animeId: 'a1',
              founderId: 'alice',
              membersCount: 4,
              maxMembers: 40,
              joinPolicy: JoinPolicy.open,
              isSearchable: true,
              createdAt: DateTime(2026),
              chatBackgroundUrl: null,
              rules: '',
              activityScore: 1,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Founded Group B'), findsOneWidget);
    expect(find.text('Anime Roleplay'), findsOneWidget);
    expect(find.text('animeRoleplay'), findsNothing);
    expect(find.text('4/40 members'), findsOneWidget);
  });
}
