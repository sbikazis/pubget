import 'package:flutter/widgets.dart';

import '../../app/app_router.dart';
import '../../core/links/pubget_links.dart';
import '../anime/widgets/anime_widgets.dart';
import '../events/models/event_models.dart';
import '../events/widgets/event_widgets.dart';
import '../fan_works/widgets/fan_work_widgets.dart';
import '../home/models/home_models.dart';

enum SearchHitType { user, group, event, anime, fanWork }

final class SearchHit {
  const SearchHit({
    required this.type,
    required this.id,
    required this.title,
    required this.route,
    this.subtitle,
    this.imageUrl,
    this.canonicalUrl,
  });

  final SearchHitType type;
  final String id;
  final String title;
  final String route;
  final String? subtitle;
  final String? imageUrl;
  final String? canonicalUrl;

  String get key => '${type.name}:$id';

  static const _visibleEventStatuses = <EventStatus>{
    EventStatus.active,
    EventStatus.scheduled,
    EventStatus.ended,
  };

  static List<SearchHit> fromDiscovery(
    DiscoverySearchResults results, {
    Set<String> hiddenUserIds = const <String>{},
  }) {
    final hits = <SearchHit>[
      for (final group in results.groups)
        if (group.isSearchable && group.id.isNotEmpty)
          SearchHit(
            type: SearchHitType.group,
            id: group.id,
            title: group.name,
            subtitle: 'Group',
            imageUrl: group.imageUrl ?? group.chatBackgroundUrl,
            route: PubgetLinks.groupPath(group.id),
            canonicalUrl: PubgetLinks.group(group.id),
          ),
      for (final person in results.people)
        if (person.uid.isNotEmpty && !hiddenUserIds.contains(person.uid))
          SearchHit(
            type: SearchHitType.user,
            id: person.uid,
            title: person.username ?? 'Pubget user',
            subtitle: 'Person',
            imageUrl: person.avatarUrl,
            route: PubgetLinks.profilePath(person.uid),
            canonicalUrl: PubgetLinks.profile(person.uid),
          ),
      for (final event in results.events)
        if (event.id.isNotEmpty && _visibleEventStatuses.contains(event.status))
          SearchHit(
            type: SearchHitType.event,
            id: event.id,
            title: event.title,
            subtitle: 'Event',
            imageUrl: event.coverUrl.isEmpty ? null : event.coverUrl,
            route: EventLinks.path(event.id),
            canonicalUrl: EventLinks.canonical(event.id),
          ),
      for (final anime in results.anime)
        if (anime.id.isNotEmpty)
          SearchHit(
            type: SearchHitType.anime,
            id: anime.id,
            title: anime.title,
            subtitle: 'Anime',
            imageUrl: anime.images.displayUrl,
            route: AnimeLinks.detailsPath(anime.id),
            canonicalUrl: PubgetLinks.anime(anime.id),
          ),
      for (final work in results.fanWorks)
        if (work.id.isNotEmpty)
          SearchHit(
            type: SearchHitType.fanWork,
            id: work.id,
            title: work.title,
            subtitle: work.creatorName.isEmpty ? 'Fan Work' : work.creatorName,
            imageUrl: work.coverPath.isEmpty ? null : work.coverPath,
            route: FanWorkLinks.path(work.id),
            canonicalUrl: FanWorkLinks.canonical(work.id),
          ),
    ];
    return _dedupe(hits);
  }

  static List<SearchHit> _dedupe(List<SearchHit> hits) {
    final seen = <String>{};
    final unique = <SearchHit>[];
    for (final hit in hits) {
      if (hit.id.isEmpty || hit.route.isEmpty || !seen.add(hit.key)) continue;
      unique.add(hit);
    }
    return unique;
  }

  void open(BuildContext context) => AppNavigation.go(context, route);
}
