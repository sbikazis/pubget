enum AppShellTab { discover, groups, joined, private, edits }

extension AppShellTabX on AppShellTab {
  String get path => switch (this) {
    AppShellTab.discover => '/home',
    AppShellTab.groups => '/groups',
    AppShellTab.joined => '/joined',
    AppShellTab.private => '/private',
    AppShellTab.edits => '/edits',
  };

  /// Legacy path retained for callers and older deep links.
  String get legacyPath => switch (this) {
    AppShellTab.discover => '/home',
    AppShellTab.groups => '/groups',
    AppShellTab.joined => '/joined',
    AppShellTab.private => '/private',
    AppShellTab.edits => '/edits',
  };

  String get canonicalPath => switch (this) {
    AppShellTab.edits => '/reels',
    _ => path,
  };

  String get label => switch (this) {
    AppShellTab.discover => 'Discover',
    AppShellTab.groups => 'Groups',
    AppShellTab.joined => 'Joined',
    AppShellTab.private => 'Private',
    AppShellTab.edits => 'Reels',
  };

  static AppShellTab fromPath(String path) {
    return switch (path) {
      '/groups' => AppShellTab.groups,
      '/joined' => AppShellTab.joined,
      '/private' => AppShellTab.private,
      '/reels' || '/edits' => AppShellTab.edits,
      _ => AppShellTab.discover,
    };
  }
}
