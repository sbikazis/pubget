final class UnreadCounts {
  const UnreadCounts({
    required this.notifications,
    required this.groups,
    required this.privateChats,
    required this.mentions,
  });

  final int notifications;
  final int groups;
  final int privateChats;
  final int mentions;
}
