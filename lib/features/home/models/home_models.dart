import '../../groups/models/group_models.dart';
import '../../events/models/event_models.dart';
import '../../anime/models/anime_models.dart';
import '../../fan_works/models/fan_work_models.dart';
import '../../social/models/public_profile.dart';

enum HomeSectionKind {
  promotedGroups,
  risingGroups,
  recommendedGroups,
  communityActivity,
  recommendedPeople,
  editsPlaceholder,
  eventsPlaceholder,
  gamesPlaceholder,
  fanWorksPlaceholder,
  animePlaceholder,
}

final class DiscoverySearchResults {
  const DiscoverySearchResults({
    this.groups = const <Group>[],
    this.people = const <PublicProfile>[],
    this.events = const <PubgetEvent>[],
    this.anime = const <Anime>[],
    this.fanWorks = const <FanWorkPreview>[],
  });

  final List<Group> groups;
  final List<PublicProfile> people;
  final List<PubgetEvent> events;
  final List<Anime> anime;
  final List<FanWorkPreview> fanWorks;

  bool get isEmpty =>
      groups.isEmpty &&
      people.isEmpty &&
      events.isEmpty &&
      anime.isEmpty &&
      fanWorks.isEmpty;
}

final class DiscoveryItem {
  const DiscoveryItem({
    required this.id,
    required this.type,
    required this.targetId,
    this.source = 'ranking',
    this.score = 0,
    this.createdAt,
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final String type;
  final String targetId;
  final String source;
  final num score;
  final DateTime? createdAt;
  final Map<String, dynamic> metadata;

  factory DiscoveryItem.fromMap(Map<String, dynamic> map) {
    return DiscoveryItem(
      id: map['id'] as String? ?? '',
      type: map['type'] as String? ?? '',
      targetId: map['targetId'] as String? ?? '',
      source: map['source'] as String? ?? 'ranking',
      score: map['score'] as num? ?? 0,
      createdAt: map['createdAt'] is DateTime ? map['createdAt'] as DateTime : null,
      metadata: map['metadata'] is Map
          ? Map<String, dynamic>.from(map['metadata'] as Map)
          : const <String, dynamic>{},
    );
  }
}

final class DiscoverySectionPage {
  const DiscoverySectionPage({
    this.items = const <DiscoveryItem>[],
    this.cursor,
    this.hasMore = false,
  });

  final List<DiscoveryItem> items;
  final String? cursor;
  final bool hasMore;

  factory DiscoverySectionPage.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const DiscoverySectionPage();
    final raw = map['items'] as List<Object?>? ?? const <Object?>[];
    return DiscoverySectionPage(
      items: raw
          .whereType<Map>()
          .map((item) => DiscoveryItem.fromMap(Map<String, dynamic>.from(item)))
          .toList(growable: false),
      cursor: map['cursor'] as String?,
      hasMore: map['hasMore'] == true,
    );
  }
}

final class DiscoveryFeed {
  const DiscoveryFeed({
    this.coldStart = false,
    this.sections = const <String, DiscoverySectionPage>{},
  });

  final bool coldStart;
  final Map<String, DiscoverySectionPage> sections;

  factory DiscoveryFeed.fromMap(Map<String, dynamic> map) {
    if (map['items'] is List) {
      final key = map['section'] as String? ?? 'default';
      return DiscoveryFeed(
        coldStart: map['coldStart'] == true,
        sections: <String, DiscoverySectionPage>{
          key: DiscoverySectionPage.fromMap(map),
        },
      );
    }
    final raw = map['sections'];
    final sections = <String, DiscoverySectionPage>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        if (value is Map) {
          sections[key.toString()] = DiscoverySectionPage.fromMap(
            Map<String, dynamic>.from(value),
          );
        }
      });
    }
    return DiscoveryFeed(
      coldStart: map['coldStart'] == true,
      sections: sections,
    );
  }

  DiscoverySectionPage section(String key) =>
      sections[key] ?? const DiscoverySectionPage();
}

final class HomeSection {
  const HomeSection({
    required this.kind,
    required this.title,
    this.groups = const <Group>[],
    this.people = const <PublicProfile>[],
    this.placeholderMessage,
  });

  final HomeSectionKind kind;
  final String title;
  final List<Group> groups;
  final List<PublicProfile> people;
  final String? placeholderMessage;

  bool get isPlaceholder => placeholderMessage != null;
}
