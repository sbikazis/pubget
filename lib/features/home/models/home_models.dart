import '../../groups/models/group_models.dart';
import '../../events/models/event_models.dart';
import '../../anime/models/anime_models.dart';
import '../../social/models/public_profile.dart';

enum HomeSectionKind {
  promotedGroups,
  risingGroups,
  recommendedGroups,
  communityActivity,
  recommendedPeople,
  editsPlaceholder,
  eventsPlaceholder,
  animePlaceholder,
}

final class DiscoverySearchResults {
  const DiscoverySearchResults({
    this.groups = const <Group>[],
    this.people = const <PublicProfile>[],
    this.events = const <PubgetEvent>[],
    this.anime = const <Anime>[],
  });

  final List<Group> groups;
  final List<PublicProfile> people;
  final List<PubgetEvent> events;
  final List<Anime> anime;

  bool get isEmpty =>
      groups.isEmpty && people.isEmpty && events.isEmpty && anime.isEmpty;
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
