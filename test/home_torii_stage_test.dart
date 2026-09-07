import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/branding/pubget_logo.dart';
import 'package:pubget/core/l10n/app_strings.dart';
import 'package:pubget/core/widgets/pubget_design_system.dart';
import 'package:pubget/features/events/models/event_models.dart';
import 'package:pubget/features/events/widgets/home_event_card.dart';
import 'package:pubget/features/fan_works/models/fan_work_models.dart';
import 'package:pubget/features/fan_works/widgets/home_fan_work_card.dart';

void main() {
  test('home chrome copy is bilingual', () {
    expect(AppStrings.english.seeMore, 'See more');
    expect(AppStrings.arabic.seeMore, 'مشاهدة المزيد');
    expect(AppStrings.english.sectionPromoted, 'Promoted groups');
    expect(AppStrings.arabic.eventTypeLabel('quiz'), 'اختبار');
    expect(AppStrings.english.fansCount(3), '3 fans');
  });

  test('home events prefer active then soon then people then remaining', () {
    final now = DateTime.utc(2026, 9, 6, 12);
    final picked = HomeEventsSection.pickHome(
      <PubgetEvent>[
        _event('ended', EventStatus.ended, people: 99, end: now.add(const Duration(hours: 1))),
        _event('soon', EventStatus.scheduled, people: 1, end: now.add(const Duration(hours: 20))),
        _event('quiet', EventStatus.active, people: 2, end: now.add(const Duration(hours: 10))),
        _event('hot', EventStatus.active, people: 8, end: now.add(const Duration(hours: 4))),
      ],
      now,
    );
    expect(picked.map((event) => event.id), <String>['hot', 'quiet']);
  });

  test('fan work row forces at least two types inside six cards', () {
    final mixed = diversifyFanWorks(<FanWork>[
      for (var i = 0; i < 8; i++) _work('d$i', FanWorkType.drawing),
      _work('m1', FanWorkType.manga),
    ]);
    expect(mixed, hasLength(6));
    expect(mixed.map((work) => work.type).toSet().length, greaterThanOrEqualTo(2));
  });

  testWidgets('luxury chrome and official logo render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: <Widget>[
              const PubgetLogoMark(key: Key('home-logo'), size: 36),
              PubgetLuxurySettingsButton(
                tooltip: 'Settings',
                onPressed: () {},
              ),
              PubgetLuxuryNotifyButton(
                tooltip: 'Notifications',
                onPressed: () {},
                badge: 2,
              ),
              PubgetKatanaCoinChip(
                balance: 120,
                tooltip: 'Store',
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('home-logo')), findsOneWidget);
    expect(find.byKey(const Key('home-settings')), findsOneWidget);
    expect(find.byKey(const Key('home-notifications')), findsOneWidget);
    expect(find.byKey(const Key('home-coins')), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
  });

  testWidgets('event home card keeps a fixed height and localized type', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        home: Scaffold(
          body: HomeEventCard(
            event: _event(
              'poll-1',
              EventStatus.active,
              people: 4,
              end: DateTime.utc(2026, 9, 7),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Poll'), findsOneWidget);
    expect(find.text('Vote'), findsOneWidget);
    expect(find.text('Best opening'), findsOneWidget);
  });
}

PubgetEvent _event(
  String id,
  EventStatus status, {
  required int people,
  required DateTime end,
}) {
  return PubgetEvent(
    id: id,
    type: EventType.poll,
    creatorId: 'alice',
    groupId: 'g1',
    title: 'Best opening',
    description: 'Vote now',
    configuration: const EventConfiguration(
      question: 'Best opening?',
      options: <EventOption>[
        EventOption(id: 'opt-1', label: 'One'),
        EventOption(id: 'opt-2', label: 'Two'),
      ],
    ),
    status: status,
    startAt: end.subtract(const Duration(days: 1)),
    endAt: end,
    participantsCount: people,
    responsesCount: 0,
    tally: const EventTally(),
    result: null,
    createdAt: DateTime.utc(2026, 9, 1),
    updatedAt: DateTime.utc(2026, 9, 1),
  );
}

FanWork _work(String id, FanWorkType type) => FanWork(
  id: id,
  creatorId: 'alice',
  type: type,
  title: 'Work $id',
  description: '',
  content: const FanWorkContent(),
  status: FanWorkStatus.published,
  moderationStatus: FanWorkModerationStatus.approved,
  visibility: FanWorkVisibility.public,
  createdAt: DateTime.utc(2026, 9, 1),
  updatedAt: DateTime.utc(2026, 9, 1),
);
