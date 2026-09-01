import '../../groups/models/group_models.dart';
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
  });

  final List<Group> groups;
  final List<PublicProfile> people;

  bool get isEmpty => groups.isEmpty && people.isEmpty;
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
