import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/anime/models/anime_models.dart';
import 'package:pubget/features/events/models/event_models.dart';
import 'package:pubget/features/fan_works/models/fan_work_models.dart';
import 'package:pubget/features/groups/models/group_models.dart';
import 'package:pubget/features/home/models/home_models.dart';
import 'package:pubget/features/search/search_hit.dart';
import 'package:pubget/features/social/models/public_profile.dart';

import 'anime_test_support.dart';

void main() {
  test('maps domain contracts and drops inaccessible rows', () {
    final hits = SearchHit.fromDiscovery(
      DiscoverySearchResults(
        groups: <Group>[
          _group('g-public', searchable: true),
          _group('g-hidden', searchable: false),
          _group(''),
        ],
        people: const <PublicProfile>[
          PublicProfile(uid: 'u1', username: 'visible'),
          PublicProfile(uid: 'blocked', username: 'nope'),
        ],
        events: <PubgetEvent>[
          _event('e-active', EventStatus.active),
          _event('e-draft', EventStatus.draft),
          _event('e-archived', EventStatus.archived),
        ],
        anime: <Anime>[sampleAnime()],
        fanWorks: const <FanWorkPreview>[
          FanWorkPreview(
            id: 'w1',
            type: FanWorkType.story,
            title: 'Tale',
            creatorId: 'u1',
            creatorName: 'Author',
          ),
        ],
      ),
      hiddenUserIds: const <String>{'blocked'},
    );

    expect(
      hits.map((hit) => hit.id),
      orderedEquals(<String>['g-public', 'u1', 'e-active', '52991', 'w1']),
    );
    expect(hits.every((hit) => hit.canonicalUrl!.contains('pubget-aaf27.web.app')), isTrue);
    expect(hits.where((hit) => hit.id == 'blocked'), isEmpty);
  });

  test('duplicate ids of the same type collapse', () {
    final hits = SearchHit.fromDiscovery(
      DiscoverySearchResults(
        groups: <Group>[_group('g1'), _group('g1')],
      ),
    );
    expect(hits, hasLength(1));
  });
}

Group _group(String id, {bool searchable = true}) => Group(
  id: id,
  name: 'Group $id',
  description: 'secret rules should not leak',
  type: GroupType.public,
  animeId: null,
  founderId: 'u1',
  membersCount: 1,
  maxMembers: 100,
  joinPolicy: JoinPolicy.open,
  isSearchable: searchable,
  createdAt: DateTime(2026),
  chatBackgroundUrl: null,
  rules: 'private rules',
  activityScore: 0,
);

PubgetEvent _event(String id, EventStatus status) => PubgetEvent(
  id: id,
  type: EventType.poll,
  creatorId: 'u1',
  groupId: 'g1',
  title: id,
  description: 'private responses stay off the hit',
  configuration: const EventConfiguration(question: 'Q'),
  status: status,
  startAt: DateTime(2026),
  endAt: DateTime(2026, 2),
  participantsCount: 4,
  responsesCount: 3,
  tally: const EventTally(votes: {'a': 3}),
  result: null,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
